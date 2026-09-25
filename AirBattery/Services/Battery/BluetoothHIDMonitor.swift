import Foundation
import IOBluetooth
import Synchronization

struct BluetoothHIDLogEntry: Decodable, Equatable {
    let mac: String
    var name: String
    let type: String
    let time: String
    let level: Int
    let status: String

    var identity: String {
        "\(name)\u{1f}\(mac)\u{1f}\(type)"
    }
}

enum BluetoothHIDLogParser {
    static func entries(from output: String) -> [BluetoothHIDLogEntry] {
        let decoder = JSONDecoder()
        return output.split(separator: "\n").compactMap { line in
            try? decoder.decode(
                BluetoothHIDLogEntry.self,
                from: Data(line.utf8)
            )
        }
    }

    static func latestEntries(from output: String) -> [BluetoothHIDLogEntry] {
        var latest: [String: BluetoothHIDLogEntry] = [:]
        for entry in entries(from: output) {
            latest[entry.identity] = entry
        }
        return Array(latest.values)
    }
}

/// Owns Bluetooth HID discovery based on the unified log stream.
///
/// There is one parser, one incremental cursor, one serialized log-reader gate,
/// and one set of names whose connected presence is refreshed between log reads.
final class BluetoothHIDMonitor: Sendable {
    enum Trigger {
        case bootstrap
        case wake
        case connect
    }

    static let shared = BluetoothHIDMonitor()

    private struct State {
        var isRunning = false
        var queued = false
        var knownDeviceNames: Set<String> = []
    }

    private let state = Mutex(State())
    private let deviceStore: DeviceStore

    init(deviceStore: DeviceStore = .shared) {
        self.deviceStore = deviceStore
    }

    var readBTHID: Bool { AppPreferences.readBTHID }

    private var lastTS: String {
        get { AppPreferences.logReaderLastTS }
        set { AppPreferences.logReaderLastTS = newValue }
    }

    func startScan() {
        guard readBTHID else { return }
        print("ℹ️ Start scanning Bluetooth HID devices...")
        DispatchQueue.global(qos: .utility).async {
            self.run(.bootstrap)
        }
    }

    func scanDevices() {
        guard readBTHID else { return }
        DispatchQueue.global(qos: .utility).async {
            self.refreshConnectedDevices()
        }
    }

    func run(_ trigger: Trigger) {
        guard readBTHID, beginRun() else { return }
        defer { finishRun() }

        switch trigger {
        case .bootstrap:
            // Recover connected HID devices whose most recent battery event may
            // predate the incremental cursor.
            let recoveryEntries = readEntries(
                window: "2h",
                startTimestamp: nil,
                timeout: 25,
                latestOnly: true
            )
            ingest(recoveryEntries, connectedOnly: true)
            refreshConnectedDevices()

            let start = incrementalStartTimestamp()
            let incrementalEntries = readEntries(
                window: start == nil ? "20m" : "10m",
                startTimestamp: start,
                timeout: 5,
                latestOnly: false
            )
            ingest(incrementalEntries, connectedOnly: false)

        case .wake:
            let start = incrementalStartTimestamp()
            let entries = readEntries(
                window: start == nil ? "3m" : "10m",
                startTimestamp: start,
                timeout: 5,
                latestOnly: false
            )
            ingest(entries, connectedOnly: false)

        case .connect:
            let start = incrementalStartTimestamp()
            let entries = readEntries(
                window: start == nil ? "2m" : "10m",
                startTimestamp: start,
                timeout: 5,
                latestOnly: false
            )
            ingest(entries, connectedOnly: false)
        }

        advanceLastTS()
    }

    private func beginRun() -> Bool {
        state.withLock { state in
            if state.isRunning {
                state.queued = true
                return false
            }
            state.isRunning = true
            return true
        }
    }

    private func finishRun() {
        let shouldRunAgain = state.withLock { state in
            state.isRunning = false
            let queued = state.queued
            state.queued = false
            return queued
        }

        if shouldRunAgain {
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + 0.8
            ) {
                self.run(.wake)
            }
        }
    }

    private func readEntries(
        window: String,
        startTimestamp: String?,
        timeout: Int,
        latestOnly: Bool
    ) -> [BluetoothHIDLogEntry] {
        guard let resourcePath = Bundle.main.resourcePath else { return [] }

        var environment = ProcessInfo.processInfo.environment
        if let startTimestamp {
            environment["START_TS"] = startTimestamp
        } else {
            environment.removeValue(forKey: "START_TS")
        }

        guard let result = ProcessRunner.run(
            path: "/bin/bash",
            arguments: [
                "\(resourcePath)/logReader.sh",
                "mac",
                window,
            ],
            environment: environment,
            timeout: timeout > 0 ? TimeInterval(timeout) : nil
        ), !result.output.isEmpty
        else {
            return []
        }

        return latestOnly
            ? BluetoothHIDLogParser.latestEntries(from: result.output)
            : BluetoothHIDLogParser.entries(from: result.output)
    }

    private func ingest(
        _ entries: [BluetoothHIDLogEntry],
        connectedOnly: Bool
    ) {
        let connectedAddresses = connectedOnly
            ? Set(Self.connectedDevices(mac: true))
            : []
        let formatter = Self.makeISOFormatter()
        let parent = AppPreferences.deviceName
        let now = Date().timeIntervalSince1970

        for var entry in entries {
            let normalizedAddress = Self.normalizedAddress(entry.mac)
            if connectedOnly && !connectedAddresses.contains(normalizedAddress) {
                continue
            }

            if entry.name.isEmpty {
                entry.name = "\(entry.type) (\(entry.mac))"
            }

            state.withLock { state in
                _ = state.knownDeviceNames.insert(entry.name)
            }

            deviceStore.update(
                Device(
                    deviceID: entry.mac,
                    deviceType: entry.type,
                    deviceName: entry.name,
                    batteryLevel: min(100, max(0, entry.level)),
                    isCharging: entry.status == "+" ? 1 : 0,
                    parentName: parent,
                    lastUpdate: now,
                    realUpdate:
                        formatter.date(from: entry.time)?.timeIntervalSince1970 ?? 0
                )
            )
        }
    }

    private func refreshConnectedDevices() {
        let connectedNames = Set(Self.connectedDevices())
        let knownNames = state.withLock { $0.knownDeviceNames }
        let now = Date().timeIntervalSince1970

        for name in knownNames where connectedNames.contains(name) {
            guard var device = deviceStore.getByName(name) else { continue }
            device.lastUpdate = now
            deviceStore.update(device)
        }
    }

    private func incrementalStartTimestamp() -> String? {
        let formatter = Self.makeCursorFormatter()
        if lastTS.isEmpty {
            return formatter.string(from: Date(timeIntervalSinceNow: -20 * 60))
        }
        guard let previous = formatter.date(from: lastTS) else { return nil }
        return formatter.string(from: previous.addingTimeInterval(-2))
    }

    private func advanceLastTS() {
        lastTS = Self.makeCursorFormatter().string(
            from: Date().addingTimeInterval(-2)
        )
    }

    private static func connectedDevices(mac: Bool = false) -> [String] {
        guard let paired =
            IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]
        else {
            return []
        }

        let connected = paired.filter { $0.isConnected() }
        if mac {
            return connected.compactMap {
                guard let address = $0.addressString, !address.isEmpty else {
                    return nil
                }
                return normalizedAddress(address)
            }
        }

        return connected.compactMap {
            guard let name = $0.name, !name.isEmpty else { return nil }
            return name
        }
    }

    private static func normalizedAddress(_ address: String) -> String {
        address.uppercased().replacingOccurrences(of: "-", with: ":")
    }

    private static func makeCursorFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter
    }

    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withTimeZone,
        ]
        return formatter
    }
}

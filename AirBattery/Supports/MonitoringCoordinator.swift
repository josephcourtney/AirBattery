import Combine
import Foundation
import WidgetKit

/// Owns AirBattery's periodic application work.
///
/// SwiftUI surfaces subscribe only to the published display ticks. Device scans,
/// alerts, widget snapshot writes, Nearcast broadcasts, and pinned-item refreshes
/// are process-level work and live here rather than in rendering views.
@MainActor
final class MonitoringCoordinator: ObservableObject {
    static let shared = MonitoringCoordinator()

    @Published private(set) var secondTick = Date()
    @Published private(set) var fiveSecondTick = Date()

    private var fixedTimers: [Timer] = []
    private var configuredTimers: [Timer] = []
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        BatteryHistoryStore.shared.recordCurrentSnapshot()

        fixedTimers = [
            makeTimer(every: 1) { [weak self] in
                InternalBattery.status = getPowerState()
                self?.secondTick = Date()
            },
            makeTimer(every: 5) { [weak self] in
                IDeviceBattery.shared.scanDevices()
                refeshPinnedBar()
                self?.fiveSecondTick = Date()
            },
            makeTimer(every: 30) {
                AirBatteryModel.touchHeartbeat()
            },
            makeTimer(every: 60) {
                BatteryHistoryStore.shared.recordCurrentSnapshot()
            },
            makeTimer(every: 300) {
                batteryAlert()
            },
        ]

        rescheduleConfiguredTimers()
    }

    func stop() {
        fixedTimers.forEach { $0.invalidate() }
        configuredTimers.forEach { $0.invalidate() }
        fixedTimers.removeAll()
        configuredTimers.removeAll()
        started = false
    }

    func updateIntervalDidChange() {
        guard started else { return }
        rescheduleConfiguredTimers()
    }

    private func rescheduleConfiguredTimers() {
        configuredTimers.forEach { $0.invalidate() }
        configuredTimers.removeAll()

        let interval = max(1, AppPreferences.updateInterval)
        let nearcastJitter = Int.random(in: -9...9)

        configuredTimers = [
            makeTimer(every: TimeInterval(29 * interval)) {
                bleBattery.scan()
            },
            makeTimer(every: TimeInterval(59 * interval)) {
                btdBattery.scanDevices()
            },
            makeTimer(every: TimeInterval(24 * interval)) {
                SPBluetoothDataModel.shared.refeshData(
                    completion: { _ in
                        DispatchQueue.global(qos: .background).async {
                            MagicBattery.shared.scanDevices()
                            AirBatteryModel.writeData()
                        }
                    },
                    error: {
                        AirBatteryModel.writeData()
                    }
                )
            },
            makeTimer(
                every: TimeInterval(max(1, 60 * interval + nearcastJitter))
            ) { [weak self] in
                self?.sendNearcastSnapshotIfNeeded()
            },
            makeTimer(every: TimeInterval(60 * interval)) {
                if AppPreferences.widgetInterval != -1 {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            },
        ]
    }

    private func makeTimer(
        every interval: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                action()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func sendNearcastSnapshotIfNeeded() {
        let groupID = AppPreferences.nearcastGroupID
        let sharingKey = AppPreferences.nearcastSharingKey
        guard AppPreferences.nearCast,
              isNearcastCredentialValid(
                  groupID: groupID,
                  sharingKey: sharingKey
              )
        else {
            return
        }

        var allDevices = AirBatteryModel.getAll()
        let internalStatus = InternalBattery.status
        if internalStatus.hasBattery {
            allDevices.insert(ib2ab(internalStatus), at: 0)
        }

        do {
            let jsonData = try JSONEncoder().encode(allDevices)
            guard let jsonString = String(data: jsonData, encoding: .utf8),
                  let data = encryptNearcastString(
                      jsonString,
                      groupID: groupID,
                      sharingKey: sharingKey
                  )
            else {
                return
            }

            let deviceName = AppPreferences.deviceName
            netcastService.sendMessage(
                NCMessage(
                    id: groupID,
                    sender: systemUUID ?? deviceName,
                    command: "",
                    content: data
                )
            )
        } catch {
            print("Write JSON error：\(error)")
        }
    }
}

@MainActor
final class BatteryHistoryStore {
    static let shared = BatteryHistoryStore()

    private static let storageKey = "batteryHistory.v1"
    private static let retention: TimeInterval = 48 * 60 * 60
    private static let maximumSamplesPerDevice = 512
    private static let minimumSampleSpacing: TimeInterval = 55
    private static let maximumReadingAge: TimeInterval = 3 * 60

    private let defaults =
        UserDefaults(suiteName: "group.com.josephcourtney.AirBattery") ??
        .standard
    private var history: [String: [BatteryHistorySample]] = [:]

    private init() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(
                  [String: [BatteryHistorySample]].self,
                  from: data
              )
        else {
            return
        }
        history = decoded
        prune(now: Date().timeIntervalSince1970)
    }

    func recordCurrentSnapshot(now: Date = Date()) {
        var devices = AirBatteryModel.deviceSnapshot()
        let internalStatus = InternalBattery.status
        if internalStatus.hasBattery {
            devices.append(ib2ab(internalStatus))
        }
        record(devices, now: now)
    }

    func record(_ devices: [Device], now: Date = Date()) {
        let timestamp = now.timeIntervalSince1970
        var changed = false

        for device in devices where device.hasBattery &&
            (0...100).contains(device.batteryLevel) {
            let readingAge = max(0, timestamp - device.lastUpdate)
            guard device.deviceID == "@MacInternalBattery" ||
                    readingAge <= Self.maximumReadingAge
            else {
                continue
            }

            let key = Self.key(for: device)
            let sample = BatteryHistorySample(
                timestamp: timestamp,
                level: device.batteryLevel,
                charging: device.isCharging != 0
            )
            var samples = history[key] ?? []

            if let last = samples.last,
               timestamp - last.timestamp < Self.minimumSampleSpacing,
               last.level == sample.level,
               last.charging == sample.charging {
                continue
            }

            samples.append(sample)
            let cutoff = timestamp - Self.retention
            samples.removeAll { $0.timestamp < cutoff }
            if samples.count > Self.maximumSamplesPerDevice {
                samples.removeFirst(
                    samples.count - Self.maximumSamplesPerDevice
                )
            }
            history[key] = samples
            changed = true
        }

        if changed {
            persist()
        }
    }

    func estimate(for device: Device, now: Date = Date()) -> BatteryTimeEstimate? {
        BatteryTimeEstimator.estimate(
            samples: history[Self.key(for: device)] ?? [],
            now: now
        )
    }

    func samples(for device: Device) -> [BatteryHistorySample] {
        history[Self.key(for: device)] ?? []
    }

    static func key(for device: Device) -> String {
        DeviceDisplayNameStore.key(
            canonicalID: device.deviceID,
            deviceType: device.deviceType
        )
    }

    private func prune(now: TimeInterval) {
        let cutoff = now - Self.retention
        for key in Array(history.keys) {
            history[key]?.removeAll { $0.timestamp < cutoff }
            if history[key]?.isEmpty == true {
                history.removeValue(forKey: key)
            }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

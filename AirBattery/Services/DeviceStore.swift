import Foundation
import Synchronization

final class DeviceStore: Sendable {
    static let shared = DeviceStore()

    private struct State {
        var devices: [Device] = []
        var lastBLEPresence: [String: Double] = [:]
    }

    private let state = Mutex(State())

    private init() {}

    func noteBLEPresence(name: String) {
        let key = normalizedObservationName(name)
        state.withLock { state in
            state.lastBLEPresence[key] = Date().timeIntervalSince1970
        }
    }

    private func isRecentlyBLEObserved(_ device: Device, now: Double) -> Bool {
        let interval = max(1, AppPreferences.updateInterval)
        let presenceLifetime = Double(max(90, interval * 65))
        let key = normalizedObservationName(observationName(for: device))
        let lastSeen = state.withLock { $0.lastBLEPresence[key] }
        guard let lastSeen else { return false }
        return now - lastSeen <= presenceLifetime
    }

    private func observationName(for device: Device) -> String {
        var name = device.deviceName
        if device.deviceType.hasPrefix("ap_pod") && !device.parentName.isEmpty {
            name = device.parentName
        }
        for suffix in [" (Case)", "（充电盒）", " 🄻🅁", " 🄻", " 🅁"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name
    }

    private func normalizedObservationName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func snapshot() -> [Device] {
        state.withLock { $0.devices }
    }

    func update(_ device: Device) {
        state.withLock { state in
            if let index = state.devices.firstIndex(where: {
                $0.deviceName == device.deviceName
            }) {
                let existing = state.devices[index]
                var merged = device
                merged.mergeIdentifiers(fromExisting: existing)
                let estimate = BatteryEstimateEngine.updated(
                    previousLevel: existing.batteryLevel,
                    previousCharging: existing.isCharging != 0,
                    previousTime: existing.lastUpdate,
                    previousRatePerHour: existing.estimatedRatePerHour,
                    previousSecondsRemaining: existing.estimatedSecondsRemaining,
                    level: merged.batteryLevel,
                    charging: merged.isCharging != 0,
                    time: merged.lastUpdate
                )
                merged.estimatedRatePerHour = estimate.ratePerHour
                merged.estimatedSecondsRemaining = estimate.secondsRemaining
                state.devices[index] = merged
            } else {
                state.devices.append(device)
            }
        }
    }

    func hiddenDevices() -> [Device] {
        let hiddenNames = AppPreferences.hiddenDeviceNames
        return getAll(noFilter: true).filter {
            hiddenNames.contains($0.deviceName)
        }
    }

    func getAll(reverse: Bool = false, noFilter: Bool = false) -> [Device] {
        let thisMac = AppPreferences.deviceName
        let disappearTime = AppPreferences.disappearTime
        let hiddenNames = AppPreferences.hiddenDeviceNames
        let now = Date().timeIntervalSince1970
        let current = snapshot()
        var list = (reverse ? Array(current.reversed()) : current).filter {
            now - $0.lastUpdate < Double(disappearTime * 60) ||
                isRecentlyBLEObserved($0, now: now)
        }
        if !noFilter {
            list = list.filter { !hiddenNames.contains($0.deviceName) }
        }

        var ordered = list.filter { $0.parentName == thisMac }
        for device in list where device.parentName.isEmpty && device.parentName != thisMac {
            ordered.append(device)
            ordered.append(contentsOf: list.filter { $0.parentName == device.deviceName })
        }
        ordered.append(contentsOf: list.filter { !ordered.contains($0) })
        return ordered.filter { !isNameBlocked(name: $0.deviceName) }
    }

    func getByName(_ name: String) -> Device? {
        getAll(noFilter: true).first { $0.deviceName == name }
    }

    func getByID(_ id: String) -> Device? {
        getAll(noFilter: true).first { $0.matchesIdentifier(id) }
    }

    func isNameBlocked(name: String) -> Bool {
        let whitelistMode = AppPreferences.whitelistMode
        let filteredNames = AppPreferences.nameRules
        if whitelistMode {
            return !filteredNames.isEmpty && !filteredNames.contains(name)
        }
        return filteredNames.contains(name)
    }
}

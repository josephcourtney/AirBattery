import Foundation

@MainActor
final class BatteryHistoryStore {
    private let deviceStore: DeviceStore

    private static let storageKey = "batteryHistory.v1"
    private static let retention: TimeInterval = 48 * 60 * 60
    private static let maximumSamplesPerDevice = 512
    private static let minimumSampleSpacing: TimeInterval = 55
    private static let maximumReadingAge: TimeInterval = 3 * 60

    private let defaults =
        UserDefaults(suiteName: "group.com.josephcourtney.AirBattery") ??
        .standard
    private var history: [String: [BatteryHistorySample]] = [:]

    init(deviceStore: DeviceStore) {
        self.deviceStore = deviceStore
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
        var devices = deviceStore.snapshot()
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
        if device.deviceID == "@MacInternalBattery",
           let native = nativeInternalEstimate(now: now) {
            return native
        }

        return BatteryTimeEstimator.estimate(
            samples: history[Self.key(for: device)] ?? [],
            now: now
        )
    }

    func samples(for device: Device) -> [BatteryHistorySample] {
        history[Self.key(for: device)] ?? []
    }

    static func key(for device: Device) -> String {
        DeviceStorageKey.make(
            canonicalID: device.deviceID,
            deviceType: device.deviceType
        )
    }

    private func nativeInternalEstimate(
        now: Date
    ) -> BatteryTimeEstimate? {
        let status = InternalBattery.status
        guard status.hasBattery,
              status.batteryLevel > 0,
              status.batteryLevel < 100,
              let duration = parseTimeLeft(status.timeLeft),
              duration >= 3 * 60
        else {
            return nil
        }

        return BatteryTimeEstimate(
            kind: status.isCharging ? .charging : .discharging,
            startDate: now,
            endDate: now.addingTimeInterval(duration),
            duration: duration,
            confidence: 1
        )
    }

    private func parseTimeLeft(_ value: String) -> TimeInterval? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              hours >= 0,
              (0..<60).contains(minutes)
        else {
            return nil
        }
        return TimeInterval(hours * 3600 + minutes * 60)
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

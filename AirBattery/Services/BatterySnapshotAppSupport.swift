import Foundation

extension BatterySnapshotStore {
    static func widgetStoredDevices(
        from devices: [Device],
        internalBattery: Device?,
        reverse: Bool
    ) -> [Device] {
        var ordered = reverse ? Array(devices.reversed()) : devices
        if let internalBattery, internalBattery.hasBattery {
            ordered.insert(internalBattery, at: 0)
        }
        return ordered
    }

    static func internalBatteryDevice(from battery: iBattery) -> Device {
        var device = ib2ab(battery)
        device.estimatedSecondsRemaining =
            BatteryEstimateEngine.seconds(fromNativeTimeLeft: battery.timeLeft)
        return device
    }

    static func writeCurrentSnapshot(deviceStore: DeviceStore = .shared) {
        let reverse = UserDefaults.standard.object(
            forKey: "revListOnWidget"
        ) as? Bool ?? false
        let status = InternalBattery.status
        let devices = widgetStoredDevices(
            from: deviceStore.getAll(),
            internalBattery: status.hasBattery
                ? internalBatteryDevice(from: status)
                : nil,
            reverse: reverse
        )
        do {
            let data = try JSONEncoder().encode(devices)
            try data.write(to: dataURL, options: .atomic)
            touchHeartbeat()
        } catch {
            print("Write JSON error：\(error)")
        }
    }

    static func nearcastDevices(
        at url: URL,
        deviceStore: DeviceStore = .shared
    ) -> [Device] {
        nearcastDevices(
            at: url,
            localNames: Set(deviceStore.getAll().map(\.deviceName))
        )
    }
}

import Foundation

enum BatterySnapshotStore {
    static let widgetBundleIdentifier = "com.josephcourtney.AirBattery.widget"
    static let appGroupIdentifier = "group.com.josephcourtney.AirBattery"

    static var sharedDataDirectory: URL {
        if let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let directory = container.appendingPathComponent("Documents", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
        }

        if Bundle.main.bundleIdentifier == widgetBundleIdentifier {
            return FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
        }
        return FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent(
            "Containers/\(widgetBundleIdentifier)/Data/Documents",
            isDirectory: true
        )
    }

    static var dataURL: URL {
        sharedDataDirectory.appendingPathComponent("data.json")
    }

    static var nearcastDirectory: URL {
        let url = sharedDataDirectory.appendingPathComponent("NearcastData", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var heartbeatURL: URL {
        sharedDataDirectory.appendingPathComponent("heartbeat")
    }

    static func touchHeartbeat() {
        try? Data().write(to: heartbeatURL, options: .atomic)
    }

    static func isFresh(maxAge: TimeInterval = 120, now: Date = Date()) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: heartbeatURL.path
        ),
        let modified = attributes[.modificationDate] as? Date
        else {
            return false
        }
        return now.timeIntervalSince(modified) <= maxAge
    }

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
        let reverse = UserDefaults.standard.object(forKey: "revListOnWidget") as? Bool ?? false
        let status = InternalBattery.status
        let devices = widgetStoredDevices(
            from: deviceStore.getAll(),
            internalBattery: status.hasBattery ? internalBatteryDevice(from: status) : nil,
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

    static func read(from url: URL = dataURL) -> [Device] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Device].self, from: data)
        } catch {
            print("Read JSON error：\(error)")
            return []
        }
    }

    static func nearcastDevices(
        at url: URL,
        fromWidget: Bool = false,
        deviceStore: DeviceStore = .shared
    ) -> [Device] {
        let disappearTime = AppPreferences.disappearTime
        let devices = read(from: url)
        let now = Date().timeIntervalSince1970
        let localNames = fromWidget
            ? read().map(\.deviceName)
            : deviceStore.getAll().map(\.deviceName)
        var list = devices
            .filter { now - $0.lastUpdate < Double(disappearTime * 60) }
            .filter { !localNames.contains($0.deviceName) }
        if let first = devices.first, !list.contains(first), !list.isEmpty {
            list.insert(first, at: 0)
        }
        if let first = list.first, list.count == 1, !first.hasBattery {
            return []
        }
        return list
    }
}

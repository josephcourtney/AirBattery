import Foundation

public struct AirBatteryCLIItem: Codable, Equatable {
    public let device: String
    public let level: Int
    public let status: String
    public let update: Int

    init(device: Device, now: Date = Date()) {
        let status: String
        if device.isCharged || device.acPowered || device.isCharging != 0 {
            status = "+"
        } else if device.isPaused {
            status = "="
        } else {
            status = "-"
        }

        let stamp = device.realUpdate != 0 ? device.realUpdate : device.lastUpdate
        self.device = device.deviceName
        self.level = device.batteryLevel
        self.status = status
        self.update = Int((stamp - now.timeIntervalSince1970) / 60)
    }
}

public enum AirBatteryCLI {
    public static func items(
        includeNearcast: Bool,
        now: Date = Date()
    ) -> [AirBatteryCLIItem] {
        var devices = BatterySnapshotStore.read()
        if includeNearcast {
            for url in getFiles(
                withExtension: "json",
                in: BatterySnapshotStore.nearcastDirectory
            ) {
                devices += BatterySnapshotStore.nearcastDevicesForWidget(at: url)
            }
        }
        return devices.map { AirBatteryCLIItem(device: $0, now: now) }
    }
}

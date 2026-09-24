import Foundation

@MainActor
final class BatteryAlertService {
    private let deviceStore: DeviceStore
    private let nearcast: MultipeerService
    private var snoozedUntil: [String: TimeInterval] = [:]

    init(deviceStore: DeviceStore, nearcast: MultipeerService) {
        self.deviceStore = deviceStore
        self.nearcast = nearcast
    }

    func snooze(deviceName: String, for interval: TimeInterval = 30 * 60) {
        snoozedUntil[deviceName] = Date().timeIntervalSince1970 + interval
    }

    func evaluate(now: Date = Date()) {
        let timestamp = now.timeIntervalSince1970
        snoozedUntil = snoozedUntil.filter { $0.value >= timestamp }

        let alerts = UserDefaults.standard.get(
            objectType: [btAlert].self,
            forKey: "alertList"
        ) ?? []
        guard !alerts.isEmpty else { return }

        var devices = deviceStore.getAll()
        devices.append(ib2ab(InternalBattery.status))
        for url in getFiles(
            withExtension: "json",
            in: BatterySnapshotStore.nearcastDirectory
        ) {
            devices += BatterySnapshotStore.nearcastDevices(
                at: url,
                deviceStore: deviceStore
            )
        }

        for device in devices {
            guard let alert = alerts.first(where: { $0.name == device.deviceName }) else {
                continue
            }
            if let until = snoozedUntil[device.deviceName], until > timestamp {
                return
            }

            if device.batteryLevel < alert.low,
               device.isCharging == 0,
               alert.lowOn {
                send(
                    title: "Low Battery".local,
                    body: String(
                        format: "\"%@\" remaining battery %d%%".local,
                        device.deviceName,
                        device.batteryLevel
                    ),
                    sound: alert.lowSound,
                    deviceName: device.deviceName
                )
            }

            if device.batteryLevel > alert.full,
               device.isCharging != 0,
               alert.fullOn {
                send(
                    title: "Fully Charged".local,
                    body: String(
                        format: "\"%@\" battery has reached %d%%".local,
                        device.deviceName,
                        device.batteryLevel
                    ),
                    sound: alert.fullSound,
                    deviceName: device.deviceName
                )
            }
        }
    }

    private func send(
        title: String,
        body: String,
        sound: Bool,
        deviceName: String
    ) {
        createNotification(
            title: title,
            message: body,
            alertSound: sound,
            delay: true,
            info: deviceName
        )
        guard AppPreferences.nearCast,
              let message = nearcast.createInfo(title: title, info: body)
        else { return }
        nearcast.sendMessage(message)
    }
}

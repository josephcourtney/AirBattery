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
        action: @escaping () -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            action()
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

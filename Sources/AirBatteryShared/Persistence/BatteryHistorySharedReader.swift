import Foundation

package enum BatteryHistorySharedReader {
    private static let storageKey = "batteryHistory.v1"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.com.josephcourtney.AirBattery") ?? .standard
    }

    package static func estimate(
        canonicalID: String,
        deviceType: String,
        now: Date = Date()
    ) -> BatteryTimeEstimate? {
        guard let data = defaults.data(forKey: storageKey),
              let history = try? JSONDecoder().decode(
                  [String: [BatteryHistorySample]].self,
                  from: data
              )
        else {
            return nil
        }

        let key = DeviceStorageKey.make(
            canonicalID: canonicalID,
            deviceType: deviceType
        )
        return BatteryTimeEstimator.estimate(
            samples: history[key] ?? [],
            now: now
        )
    }

    package static func estimate(for device: Device, now: Date = Date()) -> BatteryTimeEstimate? {
        guard device.deviceID != "@MacInternalBattery" else { return nil }
        return estimate(
            canonicalID: device.deviceID,
            deviceType: device.deviceType,
            now: now
        )
    }
}

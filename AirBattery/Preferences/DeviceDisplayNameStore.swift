import Foundation

enum DeviceDisplayNameStore {
    static let didChangeNotification = Notification.Name(
        "AirBatteryDeviceDisplayNameDidChange"
    )

    private static let storageKey = "deviceDisplayNameOverrides.v1"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.com.josephcourtney.AirBattery") ??
            .standard
    }

    static func key(canonicalID: String, deviceType: String) -> String {
        DeviceStorageKey.make(canonicalID: canonicalID, deviceType: deviceType)
    }

    static func override(forKey key: String) -> String? {
        guard let value = overrides()[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    static func displayName(forKey key: String, fallback: String) -> String {
        override(forKey: key) ?? fallback
    }

    static func setOverride(_ value: String?, forKey key: String) {
        var values = overrides()
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            values.removeValue(forKey: key)
        } else {
            values[key] = trimmed
        }
        defaults.set(values, forKey: storageKey)
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: key
        )
    }

    private static func overrides() -> [String: String] {
        defaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
}

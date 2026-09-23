import Foundation

enum AppPreferences {
    private static func bool(_ key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func integer(_ key: String, default defaultValue: Int) -> Int {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.integer(forKey: key)
    }

    private static func string(_ key: String, default defaultValue: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? defaultValue
    }

    static var showOn: String {
        get { string("showOn", default: "sbar") }
        set { UserDefaults.standard.set(newValue, forKey: "showOn") }
    }

    static var machineType: String {
        get { string("machineType", default: "mac") }
        set { UserDefaults.standard.set(newValue, forKey: "machineType") }
    }

    static var deviceName: String {
        get { string("deviceName", default: "Mac") }
        set { UserDefaults.standard.set(newValue, forKey: "deviceName") }
    }

    static var nearcastGroupID: String {
        get { string("nearcastGroupID", default: "") }
        set { UserDefaults.standard.set(newValue, forKey: "nearcastGroupID") }
    }

    static var nearcastSharingKey: String {
        get { string("nearcastSharingKey", default: "") }
        set { UserDefaults.standard.set(newValue, forKey: "nearcastSharingKey") }
    }

    static var nearCast: Bool {
        get { bool("nearCast", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "nearCast") }
    }

    static var launchAtLogin: Bool {
        get { bool("launchAtLogin", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
    }

    static var intBattOnStatusBar: Bool {
        get { bool("intBattOnStatusBar", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "intBattOnStatusBar") }
    }

    static var batteryPercent: String {
        get { string("batteryPercent", default: "outside") }
        set { UserDefaults.standard.set(newValue, forKey: "batteryPercent") }
    }

    static var alertSound: Bool {
        get { bool("alertSound", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "alertSound") }
    }

    static var readBTHID: Bool {
        get { bool("readBTHID", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "readBTHID") }
    }

    static var hideLevel: Int {
        get { integer("hideLevel", default: 90) }
        set { UserDefaults.standard.set(newValue, forKey: "hideLevel") }
    }

    static var disappearTime: Int {
        get { integer("disappearTime", default: 20) }
        set { UserDefaults.standard.set(newValue, forKey: "disappearTime") }
    }

    static var whitelistMode: Bool {
        get { bool("whitelistMode", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "whitelistMode") }
    }

    static var iosBatteryStyle: Bool {
        get { bool("iosBatteryStyle", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "iosBatteryStyle") }
    }

    static var updateInterval: Int {
        get { integer("updateInterval", default: 1) }
        set { UserDefaults.standard.set(newValue, forKey: "updateInterval") }
    }

    static var widgetInterval: Int {
        get { integer("widgetInterval", default: 0) }
        set { UserDefaults.standard.set(newValue, forKey: "widgetInterval") }
    }

    static var carouselMode: Bool {
        get { bool("carouselMode", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "carouselMode") }
    }

    static var alertLevel: Int {
        get { integer("alertLevel", default: 10) }
        set { UserDefaults.standard.set(newValue, forKey: "alertLevel") }
    }

    static var fullyLevel: Int {
        get { integer("fullyLevel", default: 100) }
        set { UserDefaults.standard.set(newValue, forKey: "fullyLevel") }
    }

    static var ideviceOverBLE: Bool {
        get { bool("ideviceOverBLE", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "ideviceOverBLE") }
    }

    static var readBTDevice: Bool {
        get { bool("readBTDevice", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "readBTDevice") }
    }

    static var readBLEDevice: Bool {
        get { bool("readBLEDevice", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "readBLEDevice") }
    }

    static var bleDiscoveryMode: String {
        get { string("bleDiscoveryMode", default: "review") }
        set { UserDefaults.standard.set(newValue, forKey: "bleDiscoveryMode") }
    }

    static var readPencil: Bool {
        get { bool("readPencil", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "readPencil") }
    }

    static var readIDevice: Bool {
        get { bool("readIDevice", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "readIDevice") }
    }

    static var appearance: String {
        get { string("appearance", default: "auto") }
        set { UserDefaults.standard.set(newValue, forKey: "appearance") }
    }

    static var logReaderLastTS: String {
        get { string("logReaderLastTS", default: "") }
        set { UserDefaults.standard.set(newValue, forKey: "logReaderLastTS") }
    }

    static var pinnedNames: [String] {
        get { UserDefaults.standard.stringArray(forKey: "pinnedList") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "pinnedList") }
    }

    static var hiddenDeviceNames: [String] {
        get { UserDefaults.standard.stringArray(forKey: "blackList") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "blackList") }
    }

    static var nameRules: [String] {
        get { UserDefaults.standard.stringArray(forKey: "blockedDevices") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "blockedDevices") }
    }

    static var neverRemind: [String] {
        get { UserDefaults.standard.stringArray(forKey: "neverRemindMe") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "neverRemindMe") }
    }
}

enum BatteryHistorySharedReader {
    private static let storageKey = "batteryHistory.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.com.josephcourtney.AirBattery") ??
            .standard
    }

    static func estimate(
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

        let key = DeviceDisplayNameStore.key(
            canonicalID: canonicalID,
            deviceType: deviceType
        )
        return BatteryTimeEstimator.estimate(
            samples: history[key] ?? [],
            now: now
        )
    }
}

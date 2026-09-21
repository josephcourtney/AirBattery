import Foundation

enum AppPreferences {
    private static func bool(_ key: String, default defaultValue: Bool) -> Bool {
        guard ud.object(forKey: key) != nil else { return defaultValue }
        return ud.bool(forKey: key)
    }

    private static func integer(_ key: String, default defaultValue: Int) -> Int {
        guard ud.object(forKey: key) != nil else { return defaultValue }
        return ud.integer(forKey: key)
    }

    private static func string(_ key: String, default defaultValue: String) -> String {
        ud.string(forKey: key) ?? defaultValue
    }

    static var showOn: String {
        get { string("showOn", default: "sbar") }
        set { ud.set(newValue, forKey: "showOn") }
    }

    static var machineType: String {
        get { string("machineType", default: "mac") }
        set { ud.set(newValue, forKey: "machineType") }
    }

    static var deviceName: String {
        get { string("deviceName", default: "Mac") }
        set { ud.set(newValue, forKey: "deviceName") }
    }

    static var nearcastGroupID: String {
        get { string("nearcastGroupID", default: "") }
        set { ud.set(newValue, forKey: "nearcastGroupID") }
    }

    static var nearcastSharingKey: String {
        get { string("nearcastSharingKey", default: "") }
        set { ud.set(newValue, forKey: "nearcastSharingKey") }
    }

    static var nearCast: Bool {
        get { bool("nearCast", default: false) }
        set { ud.set(newValue, forKey: "nearCast") }
    }

    static var launchAtLogin: Bool {
        get { bool("launchAtLogin", default: false) }
        set { ud.set(newValue, forKey: "launchAtLogin") }
    }

    static var intBattOnStatusBar: Bool {
        get { bool("intBattOnStatusBar", default: true) }
        set { ud.set(newValue, forKey: "intBattOnStatusBar") }
    }

    static var batteryPercent: String {
        get { string("batteryPercent", default: "outside") }
        set { ud.set(newValue, forKey: "batteryPercent") }
    }

    static var alertSound: Bool {
        get { bool("alertSound", default: true) }
        set { ud.set(newValue, forKey: "alertSound") }
    }

    static var readBTHID: Bool {
        get { bool("readBTHID", default: true) }
        set { ud.set(newValue, forKey: "readBTHID") }
    }

    static var hideLevel: Int {
        get { integer("hideLevel", default: 90) }
        set { ud.set(newValue, forKey: "hideLevel") }
    }

    static var disappearTime: Int {
        get { integer("disappearTime", default: 20) }
        set { ud.set(newValue, forKey: "disappearTime") }
    }

    static var whitelistMode: Bool {
        get { bool("whitelistMode", default: false) }
        set { ud.set(newValue, forKey: "whitelistMode") }
    }

    static var iosBatteryStyle: Bool {
        get { bool("iosBatteryStyle", default: false) }
        set { ud.set(newValue, forKey: "iosBatteryStyle") }
    }

    static var updateInterval: Int {
        get { integer("updateInterval", default: 1) }
        set { ud.set(newValue, forKey: "updateInterval") }
    }

    static var carouselMode: Bool {
        get { bool("carouselMode", default: true) }
        set { ud.set(newValue, forKey: "carouselMode") }
    }

    static var alertLevel: Int {
        get { integer("alertLevel", default: 10) }
        set { ud.set(newValue, forKey: "alertLevel") }
    }

    static var fullyLevel: Int {
        get { integer("fullyLevel", default: 100) }
        set { ud.set(newValue, forKey: "fullyLevel") }
    }

    static var ideviceOverBLE: Bool {
        get { bool("ideviceOverBLE", default: false) }
        set { ud.set(newValue, forKey: "ideviceOverBLE") }
    }

    static var readBTDevice: Bool {
        get { bool("readBTDevice", default: true) }
        set { ud.set(newValue, forKey: "readBTDevice") }
    }

    static var readBLEDevice: Bool {
        get { bool("readBLEDevice", default: false) }
        set { ud.set(newValue, forKey: "readBLEDevice") }
    }

    static var bleDiscoveryMode: String {
        get { string("bleDiscoveryMode", default: "review") }
        set { ud.set(newValue, forKey: "bleDiscoveryMode") }
    }

    static var readPencil: Bool {
        get { bool("readPencil", default: false) }
        set { ud.set(newValue, forKey: "readPencil") }
    }

    static var readIDevice: Bool {
        get { bool("readIDevice", default: true) }
        set { ud.set(newValue, forKey: "readIDevice") }
    }

    static var appearance: String {
        get { string("appearance", default: "auto") }
        set { ud.set(newValue, forKey: "appearance") }
    }

    static var logReaderLastTS: String {
        get { string("logReaderLastTS", default: "") }
        set { ud.set(newValue, forKey: "logReaderLastTS") }
    }

    static var pinnedNames: [String] {
        get { ud.stringArray(forKey: "pinnedList") ?? [] }
        set { ud.set(newValue, forKey: "pinnedList") }
    }

    static var hiddenDeviceNames: [String] {
        get { ud.stringArray(forKey: "blackList") ?? [] }
        set { ud.set(newValue, forKey: "blackList") }
    }

    static var neverRemind: [String] {
        get { ud.stringArray(forKey: "neverRemindMe") ?? [] }
        set { ud.set(newValue, forKey: "neverRemindMe") }
    }
}

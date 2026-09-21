import Foundation

enum DeviceObservationSource: String, Codable, Equatable {
    case ble
    case libimobiledevice
}

struct DeviceIdentifierSet: Equatable {
    var canonicalID: String
    var mobileDeviceID: String?
    var bleDeviceID: String?

    mutating func merge(
        canonicalID incomingCanonicalID: String,
        mobileDeviceID incomingMobileDeviceID: String?,
        bleDeviceID incomingBLEDeviceID: String?
    ) {
        if let incomingMobileDeviceID, !incomingMobileDeviceID.isEmpty {
            mobileDeviceID = incomingMobileDeviceID
        }
        if let incomingBLEDeviceID, !incomingBLEDeviceID.isEmpty {
            bleDeviceID = incomingBLEDeviceID
        }

        if let mobileDeviceID, !mobileDeviceID.isEmpty {
            canonicalID = mobileDeviceID
        } else if !incomingCanonicalID.isEmpty {
            canonicalID = incomingCanonicalID
        } else if let bleDeviceID, !bleDeviceID.isEmpty {
            canonicalID = bleDeviceID
        }
    }

    func matches(_ identifier: String) -> Bool {
        canonicalID == identifier ||
            mobileDeviceID == identifier ||
            bleDeviceID == identifier
    }
}

enum BatteryComponentRole: String, Codable, Hashable {
    case primary
    case caseBattery
    case leftEarbud
    case rightEarbud
    case earbuds
}

enum DevicePresentationNaming {
    static func compactName(deviceType: String, displayName: String) -> String {
        let type = deviceType.lowercased()
        let name = displayName.lowercased()

        if type == "ap_case" || type.hasPrefix("ap_pod") || name.contains("airpods") {
            return "AirPods"
        }
        if type.contains("watch") || name.contains("apple watch") {
            return "Watch"
        }
        if type.contains("iphone") {
            return "iPhone"
        }
        if type.contains("ipad") {
            return "iPad"
        }
        if type.contains("mac") || type.contains("book") || type.contains("mini") ||
            type.contains("studio") || type.contains("imac") {
            return "Mac"
        }
        return displayName
    }

    static func componentLabel(_ role: BatteryComponentRole) -> String {
        switch role {
        case .primary: return "Battery"
        case .caseBattery: return "Case"
        case .leftEarbud: return "Left"
        case .rightEarbud: return "Right"
        case .earbuds: return "Earbuds"
        }
    }
}

enum NearcastCredentialFormat {
    static let groupPrefix = "ncg-"
    static let sharingKeyPrefix = "nck2-"
    static let setupPrefix = "airbattery-nearcast"

    static func isLegacySharingKey(_ value: String) -> Bool {
        guard value.count == 23, value.hasPrefix("nc-") else { return false }
        return value.allSatisfy { character in
            character.isLetter || character.isNumber || character == "-"
        }
    }

    static func isValid(groupID: String, sharingKey: String) -> Bool {
        if sharingKey.hasPrefix(sharingKeyPrefix) {
            guard groupID.hasPrefix(groupPrefix),
                  groupID.count == groupPrefix.count + 16
            else {
                return false
            }
            let encoded = String(sharingKey.dropFirst(sharingKeyPrefix.count))
            return Data(base64Encoded: encoded)?.count == 32
        }

        return isLegacySharingKey(sharingKey) &&
            groupID == String(sharingKey.prefix(15))
    }

    static func setupCode(groupID: String, sharingKey: String) -> String? {
        guard isValid(groupID: groupID, sharingKey: sharingKey) else { return nil }
        return "\(setupPrefix):\(groupID):\(sharingKey)"
    }

    static func parseSetupCode(_ code: String) -> (groupID: String, sharingKey: String)? {
        let parts = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              String(parts[0]) == setupPrefix
        else {
            return nil
        }

        let groupID = String(parts[1])
        let sharingKey = String(parts[2])
        guard isValid(groupID: groupID, sharingKey: sharingKey) else { return nil }
        return (groupID, sharingKey)
    }
}

enum IDeviceConnectionSource: String, Hashable {
    case network = "Network"
    case usb = "USB"
}

struct IDeviceDiscoveryCandidate: Identifiable, Hashable {
    let identifier: String
    var name: String?
    var deviceType: String?
    var model: String?
    var sources: Set<IDeviceConnectionSource>
    var lastSeen: Date
    var batteryReadable: Bool

    var id: String { identifier }

    mutating func merge(
        source: IDeviceConnectionSource,
        name: String? = nil,
        deviceType: String? = nil,
        model: String? = nil,
        batteryReadable: Bool? = nil,
        lastSeen: Date
    ) {
        sources.insert(source)
        self.lastSeen = lastSeen
        if let name { self.name = name }
        if let deviceType { self.deviceType = deviceType }
        if let model { self.model = model }
        if let batteryReadable {
            self.batteryReadable = self.batteryReadable || batteryReadable
        }
    }
}

final class ExclusiveScanGate {
    private let lock = NSLock()
    private var inFlight = false

    func tryBegin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    func end() {
        lock.lock()
        inFlight = false
        lock.unlock()
    }
}

struct CompanionBatteryResponse: Decodable, Equatable {
    struct Watch: Decodable, Equatable {
        let id: String
        let name: String
        let productType: String
        let batteryLevel: Int
        let isCharging: Bool
    }

    let watches: [Watch]

    var validWatches: [Watch] {
        watches.filter { (0...100).contains($0.batteryLevel) }
    }
}

final class CompanionProbeState {
    private let lock = NSLock()
    private let interval: TimeInterval
    private var disabledForLaunch = false
    private var lastProbe: [String: TimeInterval] = [:]

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func shouldProbe(
        parentID: String,
        deviceType: String,
        now: TimeInterval
    ) -> Bool {
        guard deviceType.caseInsensitiveCompare("iPhone") == .orderedSame else {
            return false
        }

        lock.lock()
        defer { lock.unlock() }

        guard !disabledForLaunch else { return false }
        if let previous = lastProbe[parentID], now - previous < interval {
            return false
        }

        lastProbe[parentID] = now
        return true
    }

    func disableForLaunch() {
        lock.lock()
        disabledForLaunch = true
        lock.unlock()
    }

    var isDisabledForLaunch: Bool {
        lock.lock()
        defer { lock.unlock() }
        return disabledForLaunch
    }
}

struct IDeviceMetadata: Equatable {
    let name: String
    let productType: String
    let deviceClass: String
}

struct IDeviceBatteryReading: Equatable {
    let level: Int
    let isCharging: Bool
}

enum IDeviceInfoParser {
    private static func value(for key: String, in output: String) -> String? {
        let prefix = key + ":"
        for line in output.components(separatedBy: .newlines) {
            guard line.hasPrefix(prefix) else { continue }
            return String(line.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func metadata(from output: String) -> IDeviceMetadata? {
        guard let name = value(for: "DeviceName", in: output),
              let productType = value(for: "ProductType", in: output),
              let deviceClass = value(for: "DeviceClass", in: output),
              !name.isEmpty,
              !productType.isEmpty,
              !deviceClass.isEmpty
        else {
            return nil
        }

        return IDeviceMetadata(
            name: name,
            productType: productType,
            deviceClass: deviceClass
        )
    }

    static func battery(from output: String) -> IDeviceBatteryReading? {
        guard let levelText = value(for: "BatteryCurrentCapacity", in: output),
              let level = Int(levelText),
              let chargingText = value(for: "BatteryIsCharging", in: output)
        else {
            return nil
        }

        let isCharging: Bool
        switch chargingText.lowercased() {
        case "true", "yes", "1":
            isCharging = true
        case "false", "no", "0":
            isCharging = false
        default:
            return nil
        }

        return IDeviceBatteryReading(level: level, isCharging: isCharging)
    }
}

enum EarbudMergePolicy {
    static func mergedLevel(
        enabled: Bool,
        threshold: Int,
        leftLevel: Int,
        leftCharging: Int,
        rightLevel: Int,
        rightCharging: Int
    ) -> Int? {
        guard enabled,
              leftCharging == rightCharging,
              abs(leftLevel - rightLevel) <= threshold
        else {
            return nil
        }
        return min(leftLevel, rightLevel)
    }

    static func mergedCharging(
        enabled: Bool,
        threshold: Int,
        leftLevel: Int,
        leftCharging: Int,
        rightLevel: Int,
        rightCharging: Int
    ) -> Int? {
        guard mergedLevel(
            enabled: enabled,
            threshold: threshold,
            leftLevel: leftLevel,
            leftCharging: leftCharging,
            rightLevel: rightLevel,
            rightCharging: rightCharging
        ) != nil else {
            return nil
        }
        return leftCharging
    }
}

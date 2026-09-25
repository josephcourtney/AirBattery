import Foundation

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

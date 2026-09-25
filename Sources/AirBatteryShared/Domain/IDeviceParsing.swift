import Foundation

package enum IDeviceConnectionSource: String, Hashable {
    case network = "Network"
    case usb = "USB"
}

package struct IDeviceDiscoveryCandidate: Identifiable, Hashable {
    package let identifier: String
    package var name: String?
    package var deviceType: String?
    package var model: String?
    package var sources: Set<IDeviceConnectionSource>
    package var lastSeen: Date
    package var batteryReadable: Bool

    package init(
        identifier: String,
        name: String?,
        deviceType: String?,
        model: String?,
        sources: Set<IDeviceConnectionSource>,
        lastSeen: Date,
        batteryReadable: Bool
    ) {
        self.identifier = identifier
        self.name = name
        self.deviceType = deviceType
        self.model = model
        self.sources = sources
        self.lastSeen = lastSeen
        self.batteryReadable = batteryReadable
    }

    package var id: String { identifier }

    package mutating func merge(
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

package struct CompanionBatteryResponse: Decodable, Equatable {
    package struct Watch: Decodable, Equatable {
        package let id: String
        package let name: String
        package let productType: String
        package let batteryLevel: Int
        package let isCharging: Bool

        package init(
            id: String,
            name: String,
            productType: String,
            batteryLevel: Int,
            isCharging: Bool
        ) {
            self.id = id
            self.name = name
            self.productType = productType
            self.batteryLevel = batteryLevel
            self.isCharging = isCharging
        }
    }

    package let watches: [Watch]

    package var validWatches: [Watch] {
        watches.filter { (0...100).contains($0.batteryLevel) }
    }
}

package final class CompanionProbeState {
    private let lock = NSLock()
    private let interval: TimeInterval
    private var disabledForLaunch = false
    private var lastProbe: [String: TimeInterval] = [:]

    package init(interval: TimeInterval) {
        self.interval = interval
    }

    package func shouldProbe(
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

    package func disableForLaunch() {
        lock.lock()
        disabledForLaunch = true
        lock.unlock()
    }

    package var isDisabledForLaunch: Bool {
        lock.lock()
        defer { lock.unlock() }
        return disabledForLaunch
    }
}

package struct IDeviceMetadata: Equatable {
    package let name: String
    package let productType: String
    package let deviceClass: String

    package init(name: String, productType: String, deviceClass: String) {
        self.name = name
        self.productType = productType
        self.deviceClass = deviceClass
    }
}

package struct IDeviceBatteryReading: Equatable {
    package let level: Int
    package let isCharging: Bool

    package init(level: Int, isCharging: Bool) {
        self.level = level
        self.isCharging = isCharging
    }
}

package enum IDeviceInfoParser {
    private static func value(for key: String, in output: String) -> String? {
        let prefix = key + ":"
        for line in output.components(separatedBy: .newlines) {
            guard line.hasPrefix(prefix) else { continue }
            return String(line.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    package static func metadata(from output: String) -> IDeviceMetadata? {
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

    package static func battery(from output: String) -> IDeviceBatteryReading? {
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

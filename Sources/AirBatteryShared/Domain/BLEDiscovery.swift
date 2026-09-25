import Foundation

package enum BLEDiscoveryMode: String, CaseIterable, Codable {
    case passive
    case review
    case automatic

    package var title: String {
        switch self {
        case .passive: return "Observe only"
        case .review: return "Ask before querying"
        case .automatic: return "Query automatically"
        }
    }

    package var detail: String {
        switch self {
        case .passive:
            return "AirBattery observes unknown devices without connecting. Only devices explicitly allowed for battery queries may be contacted."
        case .review:
            return "AirBattery observes unknown devices and suggests likely battery devices in Devices. It connects only after you allow battery queries."
        case .automatic:
            return "AirBattery may connect to promising newly discovered BLE devices automatically when a battery query is needed."
        }
    }
}

package enum BLEDevicePolicy: String, CaseIterable, Codable {
    case allow
    case observe
    case ignore

    package var title: String {
        switch self {
        case .allow: return "Allow queries"
        case .observe: return "Passive only"
        case .ignore: return "Ignore"
        }
    }
}

package struct BLEDeviceRule: Codable, Hashable, Identifiable {
    package let identifier: String
    package var name: String
    package var policy: BLEDevicePolicy

    package init(identifier: String, name: String, policy: BLEDevicePolicy) {
        self.identifier = identifier
        self.name = name
        self.policy = policy
    }

    package var id: String { identifier }
}

package struct BLELogicalDeviceRule: Codable, Hashable, Identifiable {
    package let key: String
    package var name: String
    package var policy: BLEDevicePolicy

    package init(key: String, name: String, policy: BLEDevicePolicy) {
        self.key = key
        self.name = name
        self.policy = policy
    }

    package var id: String { key }
}

package struct BLEDiscoveryCandidate: Hashable, Identifiable {
    package let identifier: String
    package var name: String
    package var rssi: Int
    package var smoothedRSSI: Double
    package var firstSeen: Date
    package var lastSeen: Date
    package var seenCount: Int
    package var isConnectable: Bool
    package var advertisesBatteryService: Bool
    package var hasPassiveBatteryData: Bool
    package var matchesPairedName: Bool
    package var lastProbeResult: String?

    package init(
        identifier: String,
        name: String,
        rssi: Int,
        smoothedRSSI: Double,
        firstSeen: Date,
        lastSeen: Date,
        seenCount: Int,
        isConnectable: Bool,
        advertisesBatteryService: Bool,
        hasPassiveBatteryData: Bool,
        matchesPairedName: Bool,
        lastProbeResult: String?
    ) {
        self.identifier = identifier
        self.name = name
        self.rssi = rssi
        self.smoothedRSSI = smoothedRSSI
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.seenCount = seenCount
        self.isConnectable = isConnectable
        self.advertisesBatteryService = advertisesBatteryService
        self.hasPassiveBatteryData = hasPassiveBatteryData
        self.matchesPairedName = matchesPairedName
        self.lastProbeResult = lastProbeResult
    }

    package var id: String { identifier }
    package var displayRSSI: Int { Int(smoothedRSSI.rounded()) }
}

package struct BLELogicalDeviceSnapshot: Identifiable {
    package let key: String
    package let name: String
    package let policy: BLEDevicePolicy?
    package let identities: [BLEDiscoveryCandidate]
    package let exactRules: [BLEDeviceRule]

    package init(
        key: String,
        name: String,
        policy: BLEDevicePolicy?,
        identities: [BLEDiscoveryCandidate],
        exactRules: [BLEDeviceRule]
    ) {
        self.key = key
        self.name = name
        self.policy = policy
        self.identities = identities
        self.exactRules = exactRules
    }

    package var id: String { key }
}

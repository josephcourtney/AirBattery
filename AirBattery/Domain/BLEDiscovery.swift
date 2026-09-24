import Foundation

enum BLEDiscoveryMode: String, CaseIterable, Codable {
    case passive
    case review
    case automatic

    var title: String {
        switch self {
        case .passive: return "Observe only"
        case .review: return "Ask before querying"
        case .automatic: return "Query automatically"
        }
    }

    var detail: String {
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

enum BLEDevicePolicy: String, CaseIterable, Codable {
    case allow
    case observe
    case ignore

    var title: String {
        switch self {
        case .allow: return "Allow queries"
        case .observe: return "Passive only"
        case .ignore: return "Ignore"
        }
    }
}

struct BLEDeviceRule: Codable, Hashable, Identifiable {
    let identifier: String
    var name: String
    var policy: BLEDevicePolicy

    var id: String { identifier }
}

struct BLELogicalDeviceRule: Codable, Hashable, Identifiable {
    let key: String
    var name: String
    var policy: BLEDevicePolicy

    var id: String { key }
}

struct BLEDiscoveryCandidate: Hashable, Identifiable {
    let identifier: String
    var name: String
    var rssi: Int
    var smoothedRSSI: Double
    var firstSeen: Date
    var lastSeen: Date
    var seenCount: Int
    var isConnectable: Bool
    var advertisesBatteryService: Bool
    var hasPassiveBatteryData: Bool
    var matchesPairedName: Bool
    var lastProbeResult: String?

    var id: String { identifier }
    var displayRSSI: Int { Int(smoothedRSSI.rounded()) }
}

struct BLELogicalDeviceSnapshot: Identifiable {
    let key: String
    let name: String
    let policy: BLEDevicePolicy?
    let identities: [BLEDiscoveryCandidate]
    let exactRules: [BLEDeviceRule]

    var id: String { key }
}

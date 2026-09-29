import CryptoKit
import Foundation

/// Versioned application-owned state required to reproduce the Display settings
/// presentation without starting AirBattery's live monitoring graph.
///
/// Hrost treats the encoded bytes as opaque. AirBattery owns this schema and the
/// migration policy for future versions.
package struct AirBatterySettingsPresentationSnapshot: Codable, Sendable {
    package static let schemaIdentifier = "dev.airbattery.settings-presentation"
    package static let schemaVersion = 1

    package struct DiscoveryRule: Codable, Sendable {
        let identifier: String
        let name: String
        let policy: String
    }

    package struct LogicalDiscoveryRule: Codable, Sendable {
        let key: String
        let name: String
        let policy: String
    }

    package struct DiscoveryCandidate: Codable, Sendable {
        let identifier: String
        let name: String
        let rssi: Int
        let smoothedRSSI: Double
        let firstSeen: Date
        let lastSeen: Date
        let seenCount: Int
        let isConnectable: Bool
        let advertisesBatteryService: Bool
        let hasPassiveBatteryData: Bool
        let matchesPairedName: Bool
        let lastProbeResult: String?
    }

    package let scenarioID: String
    package let selectedSection: String

    package let showOn: String
    package let appearance: String
    package let showThisMac: String
    package let carouselMode: Bool
    package let colorfulBattery: Bool
    package let iosBatteryStyle: Bool
    package let intBattOnStatusBar: Bool
    package let batteryPercent: String
    package let hideLevel: Int
    package let twsMergeEnabled: Bool
    package let twsMerge: Int
    package let reverseWidgetList: Bool
    package let widgetInterval: Int
    package let deviceName: String
    package let showDebug: Bool

    package let readBLEDevice: Bool
    package let ideviceOverBLE: Bool
    package let bleDiscoveryMode: String
    package let discoveryRules: [DiscoveryRule]
    package let logicalDiscoveryRules: [LogicalDiscoveryRule]
    package let discoveryCandidates: [DiscoveryCandidate]

    package static func capture(scenarioID: String) -> Self {
        let defaults = UserDefaults.standard
        let discovery = BLEDiscoveryPolicyStore.shared
        return Self(
            scenarioID: scenarioID,
            selectedSection: SettingsSection.display.rawValue,
            showOn: defaults.string(forKey: "showOn") ?? "sbar",
            appearance: defaults.string(forKey: "appearance") ?? "auto",
            showThisMac: defaults.string(forKey: "showThisMac") ?? "icon",
            carouselMode: bool(defaults, "carouselMode", default: true),
            colorfulBattery: bool(defaults, "colorfulBattery", default: false),
            iosBatteryStyle: bool(defaults, "iosBatteryStyle", default: false),
            intBattOnStatusBar: bool(defaults, "intBattOnStatusBar", default: true),
            batteryPercent: defaults.string(forKey: "batteryPercent") ?? "outside",
            hideLevel: integer(defaults, "hideLevel", default: 90),
            twsMergeEnabled: bool(defaults, "twsMergeEnabled", default: true),
            twsMerge: integer(defaults, "twsMerge", default: 5),
            reverseWidgetList: bool(defaults, "revListOnWidget", default: false),
            widgetInterval: integer(defaults, "widgetInterval", default: 0),
            deviceName: defaults.string(forKey: "deviceName") ?? "Mac",
            showDebug: bool(defaults, "showDebug", default: false),
            readBLEDevice: bool(defaults, "readBLEDevice", default: false),
            ideviceOverBLE: bool(defaults, "ideviceOverBLE", default: false),
            bleDiscoveryMode: defaults.string(forKey: "bleDiscoveryMode") ?? "review",
            discoveryRules: discovery.rules.map {
                .init(identifier: $0.identifier, name: $0.name, policy: $0.policy.rawValue)
            },
            logicalDiscoveryRules: discovery.logicalRules.map {
                .init(key: $0.key, name: $0.name, policy: $0.policy.rawValue)
            },
            discoveryCandidates: discovery.candidates.map {
                .init(
                    identifier: $0.identifier,
                    name: $0.name,
                    rssi: $0.rssi,
                    smoothedRSSI: $0.smoothedRSSI,
                    firstSeen: $0.firstSeen,
                    lastSeen: $0.lastSeen,
                    seenCount: $0.seenCount,
                    isConnectable: $0.isConnectable,
                    advertisesBatteryService: $0.advertisesBatteryService,
                    hasPassiveBatteryData: $0.hasPassiveBatteryData,
                    matchesPairedName: $0.matchesPairedName,
                    lastProbeResult: $0.lastProbeResult
                )
            }
        )
    }

    package func restore() throws {
        guard selectedSection == SettingsSection.display.rawValue else {
            throw SnapshotError.unsupportedSection(selectedSection)
        }

        let rules = try discoveryRules.map { rule in
            guard let policy = BLEDevicePolicy(rawValue: rule.policy) else {
                throw SnapshotError.invalidDiscoveryPolicy(rule.policy)
            }
            return BLEDeviceRule(identifier: rule.identifier, name: rule.name, policy: policy)
        }
        let logicalRules = try logicalDiscoveryRules.map { rule in
            guard let policy = BLEDevicePolicy(rawValue: rule.policy) else {
                throw SnapshotError.invalidDiscoveryPolicy(rule.policy)
            }
            return BLELogicalDeviceRule(key: rule.key, name: rule.name, policy: policy)
        }
        let candidates = discoveryCandidates.map {
            BLEDiscoveryCandidate(
                identifier: $0.identifier,
                name: $0.name,
                rssi: $0.rssi,
                smoothedRSSI: $0.smoothedRSSI,
                firstSeen: $0.firstSeen,
                lastSeen: $0.lastSeen,
                seenCount: $0.seenCount,
                isConnectable: $0.isConnectable,
                advertisesBatteryService: $0.advertisesBatteryService,
                hasPassiveBatteryData: $0.hasPassiveBatteryData,
                matchesPairedName: $0.matchesPairedName,
                lastProbeResult: $0.lastProbeResult
            )
        }

        let defaults = UserDefaults.standard
        defaults.set(showOn, forKey: "showOn")
        defaults.set(appearance, forKey: "appearance")
        defaults.set(showThisMac, forKey: "showThisMac")
        defaults.set(carouselMode, forKey: "carouselMode")
        defaults.set(colorfulBattery, forKey: "colorfulBattery")
        defaults.set(iosBatteryStyle, forKey: "iosBatteryStyle")
        defaults.set(intBattOnStatusBar, forKey: "intBattOnStatusBar")
        defaults.set(batteryPercent, forKey: "batteryPercent")
        defaults.set(hideLevel, forKey: "hideLevel")
        defaults.set(twsMergeEnabled, forKey: "twsMergeEnabled")
        defaults.set(twsMerge, forKey: "twsMerge")
        defaults.set(reverseWidgetList, forKey: "revListOnWidget")
        defaults.set(widgetInterval, forKey: "widgetInterval")
        defaults.set(deviceName, forKey: "deviceName")
        defaults.set(showDebug, forKey: "showDebug")
        defaults.set(readBLEDevice, forKey: "readBLEDevice")
        defaults.set(ideviceOverBLE, forKey: "ideviceOverBLE")
        defaults.set(bleDiscoveryMode, forKey: "bleDiscoveryMode")

        BLEDiscoveryPolicyStore.shared.replacePresentationState(
            rules: rules,
            logicalRules: logicalRules,
            candidates: candidates
        )
    }

    package func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(self)
    }

    package static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(Self.self, from: data)
    }

    package func stableID() throws -> String {
        let digest = SHA256.hash(data: try encoded())
            .map { String(format: "%02x", $0) }
            .joined()
        return "settings-v1:\(digest)"
    }

    package enum SnapshotError: LocalizedError {
        case unsupportedSection(String)
        case invalidDiscoveryPolicy(String)

        package var errorDescription: String? {
            switch self {
            case let .unsupportedSection(section):
                "Unsupported settings presentation section '\(section)'."
            case let .invalidDiscoveryPolicy(policy):
                "Unknown BLE discovery policy '\(policy)'."
            }
        }
    }

    private static func bool(
        _ defaults: UserDefaults,
        _ key: String,
        default defaultValue: Bool
    ) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private static func integer(
        _ defaults: UserDefaults,
        _ key: String,
        default defaultValue: Int
    ) -> Int {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.integer(forKey: key)
    }
}

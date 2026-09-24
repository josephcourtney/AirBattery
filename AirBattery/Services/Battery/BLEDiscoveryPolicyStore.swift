import Combine
import Foundation

@MainActor
final class BLEDiscoveryPolicyStore: ObservableObject {
    static let shared = BLEDiscoveryPolicyStore()

    @Published private(set) var rules: [BLEDeviceRule]
    @Published private(set) var logicalRules: [BLELogicalDeviceRule]
    @Published private(set) var candidates: [BLEDiscoveryCandidate] = []

    private let rulesKey = "bleDevicePolicyRules"
    private let logicalRulesKey = "bleLogicalDevicePolicyRulesV1"

    private init() {
        let storedRules: [BLEDeviceRule]
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([BLEDeviceRule].self, from: data) {
            storedRules = decoded
        } else {
            storedRules = []
        }

        if let data = UserDefaults.standard.data(forKey: logicalRulesKey),
           let decoded = try? JSONDecoder().decode([BLELogicalDeviceRule].self, from: data) {
            rules = storedRules
            logicalRules = decoded
        } else {
            var remainingRules = storedRules
            var migratedRules: [BLELogicalDeviceRule] = []
            let grouped = Dictionary(grouping: storedRules) {
                Self.logicalKey(for: $0.name)
            }
            for (key, group) in grouped {
                let policies = Set(group.map(\.policy))
                guard policies.count == 1, let policy = policies.first, let name = group.first?.name else {
                    continue
                }
                migratedRules.append(BLELogicalDeviceRule(key: key, name: name, policy: policy))
                remainingRules.removeAll { Self.logicalKey(for: $0.name) == key }
            }
            rules = remainingRules
            logicalRules = migratedRules.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            if !migratedRules.isEmpty {
                if let data = try? JSONEncoder().encode(rules) {
                    UserDefaults.standard.set(data, forKey: rulesKey)
                }
                if let data = try? JSONEncoder().encode(logicalRules) {
                    UserDefaults.standard.set(data, forKey: logicalRulesKey)
                }
            }
        }
    }

    static func logicalKey(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func exactPolicy(identifier: String) -> BLEDevicePolicy? {
        rules.first(where: { $0.identifier == identifier })?.policy
    }

    func logicalPolicy(name: String) -> BLEDevicePolicy? {
        let key = Self.logicalKey(for: name)
        return logicalRules.first(where: { $0.key == key })?.policy
    }

    func explicitPolicy(identifier: String, name: String) -> BLEDevicePolicy? {
        exactPolicy(identifier: identifier) ?? logicalPolicy(name: name)
    }

    func setPolicy(identifier: String, name: String, policy: BLEDevicePolicy) {
        if let index = rules.firstIndex(where: { $0.identifier == identifier }) {
            rules[index].name = name
            rules[index].policy = policy
        } else {
            rules.append(BLEDeviceRule(identifier: identifier, name: name, policy: policy))
        }
        rules.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveRules()
    }

    func clearPolicy(identifier: String) {
        rules.removeAll(where: { $0.identifier == identifier })
        saveRules()
    }

    func setLogicalPolicy(name: String, policy: BLEDevicePolicy) {
        let key = Self.logicalKey(for: name)
        if let index = logicalRules.firstIndex(where: { $0.key == key }) {
            logicalRules[index].name = name
            logicalRules[index].policy = policy
        } else {
            logicalRules.append(BLELogicalDeviceRule(key: key, name: name, policy: policy))
        }
        // Changing the logical rule establishes a new baseline and clears old overrides.
        rules.removeAll { Self.logicalKey(for: $0.name) == key }
        logicalRules.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveRules()
        saveLogicalRules()
    }

    func clearLogicalPolicy(name: String) {
        let key = Self.logicalKey(for: name)
        logicalRules.removeAll(where: { $0.key == key })
        saveLogicalRules()
    }

    func recordObservation(
        identifier: String,
        name: String,
        rssi: Int,
        isConnectable: Bool,
        advertisesBatteryService: Bool,
        hasPassiveBatteryData: Bool,
        matchesPairedName: Bool
    ) {
        let now = Date()
        if let index = candidates.firstIndex(where: { $0.identifier == identifier }) {
            candidates[index].name = name
            candidates[index].rssi = rssi
            candidates[index].smoothedRSSI =
                candidates[index].smoothedRSSI * 0.75 + Double(rssi) * 0.25
            candidates[index].lastSeen = now
            candidates[index].seenCount += 1
            candidates[index].isConnectable = isConnectable
            candidates[index].advertisesBatteryService =
                candidates[index].advertisesBatteryService || advertisesBatteryService
            candidates[index].hasPassiveBatteryData =
                candidates[index].hasPassiveBatteryData || hasPassiveBatteryData
            candidates[index].matchesPairedName =
                candidates[index].matchesPairedName || matchesPairedName
        } else {
            candidates.append(
                BLEDiscoveryCandidate(
                    identifier: identifier,
                    name: name,
                    rssi: rssi,
                    smoothedRSSI: Double(rssi),
                    firstSeen: now,
                    lastSeen: now,
                    seenCount: 1,
                    isConnectable: isConnectable,
                    advertisesBatteryService: advertisesBatteryService,
                    hasPassiveBatteryData: hasPassiveBatteryData,
                    matchesPairedName: matchesPairedName,
                    lastProbeResult: nil
                )
            )
        }

        trimCandidateHistoryIfNeeded()
    }

    func candidate(identifier: String) -> BLEDiscoveryCandidate? {
        candidates.first(where: { $0.identifier == identifier })
    }

    var nearbyCandidates: [BLEDiscoveryCandidate] {
        candidates.filter {
            explicitPolicy(identifier: $0.identifier, name: $0.name) == nil
        }
    }

    var suggestedCandidates: [BLEDiscoveryCandidate] {
        let mode = BLEDiscoveryMode(rawValue: UserDefaults.standard.string(forKey: "bleDiscoveryMode") ?? "") ?? .review
        guard mode == .review else { return [] }
        guard UserDefaults.standard.bool(forKey: "readBLEDevice") || UserDefaults.standard.bool(forKey: "ideviceOverBLE") else { return [] }
        return nearbyCandidates.filter(isReviewCandidate)
    }

    var otherNearbyCandidates: [BLEDiscoveryCandidate] {
        let suggestedIDs = Set(suggestedCandidates.map(\.identifier))
        return nearbyCandidates.filter { !suggestedIDs.contains($0.identifier) }
    }

    var knownLogicalDevices: [BLELogicalDeviceSnapshot] {
        let keys = Set(logicalRules.map(\.key) + rules.map { Self.logicalKey(for: $0.name) })
        return keys.compactMap { key in
            let logicalRule = logicalRules.first(where: { $0.key == key })
            let exactRules = rules.filter { Self.logicalKey(for: $0.name) == key }
            let identities = candidates.filter { Self.logicalKey(for: $0.name) == key }
            let name = logicalRule?.name ?? exactRules.first?.name ?? identities.first?.name
            guard let name else { return nil }
            return BLELogicalDeviceSnapshot(
                key: key,
                name: name,
                policy: logicalRule?.policy,
                identities: identities,
                exactRules: exactRules
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func recordProbeResult(identifier: String, result: String) {
        guard let index = candidates.firstIndex(where: { $0.identifier == identifier }) else { return }
        candidates[index].lastProbeResult = result
    }

    func clearNearby() {
        candidates.removeAll {
            explicitPolicy(identifier: $0.identifier, name: $0.name) == nil
        }
    }

    private func trimCandidateHistoryIfNeeded() {
        while candidates.count > 100 {
            let removable = candidates.indices.filter {
                explicitPolicy(
                    identifier: candidates[$0].identifier,
                    name: candidates[$0].name
                ) == nil
            }
            let pool = removable.isEmpty ? Array(candidates.indices) : removable
            guard let oldestIndex = pool.min(by: {
                candidates[$0].lastSeen < candidates[$1].lastSeen
            }) else { return }
            candidates.remove(at: oldestIndex)
        }
    }

    func effectivePolicy(
        identifier: String,
        name: String,
        mode: BLEDiscoveryMode
    ) -> BLEDevicePolicy {
        if let explicit = explicitPolicy(identifier: identifier, name: name) {
            return explicit
        }
        switch mode {
        case .passive, .review:
            return .observe
        case .automatic:
            return .allow
        }
    }

    func isReviewCandidate(_ candidate: BLEDiscoveryCandidate) -> Bool {
        guard explicitPolicy(identifier: candidate.identifier, name: candidate.name) == nil else { return false }
        guard candidate.seenCount >= 3 else { return false }
        guard !candidate.hasPassiveBatteryData else { return false }
        return candidate.matchesPairedName ||
            candidate.advertisesBatteryService ||
            candidate.lastProbeResult != nil
    }

    var reviewCount: Int {
        suggestedCandidates.count
    }

    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }

    private func saveLogicalRules() {
        if let data = try? JSONEncoder().encode(logicalRules) {
            UserDefaults.standard.set(data, forKey: logicalRulesKey)
        }
    }
}

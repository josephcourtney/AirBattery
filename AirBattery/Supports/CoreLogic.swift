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
        if type.contains("keyboard") || name.contains("keyboard") {
            return "Keyboard"
        }
        if type.contains("mouse") || name.contains("mouse") ||
            name.contains("mx ergo") {
            return "Mouse"
        }
        if type.contains("trackpad") || name.contains("trackpad") {
            return "Trackpad"
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
        canonicalID + "|" + deviceType
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

struct BatteryHistorySample: Codable, Equatable, Sendable {
    let timestamp: TimeInterval
    let level: Int
    let charging: Bool
}

enum BatteryTimeEstimateKind: String, Codable, Equatable, Sendable {
    case charging
    case discharging
}

struct BatteryTimeEstimate: Equatable, Sendable {
    let kind: BatteryTimeEstimateKind
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let confidence: Double
}

enum BatteryTimeEstimator {
    private static let minimumSpan: TimeInterval = 10 * 60
    private static let maximumSpan: TimeInterval = 6 * 60 * 60
    private static let maximumPrediction: TimeInterval = 72 * 60 * 60

    static func estimate(
        samples: [BatteryHistorySample],
        now: Date = Date()
    ) -> BatteryTimeEstimate? {
        guard let latest = samples.last,
              (0...100).contains(latest.level),
              latest.level > 0,
              latest.level < 100
        else {
            return nil
        }

        let charging = latest.charging
        var tail: [BatteryHistorySample] = []
        for sample in samples.reversed() {
            guard sample.charging == charging else { break }
            if latest.timestamp - sample.timestamp > maximumSpan { break }
            tail.append(sample)
        }
        tail.reverse()

        guard tail.count >= 3,
              let first = tail.first,
              let last = tail.last,
              last.timestamp - first.timestamp >= minimumSpan
        else {
            return nil
        }

        let levelDelta = last.level - first.level
        guard abs(levelDelta) >= 2,
              (charging ? levelDelta > 0 : levelDelta < 0)
        else {
            return nil
        }

        let origin = first.timestamp
        let points = tail.map {
            (
                x: ($0.timestamp - origin) / 3600,
                y: Double($0.level)
            )
        }
        let meanX = points.map(\.x).reduce(0, +) / Double(points.count)
        let meanY = points.map(\.y).reduce(0, +) / Double(points.count)
        let covariance = points.reduce(0) {
            $0 + ($1.x - meanX) * ($1.y - meanY)
        }
        let variance = points.reduce(0) {
            $0 + pow($1.x - meanX, 2)
        }
        guard variance > 0 else { return nil }

        let slope = covariance / variance
        guard charging ? slope >= 0.5 : slope <= -0.2 else {
            return nil
        }

        let directionChanges = zip(tail, tail.dropFirst()).compactMap {
            pair -> Bool? in
            let delta = pair.1.level - pair.0.level
            guard delta != 0 else { return nil }
            return charging ? delta > 0 : delta < 0
        }
        let directionConsistency = directionChanges.isEmpty
            ? 0
            : Double(directionChanges.filter { $0 }.count) /
                Double(directionChanges.count)
        guard directionConsistency >= 0.75 else { return nil }

        let target = charging ? 100.0 : 0.0
        let hours = (target - Double(latest.level)) / slope
        let duration = hours * 3600
        guard duration >= 3 * 60,
              duration <= maximumPrediction
        else {
            return nil
        }

        let span = last.timestamp - first.timestamp
        let spanConfidence = min(1, span / 3600)
        let deltaConfidence = min(1, Double(abs(levelDelta)) / 6)
        let confidence = min(
            1,
            0.35 * spanConfidence +
                0.35 * deltaConfidence +
                0.30 * directionConsistency
        )
        guard confidence >= 0.55 else { return nil }

        let startDate = max(now, Date(timeIntervalSince1970: latest.timestamp))
        return BatteryTimeEstimate(
            kind: charging ? .charging : .discharging,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration),
            duration: duration,
            confidence: confidence
        )
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

final class ExclusiveScanGate: @unchecked Sendable {
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

struct BatteryEstimateState: Equatable {
    let ratePerHour: Double?
    let secondsRemaining: Double?
}

enum BatteryEstimateEngine {
    private static let minimumSampleInterval: TimeInterval = 120
    private static let maximumSampleInterval: TimeInterval = 6 * 3600
    private static let minimumPlausibleRate = 0.1
    private static let maximumPlausibleRate = 100.0
    private static let smoothingWeight = 0.3

    static func updated(
        previousLevel: Int,
        previousCharging: Bool,
        previousTime: TimeInterval,
        previousRatePerHour: Double?,
        previousSecondsRemaining: Double?,
        level: Int,
        charging: Bool,
        time: TimeInterval
    ) -> BatteryEstimateState {
        guard (0...100).contains(level), time > previousTime else {
            return BatteryEstimateState(
                ratePerHour: previousRatePerHour,
                secondsRemaining: previousSecondsRemaining
            )
        }

        if charging != previousCharging {
            return anchor(level: level, time: time)
        }

        if let anchor = decodedAnchor(
            ratePerHour: previousRatePerHour,
            secondsRemaining: previousSecondsRemaining
        ) {
            return updateFromAnchor(
                anchorLevel: anchor.level,
                anchorTime: anchor.time,
                level: level,
                charging: charging,
                time: time
            )
        }

        guard let previousRatePerHour,
              previousRatePerHour > 0,
              let previousSecondsRemaining,
              previousSecondsRemaining >= 0
        else {
            return anchor(level: previousLevel, time: previousTime)
        }

        let elapsed = time - previousTime
        let delta = level - previousLevel
        if delta == 0 {
            return BatteryEstimateState(
                ratePerHour: previousRatePerHour,
                secondsRemaining: max(0, previousSecondsRemaining - elapsed)
            )
        }

        let movedInExpectedDirection = charging ? delta > 0 : delta < 0
        guard movedInExpectedDirection else {
            return anchor(level: level, time: time)
        }

        let theoreticalPrevious = secondsToTarget(
            level: previousLevel,
            charging: charging,
            ratePerHour: previousRatePerHour
        )
        let sincePreviousLevel = max(
            0,
            theoreticalPrevious - previousSecondsRemaining
        ) + elapsed

        guard sincePreviousLevel >= minimumSampleInterval,
              sincePreviousLevel <= maximumSampleInterval
        else {
            return BatteryEstimateState(
                ratePerHour: previousRatePerHour,
                secondsRemaining: secondsToTarget(
                    level: level,
                    charging: charging,
                    ratePerHour: previousRatePerHour
                )
            )
        }

        let observed = abs(Double(delta)) / sincePreviousLevel * 3600
        guard (minimumPlausibleRate...maximumPlausibleRate).contains(observed) else {
            return BatteryEstimateState(
                ratePerHour: previousRatePerHour,
                secondsRemaining: secondsToTarget(
                    level: level,
                    charging: charging,
                    ratePerHour: previousRatePerHour
                )
            )
        }

        let rate = previousRatePerHour * (1 - smoothingWeight) +
            observed * smoothingWeight
        return BatteryEstimateState(
            ratePerHour: rate,
            secondsRemaining: secondsToTarget(
                level: level,
                charging: charging,
                ratePerHour: rate
            )
        )
    }

    static func seconds(fromNativeTimeLeft value: String) -> Double? {
        guard value != "∞", value != "…" else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              hours >= 0,
              (0..<60).contains(minutes)
        else {
            return nil
        }
        return (hours * 60 + minutes) * 60
    }

    private static func updateFromAnchor(
        anchorLevel: Int,
        anchorTime: TimeInterval,
        level: Int,
        charging: Bool,
        time: TimeInterval
    ) -> BatteryEstimateState {
        let elapsed = time - anchorTime
        guard elapsed > 0 else {
            return anchor(level: anchorLevel, time: anchorTime)
        }

        let delta = level - anchorLevel
        if delta == 0 {
            if elapsed > maximumSampleInterval {
                return anchor(level: level, time: time)
            }
            return anchor(level: anchorLevel, time: anchorTime)
        }

        let movedInExpectedDirection = charging ? delta > 0 : delta < 0
        guard movedInExpectedDirection else {
            return anchor(level: level, time: time)
        }

        guard elapsed >= minimumSampleInterval,
              elapsed <= maximumSampleInterval
        else {
            return elapsed > maximumSampleInterval
                ? anchor(level: level, time: time)
                : anchor(level: anchorLevel, time: anchorTime)
        }

        let observed = abs(Double(delta)) / elapsed * 3600
        guard (minimumPlausibleRate...maximumPlausibleRate).contains(observed) else {
            return anchor(level: level, time: time)
        }

        return BatteryEstimateState(
            ratePerHour: observed,
            secondsRemaining: secondsToTarget(
                level: level,
                charging: charging,
                ratePerHour: observed
            )
        )
    }

    private static func secondsToTarget(
        level: Int,
        charging: Bool,
        ratePerHour: Double
    ) -> Double {
        let pointsRemaining = charging ? max(0, 100 - level) : max(0, level)
        return Double(pointsRemaining) / ratePerHour * 3600
    }

    // Before the first usable rate, the two optional estimate fields carry an
    // internal negative sentinel. Formatting rejects the negative remaining
    // value, so it is never exposed as an ETA. This lets frequent unchanged
    // observations preserve the original level/time anchor without adding
    // another serialized state field to Device.
    private static func anchor(
        level: Int,
        time: TimeInterval
    ) -> BatteryEstimateState {
        BatteryEstimateState(
            ratePerHour: -Double(level + 1),
            secondsRemaining: -time
        )
    }

    private static func decodedAnchor(
        ratePerHour: Double?,
        secondsRemaining: Double?
    ) -> (level: Int, time: TimeInterval)? {
        guard let ratePerHour,
              let secondsRemaining,
              ratePerHour < 0,
              secondsRemaining < 0
        else {
            return nil
        }

        let level = Int((-ratePerHour - 1).rounded())
        guard (0...100).contains(level) else { return nil }
        return (level, -secondsRemaining)
    }
}

enum BatteryHistorySharedReader {
    private static let storageKey = "batteryHistory.v1"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: "group.com.josephcourtney.AirBattery") ?? .standard
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

enum BatteryEstimateFormatting {
    static func full(
        canonicalID: String,
        deviceType: String,
        level: Int,
        charging: Bool,
        charged: Bool,
        secondsRemaining: Double?,
        lastUpdate: TimeInterval,
        now: Date = Date()
    ) -> String? {
        if charged || (charging && level >= 100) {
            return "Full while charging"
        }

        if canonicalID != "@MacInternalBattery",
           let estimate = BatteryHistorySharedReader.estimate(
               canonicalID: canonicalID,
               deviceType: deviceType,
               now: now
           ) {
            return fullText(
                charging: estimate.kind == .charging,
                endDate: estimate.endDate,
                duration: estimate.duration
            )
        }

        guard let remaining = adjustedRemaining(
            secondsRemaining,
            lastUpdate: lastUpdate,
            now: now
        ) else {
            return nil
        }
        return fullText(
            charging: charging,
            endDate: now.addingTimeInterval(remaining),
            duration: remaining
        )
    }

    static func compact(
        canonicalID: String,
        deviceType: String,
        level: Int,
        charging: Bool,
        charged: Bool,
        secondsRemaining: Double?,
        lastUpdate: TimeInterval,
        now: Date = Date()
    ) -> String? {
        if charged || (charging && level >= 100) {
            return "Full"
        }

        if canonicalID != "@MacInternalBattery",
           let estimate = BatteryHistorySharedReader.estimate(
               canonicalID: canonicalID,
               deviceType: deviceType,
               now: now
           ) {
            return compactText(
                charging: estimate.kind == .charging,
                endDate: estimate.endDate
            )
        }

        guard let remaining = adjustedRemaining(
            secondsRemaining,
            lastUpdate: lastUpdate,
            now: now
        ) else {
            return nil
        }
        return compactText(
            charging: charging,
            endDate: now.addingTimeInterval(remaining)
        )
    }

    private static func adjustedRemaining(
        _ secondsRemaining: Double?,
        lastUpdate: TimeInterval,
        now: Date
    ) -> Double? {
        guard let secondsRemaining,
              secondsRemaining.isFinite,
              secondsRemaining >= 0
        else {
            return nil
        }
        let elapsed = max(0, now.timeIntervalSince1970 - lastUpdate)
        return max(0, secondsRemaining - elapsed)
    }

    private static func fullText(
        charging: Bool,
        endDate: Date,
        duration: TimeInterval
    ) -> String {
        let verb = charging ? "Full" : "Empty"
        return "\(verb) around \(clockString(endDate)) (~\(durationString(duration)))"
    }

    private static func compactText(charging: Bool, endDate: Date) -> String {
        "\(charging ? "Full" : "Empty") \(clockString(endDate))"
    }

    private static func clockString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func durationString(_ seconds: Double) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

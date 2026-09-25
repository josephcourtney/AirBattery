import Foundation

package struct BatteryHistorySample: Codable, Equatable, Sendable {
    package let timestamp: TimeInterval
    package let level: Int
    package let charging: Bool

    package init(timestamp: TimeInterval, level: Int, charging: Bool) {
        self.timestamp = timestamp
        self.level = level
        self.charging = charging
    }
}

package enum BatteryTimeEstimateKind: String, Codable, Equatable, Sendable {
    case charging
    case discharging
}

package struct BatteryTimeEstimate: Equatable, Sendable {
    package let kind: BatteryTimeEstimateKind
    package let startDate: Date
    package let endDate: Date
    package let duration: TimeInterval
    package let confidence: Double

    package init(
        kind: BatteryTimeEstimateKind,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        confidence: Double
    ) {
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.confidence = confidence
    }
}

package enum BatteryTimeEstimator {
    private static let minimumSpan: TimeInterval = 10 * 60
    private static let maximumSpan: TimeInterval = 6 * 60 * 60
    private static let maximumPrediction: TimeInterval = 72 * 60 * 60

    package static func estimate(
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

package struct BatteryEstimateState: Equatable {
    package let ratePerHour: Double?
    package let secondsRemaining: Double?

    package init(ratePerHour: Double?, secondsRemaining: Double?) {
        self.ratePerHour = ratePerHour
        self.secondsRemaining = secondsRemaining
    }
}

package enum BatteryEstimateEngine {
    private static let minimumSampleInterval: TimeInterval = 120
    private static let maximumSampleInterval: TimeInterval = 6 * 3600
    private static let minimumPlausibleRate = 0.1
    private static let maximumPlausibleRate = 100.0
    private static let smoothingWeight = 0.3

    package static func updated(
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

    package static func seconds(fromNativeTimeLeft value: String) -> Double? {
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

package enum BatteryEstimateFormatting {
    package static func full(
        level: Int,
        charging: Bool,
        charged: Bool,
        secondsRemaining: Double?,
        lastUpdate: TimeInterval,
        historyEstimate: BatteryTimeEstimate? = nil,
        now: Date = Date()
    ) -> String? {
        if charged || (charging && level >= 100) {
            return "Full while charging"
        }

        if let estimate = historyEstimate {
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

    package static func compact(
        level: Int,
        charging: Bool,
        charged: Bool,
        secondsRemaining: Double?,
        lastUpdate: TimeInterval,
        historyEstimate: BatteryTimeEstimate? = nil,
        now: Date = Date()
    ) -> String? {
        if charged || (charging && level >= 100) {
            return "Full"
        }

        if let estimate = historyEstimate {
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

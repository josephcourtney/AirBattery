import Foundation

package enum EarbudMergePolicy {
    package static func mergedLevel(
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

    package static func mergedCharging(
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

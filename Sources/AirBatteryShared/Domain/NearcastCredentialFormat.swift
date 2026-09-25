import Foundation

package enum NearcastCredentialFormat {
    package static let groupPrefix = "ncg-"
    package static let sharingKeyPrefix = "nck2-"
    package static let setupPrefix = "airbattery-nearcast"

    package static func isValid(groupID: String, sharingKey: String) -> Bool {
        guard groupID.hasPrefix(groupPrefix),
              groupID.count == groupPrefix.count + 16,
              sharingKey.hasPrefix(sharingKeyPrefix)
        else {
            return false
        }
        let encoded = String(sharingKey.dropFirst(sharingKeyPrefix.count))
        return Data(base64Encoded: encoded)?.count == 32
    }

    package static func setupCode(groupID: String, sharingKey: String) -> String? {
        guard isValid(groupID: groupID, sharingKey: sharingKey) else { return nil }
        return "\(setupPrefix):\(groupID):\(sharingKey)"
    }

    package static func parseSetupCode(_ code: String) -> (groupID: String, sharingKey: String)? {
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

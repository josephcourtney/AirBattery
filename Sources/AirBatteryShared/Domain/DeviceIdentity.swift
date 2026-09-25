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

enum DeviceStorageKey {
    static func make(canonicalID: String, deviceType: String) -> String {
        canonicalID + "|" + deviceType
    }
}

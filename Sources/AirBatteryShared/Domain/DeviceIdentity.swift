import Foundation

package enum DeviceObservationSource: String, Codable, Equatable {
    case ble
    case libimobiledevice
}

package struct DeviceIdentifierSet: Equatable {
    package var canonicalID: String
    package var mobileDeviceID: String?
    package var bleDeviceID: String?

    package init(
        canonicalID: String,
        mobileDeviceID: String?,
        bleDeviceID: String?
    ) {
        self.canonicalID = canonicalID
        self.mobileDeviceID = mobileDeviceID
        self.bleDeviceID = bleDeviceID
    }

    package mutating func merge(
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

    package func matches(_ identifier: String) -> Bool {
        canonicalID == identifier ||
            mobileDeviceID == identifier ||
            bleDeviceID == identifier
    }
}

package enum DeviceStorageKey {
    package static func make(canonicalID: String, deviceType: String) -> String {
        canonicalID + "|" + deviceType
    }
}

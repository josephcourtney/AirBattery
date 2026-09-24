import Foundation

struct Device: Hashable, Codable {
    var hasBattery: Bool = true
    var deviceID: String
    var deviceType: String
    var deviceName: String
    var deviceModel: String?
    var batteryLevel: Int
    var isCharging: Int
    var isCharged: Bool = false
    var isPaused: Bool = false
    var acPowered: Bool = false
    var lowPower: Bool = false
    var parentName: String = ""
    var lastUpdate: Double
    var realUpdate: Double = 0.0
    var mobileDeviceID: String?
    var bleDeviceID: String?
    var batterySource: DeviceObservationSource?
    var estimatedRatePerHour: Double?
    var estimatedSecondsRemaining: Double?

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hasBattery)
        hasher.combine(deviceID)
        hasher.combine(deviceType)
        hasher.combine(deviceName)
        hasher.combine(deviceModel)
        hasher.combine(batteryLevel)
        hasher.combine(isCharging)
        hasher.combine(isCharged)
        hasher.combine(isPaused)
        hasher.combine(acPowered)
        hasher.combine(lowPower)
        hasher.combine(lastUpdate)
        hasher.combine(realUpdate)
        hasher.combine(parentName)
        hasher.combine(mobileDeviceID)
        hasher.combine(bleDeviceID)
        hasher.combine(batterySource)
        hasher.combine(estimatedRatePerHour)
        hasher.combine(estimatedSecondsRemaining)
    }

    mutating func mergeIdentifiers(fromExisting existing: Device) {
        var identifiers = DeviceIdentifierSet(
            canonicalID: existing.deviceID,
            mobileDeviceID: existing.mobileDeviceID,
            bleDeviceID: existing.bleDeviceID
        )
        identifiers.merge(
            canonicalID: deviceID,
            mobileDeviceID: mobileDeviceID,
            bleDeviceID: bleDeviceID
        )
        deviceID = identifiers.canonicalID
        mobileDeviceID = identifiers.mobileDeviceID
        bleDeviceID = identifiers.bleDeviceID
    }

    func matchesIdentifier(_ identifier: String) -> Bool {
        DeviceIdentifierSet(
            canonicalID: deviceID,
            mobileDeviceID: mobileDeviceID,
            bleDeviceID: bleDeviceID
        ).matches(identifier)
    }
}

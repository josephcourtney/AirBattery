import Foundation

package struct Device: Hashable, Codable {
    package var hasBattery: Bool = true
    package var deviceID: String
    package var deviceType: String
    package var deviceName: String
    package var deviceModel: String?
    package var batteryLevel: Int
    package var isCharging: Int
    package var isCharged: Bool = false
    package var isPaused: Bool = false
    package var acPowered: Bool = false
    package var lowPower: Bool = false
    package var parentName: String = ""
    package var lastUpdate: Double
    package var realUpdate: Double = 0.0
    package var mobileDeviceID: String?
    package var bleDeviceID: String?
    package var batterySource: DeviceObservationSource?
    package var estimatedRatePerHour: Double?
    package var estimatedSecondsRemaining: Double?

    package init(
        hasBattery: Bool = true,
        deviceID: String,
        deviceType: String,
        deviceName: String,
        deviceModel: String? = nil,
        batteryLevel: Int,
        isCharging: Int,
        isCharged: Bool = false,
        isPaused: Bool = false,
        acPowered: Bool = false,
        lowPower: Bool = false,
        parentName: String = "",
        lastUpdate: Double,
        realUpdate: Double = 0.0,
        mobileDeviceID: String? = nil,
        bleDeviceID: String? = nil,
        batterySource: DeviceObservationSource? = nil,
        estimatedRatePerHour: Double? = nil,
        estimatedSecondsRemaining: Double? = nil
    ) {
        self.hasBattery = hasBattery
        self.deviceID = deviceID
        self.deviceType = deviceType
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.isPaused = isPaused
        self.acPowered = acPowered
        self.lowPower = lowPower
        self.parentName = parentName
        self.lastUpdate = lastUpdate
        self.realUpdate = realUpdate
        self.mobileDeviceID = mobileDeviceID
        self.bleDeviceID = bleDeviceID
        self.batterySource = batterySource
        self.estimatedRatePerHour = estimatedRatePerHour
        self.estimatedSecondsRemaining = estimatedSecondsRemaining
    }

    package func hash(into hasher: inout Hasher) {
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

    package mutating func mergeIdentifiers(fromExisting existing: Device) {
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

    package func matchesIdentifier(_ identifier: String) -> Bool {
        DeviceIdentifierSet(
            canonicalID: deviceID,
            mobileDeviceID: mobileDeviceID,
            bleDeviceID: bleDeviceID
        ).matches(identifier)
    }
}

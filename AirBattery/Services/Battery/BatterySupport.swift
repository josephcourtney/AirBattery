import Foundation

func getPowerState() -> iBattery {
    if !AppPreferences.machineType.lowercased().contains("book") { return iBattery(hasBattery: false, isCharging: false, isCharged: false, acPowered: false, timeLeft: "", batteryLevel: 0) }
    let internalFinder = InternalFinder()
    if let internalBattery = internalFinder.getInternalBattery() {
        if let level = internalBattery.charge {
            var ib = iBattery(hasBattery: true, isCharging: internalBattery.isCharging ?? false, isCharged :internalBattery.isCharged ?? false, acPowered: internalBattery.acPowered ?? false, timeLeft: internalBattery.timeLeft, batteryLevel: Int(level))
            ib.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            return ib
        }
    }
    return iBattery(hasBattery: false, isCharging: false, isCharged: false, acPowered: false, timeLeft: "", batteryLevel: 0)
}

func getPowerColor(_ device: Device) -> String {
    if device.lowPower { return "my_yellow" }

    var colorName = "my_green"
    if device.batteryLevel <= 10 {
        colorName = "my_red"
    } else if device.batteryLevel <= 20 {
        colorName = "my_yellow"
    }
    return colorName
}

func ib2ab(_ ib: iBattery) -> Device {
    Device(
        hasBattery: ib.hasBattery,
        deviceID: "@MacInternalBattery",
        deviceType: AppPreferences.machineType,
        deviceName: AppPreferences.deviceName,
        deviceModel: macID,
        batteryLevel: ib.batteryLevel,
        isCharging: ib.isCharging ? 1 : 0,
        isCharged: ib.isCharged,
        acPowered: ib.acPowered,
        lowPower: ib.lowPower,
        lastUpdate: Date().timeIntervalSince1970
    )
}

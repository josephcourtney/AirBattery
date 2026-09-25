func getPowerColor(_ device: Device) -> String {
    if device.lowPower { return "my_yellow" }
    if device.batteryLevel <= 10 { return "my_red" }
    if device.batteryLevel <= 20 { return "my_yellow" }
    return "my_green"
}

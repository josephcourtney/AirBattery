func getDeviceIcon(_ device: Device) -> String {
    SharedDeviceIconCatalog.icon(for: device)
}

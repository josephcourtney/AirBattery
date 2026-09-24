import Foundation

enum DeviceInventorySource: String, Hashable {
    case builtIn = "Built-in"
    case network = "Network"
    case usb = "USB"
    case bluetooth = "Bluetooth"
    case nearcast = "Nearcast"

    var sortOrder: Int {
        switch self {
        case .builtIn: return 0
        case .network: return 1
        case .usb: return 2
        case .bluetooth: return 3
        case .nearcast: return 4
        }
    }
}

struct KnownDeviceSnapshot: Identifiable {
    let id: String
    var name: String
    var devices: [Device] = []
    var sources: Set<DeviceInventorySource> = []
    var ble: BLELogicalDeviceSnapshot?
    var iDeviceCandidates: [IDeviceDiscoveryCandidate] = []
    var isBuiltIn = false
}

enum DeviceInventoryBuilder {
    static func build(
        localDevices: [Device],
        internalBattery: Device?,
        nearcastDevices: [Device],
        bleDevices: [BLELogicalDeviceSnapshot],
        bleCandidates: [BLEDiscoveryCandidate],
        iDeviceCandidates: [IDeviceDiscoveryCandidate]
    ) -> [KnownDeviceSnapshot] {
        var inventory: [String: KnownDeviceSnapshot] = [:]

        func key(for name: String) -> String {
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        func merge(
            name: String,
            device: Device? = nil,
            source: DeviceInventorySource? = nil,
            keyOverride: String? = nil,
            builtIn: Bool = false
        ) {
            let inventoryKey = keyOverride ?? key(for: name)
            var snapshot = inventory[inventoryKey] ?? KnownDeviceSnapshot(
                id: inventoryKey,
                name: name
            )

            if let device,
               !snapshot.devices.contains(where: {
                   $0.deviceID == device.deviceID &&
                       $0.deviceType == device.deviceType &&
                       $0.deviceName == device.deviceName
               }) {
                snapshot.devices.append(device)
            }
            if let source {
                snapshot.sources.insert(source)
            }
            snapshot.isBuiltIn = snapshot.isBuiltIn || builtIn
            inventory[inventoryKey] = snapshot
        }

        if let internalBattery {
            merge(
                name: internalBattery.deviceName,
                device: internalBattery,
                source: .builtIn,
                keyOverride: "builtin:" + key(for: internalBattery.deviceName),
                builtIn: true
            )
        }

        for device in localDevices {
            let logicalName = AirPodsPresentation.baseName(for: device) ?? device.deviceName
            merge(name: logicalName, device: device)
        }

        for logical in bleDevices {
            let inventoryKey = key(for: logical.name)
            var snapshot = inventory[inventoryKey] ?? KnownDeviceSnapshot(
                id: inventoryKey,
                name: logical.name
            )
            snapshot.sources.insert(.bluetooth)
            snapshot.ble = logical
            inventory[inventoryKey] = snapshot
        }

        for device in nearcastDevices {
            let logicalName = AirPodsPresentation.baseName(for: device) ?? device.deviceName
            merge(name: logicalName, device: device, source: .nearcast)
        }

        for inventoryKey in Array(inventory.keys) {
            guard var snapshot = inventory[inventoryKey] else { continue }

            let matchingIDevices = iDeviceCandidates.filter { candidate in
                snapshot.devices.contains {
                    $0.matchesIdentifier(candidate.identifier)
                } ||
                    candidate.name.map {
                        key(for: $0) == key(for: snapshot.name)
                    } == true ||
                    snapshot.devices.contains { device in
                        !device.parentName.isEmpty &&
                            candidate.name.map {
                                key(for: $0) == key(for: device.parentName)
                            } == true
                    }
            }
            snapshot.iDeviceCandidates = matchingIDevices
            for candidate in matchingIDevices {
                if candidate.sources.contains(.network) {
                    snapshot.sources.insert(.network)
                }
                if candidate.sources.contains(.usb) {
                    snapshot.sources.insert(.usb)
                }
            }

            let matchingBLE = bleCandidates.filter {
                key(for: $0.name) == key(for: snapshot.name)
            }
            if !matchingBLE.isEmpty {
                snapshot.sources.insert(.bluetooth)
                if snapshot.ble == nil {
                    snapshot.ble = BLELogicalDeviceSnapshot(
                        key: key(for: snapshot.name),
                        name: snapshot.name,
                        policy: nil,
                        identities: matchingBLE,
                        exactRules: []
                    )
                }
            }

            if snapshot.sources.isEmpty {
                if snapshot.devices.contains(where: { $0.batterySource == .ble }) {
                    snapshot.sources.insert(.bluetooth)
                } else if snapshot.devices.contains(where: {
                    $0.batterySource == .libimobiledevice
                }) {
                    snapshot.sources.insert(.network)
                } else if !snapshot.devices.isEmpty {
                    snapshot.sources.insert(.bluetooth)
                }
            }

            inventory[inventoryKey] = snapshot
        }

        return inventory.values.sorted {
            if $0.isBuiltIn != $1.isBuiltIn {
                return $0.isBuiltIn
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}

import Combine
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

final class DeviceInventoryModel: ObservableObject {
    @Published private(set) var devices: [KnownDeviceSnapshot] = []

    func refresh(
        policyStore: BLEDiscoveryPolicyStore,
        iDeviceBattery: IDeviceBattery
    ) {
        var inventory: [String: KnownDeviceSnapshot] = [:]

        func merge(
            name: String,
            device: Device? = nil,
            source: DeviceInventorySource? = nil,
            keyOverride: String? = nil,
            builtIn: Bool = false
        ) {
            let key = keyOverride ?? inventoryKey(name)
            var snapshot =
                inventory[key] ?? KnownDeviceSnapshot(id: key, name: name)

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
            inventory[key] = snapshot
        }

        let internalStatus = InternalBattery.status
        if internalStatus.hasBattery {
            let mac = ib2ab(internalStatus)
            merge(
                name: mac.deviceName,
                device: mac,
                source: .builtIn,
                keyOverride: "builtin:" + inventoryKey(mac.deviceName),
                builtIn: true
            )
        }

        for device in AirBatteryModel.deviceSnapshot() {
            let logicalName =
                AirBatteryModel.airPodsBaseName(for: device) ??
                device.deviceName
            merge(name: logicalName, device: device)
        }

        for logical in policyStore.knownLogicalDevices {
            let key = inventoryKey(logical.name)
            var snapshot =
                inventory[key] ??
                KnownDeviceSnapshot(id: key, name: logical.name)
            snapshot.sources.insert(.bluetooth)
            snapshot.ble = logical
            inventory[key] = snapshot
        }

        for url in getFiles(withExtension: "json", in: ncFolder) {
            for device in AirBatteryModel.ncGetAll(url: url) {
                let logicalName =
                    AirBatteryModel.airPodsBaseName(for: device) ??
                    device.deviceName
                merge(
                    name: logicalName,
                    device: device,
                    source: .nearcast
                )
            }
        }

        for key in Array(inventory.keys) {
            guard var snapshot = inventory[key] else { continue }

            let idCandidates = iDeviceBattery.discoveryCandidates.filter {
                candidate in
                snapshot.devices.contains {
                    $0.matchesIdentifier(candidate.identifier)
                } ||
                    candidate.name.map {
                        inventoryKey($0) == inventoryKey(snapshot.name)
                    } == true ||
                    snapshot.devices.contains { device in
                        !device.parentName.isEmpty &&
                            candidate.name.map {
                                inventoryKey($0) ==
                                    inventoryKey(device.parentName)
                            } == true
                    }
            }
            snapshot.iDeviceCandidates = idCandidates
            for candidate in idCandidates {
                if candidate.sources.contains(.network) {
                    snapshot.sources.insert(.network)
                }
                if candidate.sources.contains(.usb) {
                    snapshot.sources.insert(.usb)
                }
            }

            let bleIdentities = policyStore.candidates.filter {
                inventoryKey($0.name) == inventoryKey(snapshot.name)
            }
            if !bleIdentities.isEmpty {
                snapshot.sources.insert(.bluetooth)
                if snapshot.ble == nil {
                    let exactRules = policyStore.rules.filter {
                        inventoryKey($0.name) == inventoryKey(snapshot.name)
                    }
                    snapshot.ble = BLELogicalDeviceSnapshot(
                        key: inventoryKey(snapshot.name),
                        name: snapshot.name,
                        policy: policyStore.logicalPolicy(
                            name: snapshot.name
                        ),
                        identities: bleIdentities,
                        exactRules: exactRules
                    )
                }
            }

            if snapshot.sources.isEmpty {
                if snapshot.devices.contains(where: {
                    $0.batterySource == .ble
                }) {
                    snapshot.sources.insert(.bluetooth)
                } else if snapshot.devices.contains(where: {
                    $0.batterySource == .libimobiledevice
                }) {
                    snapshot.sources.insert(.network)
                } else if !snapshot.devices.isEmpty {
                    snapshot.sources.insert(.bluetooth)
                }
            }

            inventory[key] = snapshot
        }

        devices = inventory.values.sorted {
            if $0.isBuiltIn != $1.isBuiltIn {
                return $0.isBuiltIn
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) ==
                .orderedAscending
        }
    }

    private func inventoryKey(_ name: String) -> String {
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
    }
}

import Foundation

@MainActor
final class DeviceInventoryService {
    private let deviceStore: DeviceStore
    private let policyStore: BLEDiscoveryPolicyStore
    private let iDeviceBattery: IDeviceBattery

    init(
        deviceStore: DeviceStore,
        policyStore: BLEDiscoveryPolicyStore,
        iDeviceBattery: IDeviceBattery
    ) {
        self.deviceStore = deviceStore
        self.policyStore = policyStore
        self.iDeviceBattery = iDeviceBattery
    }

    func currentInventory() -> [KnownDeviceSnapshot] {
        let internalStatus = InternalBattery.status
        let internalBattery = internalStatus.hasBattery ? ib2ab(internalStatus) : nil

        let nearcastDevices = getFiles(
            withExtension: "json",
            in: BatterySnapshotStore.nearcastDirectory
        ).flatMap {
            BatterySnapshotStore.nearcastDevices(
                at: $0,
                deviceStore: deviceStore
            )
        }

        return DeviceInventoryBuilder.build(
            localDevices: deviceStore.snapshot(),
            internalBattery: internalBattery,
            nearcastDevices: nearcastDevices,
            bleDevices: policyStore.knownLogicalDevices,
            bleCandidates: policyStore.candidates,
            iDeviceCandidates: iDeviceBattery.discoveryCandidates
        )
    }
}

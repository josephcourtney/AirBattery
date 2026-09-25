import Sparkle

/// Owns the process-wide service graph for the production application.
///
/// Dependency selection belongs here rather than in AppKit lifecycle code. A
/// few legacy battery backends still expose only shared instances internally;
/// keeping those choices at this boundary makes them straightforward to remove
/// subsystem-by-subsystem without spreading singleton lookups through the app.
@MainActor
final class AppEnvironment {
    static let shared = makeLive()

    let updaterController: SPUStandardUpdaterController
    let deviceStore: DeviceStore
    let ble: BLEBattery
    let hid: BluetoothHIDMonitor
    let iDevices: IDeviceBattery
    let blePolicy: BLEDiscoveryPolicyStore
    let magicBattery: MagicBattery
    let nearcast: MultipeerService
    let history: BatteryHistoryStore
    let systemUUID: String?

    lazy var inventory = DeviceInventoryService(
        deviceStore: deviceStore,
        policyStore: blePolicy,
        iDeviceBattery: iDevices
    )
    lazy var alerts = BatteryAlertService(
        deviceStore: deviceStore,
        nearcast: nearcast
    )
    lazy var monitoring = MonitoringCoordinator(environment: self)

    init(
        updaterController: SPUStandardUpdaterController,
        deviceStore: DeviceStore,
        ble: BLEBattery,
        hid: BluetoothHIDMonitor,
        iDevices: IDeviceBattery,
        blePolicy: BLEDiscoveryPolicyStore,
        magicBattery: MagicBattery,
        nearcast: MultipeerService,
        history: BatteryHistoryStore,
        systemUUID: String?
    ) {
        self.updaterController = updaterController
        self.deviceStore = deviceStore
        self.ble = ble
        self.hid = hid
        self.iDevices = iDevices
        self.blePolicy = blePolicy
        self.magicBattery = magicBattery
        self.nearcast = nearcast
        self.history = history
        self.systemUUID = systemUUID
    }

    private static func makeLive() -> AppEnvironment {
        let deviceStore = DeviceStore.shared
        let blePolicy = BLEDiscoveryPolicyStore.shared

        return AppEnvironment(
            updaterController: SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            ),
            deviceStore: deviceStore,
            ble: BLEBattery(),
            hid: BluetoothHIDMonitor(deviceStore: deviceStore),
            iDevices: .shared,
            blePolicy: blePolicy,
            magicBattery: .shared,
            nearcast: MultipeerService(
                serviceType: "airbattery-nc",
                deviceStore: deviceStore
            ),
            history: BatteryHistoryStore(deviceStore: deviceStore),
            systemUUID: getMacDeviceUUID()
        )
    }
}

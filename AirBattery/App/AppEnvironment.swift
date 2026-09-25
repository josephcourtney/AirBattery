import Sparkle

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

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

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        deviceStore = .shared
        ble = BLEBattery()
        hid = .shared
        iDevices = .shared
        blePolicy = .shared
        magicBattery = .shared
        nearcast = MultipeerService(
            serviceType: "airbattery-nc",
            deviceStore: deviceStore
        )
        history = BatteryHistoryStore(deviceStore: deviceStore)
        systemUUID = getMacDeviceUUID()
    }
}

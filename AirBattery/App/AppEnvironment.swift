import Sparkle

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let updaterController: SPUStandardUpdaterController
    let deviceStore: DeviceStore
    let ble: BLEBattery
    let btd: BTDBattery
    let iDevices: IDeviceBattery
    let blePolicy: BLEDiscoveryPolicyStore
    let magicBattery: MagicBattery
    let logReader: LogReader
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
        btd = BTDBattery()
        iDevices = .shared
        blePolicy = .shared
        magicBattery = .shared
        logReader = .shared
        nearcast = MultipeerService(
            serviceType: "airbattery-nc",
            deviceStore: deviceStore
        )
        history = BatteryHistoryStore(deviceStore: deviceStore)
        systemUUID = getMacDeviceUUID()
    }
}

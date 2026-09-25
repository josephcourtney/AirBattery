import AppKit
import IOBluetooth
import SwiftUI
import UserNotifications
import WidgetKit

/// Owns process-level startup, shutdown, and external event routing. `AppDelegate`
/// remains only the adapter between these operations and AppKit delegate methods.
@MainActor
final class ApplicationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private let environment: AppEnvironment
    private let workspaceCenter = NSWorkspace.shared.notificationCenter
    private let dockMenu = NSMenu()
    private var keepAliveActivity: NSObjectProtocol?
    private var startTime = Date()

    init(environment: AppEnvironment) {
        self.environment = environment
        super.init()
    }

    func handleReopen() -> Bool {
        if ["sbar", "none"].contains(AppPreferences.showOn) {
            SettingsWindowController.shared.present()
            return false
        }
        DockPopoverController.shared.toggle()
        return true
    }

    func applicationWillFinishLaunching() {
        registerNotificationCategory()
        installMainMenuIfNeeded()
        configurePreferences()
        prepareNearcastDirectory()
        registerExternalEvents()
        startNearcastIfConfigured()
        refreshBluetoothSystemProfile()
        configureNotifications()
        startMonitoring()
        scheduleInitialRefreshes()
    }

    func applicationDidFinishLaunching() {
        StatusBarController.shared.install()
        SurfaceController.shared.apply(AppPreferences.showOn, settingsVisible: false)
        NSApp.dockTile.contentView = NSHostingView(rootView: MultiBatteryView())
        NSApp.dockTile.display()

        keepAliveActivity = ProcessInfo.processInfo.beginActivity(
            options: [.automaticTerminationDisabled, .suddenTerminationDisabled],
            reason: "AirBattery menu bar monitoring"
        )
        showLaunchTipsIfNeeded()
    }

    func applicationWillTerminate() {
        environment.monitoring.stop()
        workspaceCenter.removeObserver(self)
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        if let keepAliveActivity {
            ProcessInfo.processInfo.endActivity(keepAliveActivity)
            self.keepAliveActivity = nil
        }
        _ = process(path: "/usr/bin/killall", arguments: ["idevicesyslog"])
    }

    func applicationDockMenu() -> NSMenu {
        DockPopoverController.shared.hide()
        return dockMenu
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "DELAY_30_MIN" {
            let name = response.notification.request.content.userInfo["customInfo"] as? String ?? ""
            Task { @MainActor [weak self] in
                self?.environment.alerts.snooze(deviceName: name)
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    @objc nonisolated private func onDisplayWake() {
        Task { @MainActor [weak self] in self?.handleDisplayWake() }
    }

    private func handleDisplayWake() {
        guard AppPreferences.readBTHID else { return }
        let hid = environment.hid
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { hid.run(.wake) }
    }

    @objc nonisolated private func deviceIsConnected(
        notification: IOBluetoothUserNotification,
        fromDevice device: IOBluetoothDevice
    ) {
        guard let name = device.name, let address = device.addressString else { return }
        let isAppleDevice = device.isAppleDevice
        Task { @MainActor [weak self] in
            self?.handleDeviceConnected(name: name, address: address, isAppleDevice: isAppleDevice)
        }
    }

    private func handleDeviceConnected(name: String, address: String, isAppleDevice: Bool) {
        guard AppPreferences.readBTHID,
              Date().timeIntervalSince(startTime) >= 10,
              !environment.deviceStore.isNameBlocked(name: name)
        else { return }

        print("ℹ️ \(name) (\(address)) connected")
        let hid = environment.hid
        let magicBattery = environment.magicBattery
        let deviceStore = environment.deviceStore
        DispatchQueue.global(qos: .utility).async {
            usleep(2_500_000)
            if !isAppleDevice {
                SPBluetoothDataModel.shared.refeshData { _ in
                    hid.run(.connect)
                    magicBattery.getIOBTBattery()
                    magicBattery.getOtherBTBattery()
                }
                return
            }
            if let known = deviceStore.getByName(name),
               !["Trackpad", "Keyboard", "MMouse", "Mouse"].contains(known.deviceType) {
                return
            }
            SPBluetoothDataModel.shared.refeshData { _ in magicBattery.scanDevices() }
        }
    }

    @objc nonisolated private func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        replyEvent: NSAppleEventDescriptor
    ) {
        guard let value = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else { return }
        Task { @MainActor [weak self] in self?.handleURL(value) }
    }

    private func handleURL(_ value: String) {
        guard let url = URL(string: value), url.scheme == "airbattery" else { return }
        switch url.host {
        case "writedata":
            print("Writing data to disk...")
            BatterySnapshotStore.writeCurrentSnapshot(deviceStore: environment.deviceStore)
        case "reloadwingets":
            print("Reloading all widgets...")
            BatterySnapshotStore.writeCurrentSnapshot(deviceStore: environment.deviceStore)
            WidgetCenter.shared.reloadAllTimelines()
        case "settings":
            SettingsWindowController.shared.present()
        default:
            print("Unknown command")
        }
    }

    @objc private func openAbout() { openAboutPanel() }
    @objc private func openSetting() { SettingsWindowController.shared.present() }

    private func configurePreferences() {
        AppPreferences.registerDefaults()
        AppPreferences.machineType = getMacDeviceType()
        AppPreferences.deviceName = getMacDeviceName()
        AppPreferences.launchAtLogin = isLoginItemEnabled()
        InternalBattery.status = getPowerState()
        print("⚙️ Launch AirBattery at login = \(AppPreferences.launchAtLogin)")
        print("⚙️ Icon mode = \(AppPreferences.showOn)")
    }

    private func prepareNearcastDirectory() {
        let directory = BatterySnapshotStore.nearcastDirectory
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                print("ℹ️ Folder created at: \(directory.path)")
            } catch {
                print("⚠️ Failed to create folder: \(error)")
            }
            return
        }
        for url in getFiles(withExtension: "json", in: directory) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func registerExternalEvents() {
        startTime = Date()
        workspaceCenter.addObserver(
            self,
            selector: #selector(onDisplayWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceIsConnected(notification:fromDevice:))
        )
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    private func startNearcastIfConfigured() {
        guard AppPreferences.nearCast else { return }
        if isNearcastCredentialValid(
            groupID: AppPreferences.nearcastGroupID,
            sharingKey: AppPreferences.nearcastSharingKey
        ) {
            environment.nearcast.resume()
        } else {
            AppPreferences.nearCast = false
        }
    }

    private func refreshBluetoothSystemProfile() {
        if let result = process(
            path: "/usr/sbin/system_profiler",
            arguments: ["SPBluetoothDataType", "-json"]
        ) {
            SPBluetoothDataModel.shared.data = result
        }
    }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error {
                print("⚠️ Notification authorization denied: \(error.localizedDescription)")
            }
        }
        center.delegate = self
    }

    private func startMonitoring() {
        environment.ble.startScan()
        environment.hid.startScan()
        environment.magicBattery.startScan()
        environment.iDevices.startScan()
        environment.monitoring.start()
    }

    private func scheduleInitialRefreshes() {
        let deviceStore = environment.deviceStore
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            BatterySnapshotStore.writeCurrentSnapshot(deviceStore: deviceStore)
            WidgetCenter.shared.reloadAllTimelines()
        }
        guard AppPreferences.nearCast else { return }
        let nearcast = environment.nearcast
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { nearcast.refeshAll() }
    }

    private func showLaunchTipsIfNeeded() {
        if ["dock", "both"].contains(AppPreferences.showOn) {
            showTipIfNeeded(
                id: "ab.docktile-power.note",
                message: "Displaying AirBattery on the Dock will consume more power, it is better to use Menu Bar mode or Widgets.".local
            )
        }
        if AppPreferences.readBTHID {
            showTipIfNeeded(
                id: "ab.third-party-device.note",
                message: "If some of your devices shows battery level in the Bluetooth menu, but AirBattery doesn't find it. Try disconnecting and reconnecting it, and wait a few minutes.".local
            )
        }
    }

    private func showTipIfNeeded(id: String, message: String) {
        let never = AppPreferences.neverRemind
        guard !never.contains(id) else { return }
        let alert = createAlert(
            title: "AirBattery Tips".local,
            message: message,
            button1: "Don't remind me again",
            button2: "OK"
        )
        if alert.runModal() == .alertFirstButtonReturn {
            AppPreferences.neverRemind = never + [id]
        }
    }

    private func installMainMenuIfNeeded() {
        guard NSApp.mainMenu == nil else { return }

        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "AirBattery")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        addMenuItem(appMenu, title: "About AirBattery".local, action: #selector(openAbout))
        appMenu.addItem(.separator())
        let settings = addMenuItem(appMenu, title: "Settings...".local, action: #selector(openSetting), key: ",")
        settings.keyEquivalentModifierMask = [.command]
        appMenu.addItem(.separator())

        let servicesMenu = NSMenu(title: "Services")
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        services.submenu = servicesMenu
        appMenu.addItem(services)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())

        addSystemMenuItem(appMenu, title: "Hide AirBattery", action: #selector(NSApplication.hide(_:)), key: "h", modifiers: [.command])
        addSystemMenuItem(appMenu, title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option])
        addSystemMenuItem(appMenu, title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)))
        appMenu.addItem(.separator())
        addSystemMenuItem(appMenu, title: "Quit AirBattery".local, action: #selector(NSApplication.terminate(_:)), key: "q", modifiers: [.command])

        NSApp.mainMenu = mainMenu

        addMenuItem(dockMenu, title: "Settings...".local, action: #selector(openSetting))
        addMenuItem(dockMenu, title: "About AirBattery".local, action: #selector(openAbout))
    }

    @discardableResult
    private func addMenuItem(
        _ menu: NSMenu,
        title: String,
        action: Selector,
        key: String = ""
    ) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @discardableResult
    private func addSystemMenuItem(
        _ menu: NSMenu,
        title: String,
        action: Selector,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = NSApp
        menu.addItem(item)
        return item
    }
}

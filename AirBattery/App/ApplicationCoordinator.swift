import AppKit
import IOBluetooth
import SwiftUI
import UserNotifications
import WidgetKit

/// Owns application-level startup, shutdown, and external event routing.
///
/// AppKit delegate methods stay in `AppDelegate`; process orchestration lives
/// here so the delegate remains a thin framework adapter.
@MainActor
final class ApplicationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private let environment: AppEnvironment
    private let workspaceNotifications = NSWorkspace.shared.notificationCenter
    private let dockMenu = NSMenu()

    private var keepAliveActivity: NSObjectProtocol?
    private var startTime = Date()

    init(environment: AppEnvironment) {
        self.environment = environment
        super.init()
    }

    func handleReopen() -> Bool {
        if AppPreferences.showOn == "sbar" || AppPreferences.showOn == "none" {
            presentSettings()
            return false
        }

        DockPopoverController.shared.toggle()
        return true
    }

    func applicationWillFinishLaunching() {
        registerNotificationCategory()
        installMainMenuIfNeeded()

        AppPreferences.registerDefaults()
        AppPreferences.machineType = getMacDeviceType()
        AppPreferences.deviceName = getMacDeviceName()
        InternalBattery.status = getPowerState()

        let settingsItem = dockMenu.addItem(
            withTitle: "Settings...".local,
            action: #selector(openSetting),
            keyEquivalent: ""
        )
        settingsItem.target = self
        let aboutItem = dockMenu.addItem(
            withTitle: "About AirBattery".local,
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self

        prepareNearcastDirectory()

        startTime = Date()
        workspaceNotifications.addObserver(
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

        AppPreferences.launchAtLogin = isLoginItemEnabled()
        print("⚙️ Launch AirBattery at login = \(AppPreferences.launchAtLogin)")
        print("⚙️ Icon mode = \(AppPreferences.showOn)")

        startNearcastIfConfigured()
        refreshBluetoothSystemProfile()
        configureNotifications()
        startMonitoring()
        scheduleInitialSnapshot()
        scheduleInitialNearcastRefresh()
    }

    func applicationDidFinishLaunching() {
        StatusBarController.shared.install()
        SurfaceController.shared.apply(
            AppPreferences.showOn,
            settingsVisible: false
        )
        NSApp.dockTile.contentView = NSHostingView(rootView: MultiBatteryView())
        NSApp.dockTile.display()

        let options: ProcessInfo.ActivityOptions = [
            .automaticTerminationDisabled,
            .suddenTerminationDisabled,
        ]
        keepAliveActivity = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "AirBattery menu bar monitoring"
        )

        showLaunchTipsIfNeeded()
    }

    func applicationWillTerminate() {
        environment.monitoring.stop()
        workspaceNotifications.removeObserver(self)
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
            let deviceName =
                response.notification.request.content.userInfo["customInfo"]
                    as? String ?? ""
            Task { @MainActor [weak self] in
                self?.environment.alerts.snooze(deviceName: deviceName)
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (
            UNNotificationPresentationOptions
        ) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    @objc nonisolated private func onDisplayWake() {
        Task { @MainActor [weak self] in
            self?.handleDisplayWake()
        }
    }

    private func handleDisplayWake() {
        guard AppPreferences.readBTHID else { return }
        let hid = environment.hid
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            hid.run(.wake)
        }
    }

    @objc nonisolated private func deviceIsConnected(
        notification: IOBluetoothUserNotification,
        fromDevice device: IOBluetoothDevice
    ) {
        guard let name = device.name,
              let address = device.addressString
        else {
            return
        }

        let isAppleDevice = device.isAppleDevice
        Task { @MainActor [weak self] in
            self?.handleDeviceConnected(
                name: name,
                address: address,
                isAppleDevice: isAppleDevice
            )
        }
    }

    private func handleDeviceConnected(
        name: String,
        address: String,
        isAppleDevice: Bool
    ) {
        guard AppPreferences.readBTHID,
              Date().timeIntervalSince(startTime) >= 10,
              !environment.deviceStore.isNameBlocked(name: name)
        else {
            return
        }

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
               !["Trackpad", "Keyboard", "MMouse", "Mouse"]
                   .contains(known.deviceType) {
                return
            }

            SPBluetoothDataModel.shared.refeshData { _ in
                magicBattery.scanDevices()
            }
        }
    }

    @objc nonisolated private func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlString = event
            .paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?
            .stringValue
        else {
            return
        }

        Task { @MainActor [weak self] in
            self?.handleURL(urlString)
        }
    }

    private func handleURL(_ urlString: String) {
        guard let url = URL(string: urlString),
              url.scheme == "airbattery"
        else {
            return
        }

        switch url.host {
        case "writedata":
            print("Writing data to disk...")
            BatterySnapshotStore.writeCurrentSnapshot(
                deviceStore: environment.deviceStore
            )
        case "reloadwingets":
            print("Reloading all widgets...")
            BatterySnapshotStore.writeCurrentSnapshot(
                deviceStore: environment.deviceStore
            )
            WidgetCenter.shared.reloadAllTimelines()
        case "settings":
            presentSettings()
        default:
            print("Unknown command")
        }
    }

    @objc private func openAbout() {
        openAboutPanel()
    }

    @objc private func openSetting() {
        presentSettings()
    }

    private func presentSettings() {
        SettingsWindowController.shared.present()
    }

    private func prepareNearcastDirectory() {
        if !FileManager.default.fileExists(
            atPath: BatterySnapshotStore.nearcastDirectory.path
        ) {
            do {
                try FileManager.default.createDirectory(
                    at: BatterySnapshotStore.nearcastDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print(
                    "ℹ️ Folder created at: "
                        + BatterySnapshotStore.nearcastDirectory.path
                )
            } catch {
                print("⚠️ Failed to create folder: \(error)")
            }
            return
        }

        let oldFiles = getFiles(
            withExtension: "json",
            in: BatterySnapshotStore.nearcastDirectory
        )
        for url in oldFiles {
            try? FileManager.default.removeItem(at: url)
        }
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
        guard let result = process(
            path: "/usr/sbin/system_profiler",
            arguments: ["SPBluetoothDataType", "-json"]
        ) else {
            return
        }
        SPBluetoothDataModel.shared.data = result
    }

    private func configureNotifications() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, error in
            if let error {
                print(
                    "⚠️ Notification authorization denied: "
                        + error.localizedDescription
                )
            }
        }
        notificationCenter.delegate = self
    }

    private func startMonitoring() {
        environment.ble.startScan()
        environment.hid.startScan()
        environment.magicBattery.startScan()
        environment.iDevices.startScan()
        environment.monitoring.start()
    }

    private func scheduleInitialSnapshot() {
        let deviceStore = environment.deviceStore
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            BatterySnapshotStore.writeCurrentSnapshot(deviceStore: deviceStore)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func scheduleInitialNearcastRefresh() {
        guard AppPreferences.nearCast else { return }
        let nearcast = environment.nearcast
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            nearcast.refeshAll()
        }
    }

    private func showLaunchTipsIfNeeded() {
        if AppPreferences.showOn == "dock" || AppPreferences.showOn == "both" {
            showTipIfNeeded(
                id: "ab.docktile-power.note",
                message:
                    "Displaying AirBattery on the Dock will consume more power, "
                    + "it is better to use Menu Bar mode or Widgets.".local
            )
        }

        if AppPreferences.readBTHID {
            showTipIfNeeded(
                id: "ab.third-party-device.note",
                message:
                    "If some of your devices shows battery level in the Bluetooth "
                    + "menu, but AirBattery doesn't find it. Try disconnecting and "
                    + "reconnecting it, and wait a few minutes.".local
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
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "AirBattery")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let aboutItem = NSMenuItem(
            title: "About AirBattery".local,
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...".local,
            action: #selector(openSetting),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let servicesMenu = NSMenu(title: "Services")
        let servicesItem = NSMenuItem(
            title: "Services",
            action: nil,
            keyEquivalent: ""
        )
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide AirBattery",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.keyEquivalentModifierMask = [.command]
        hideItem.target = NSApp
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        hideOthersItem.target = NSApp
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAllItem.target = NSApp
        appMenu.addItem(showAllItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit AirBattery".local,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        NSApp.mainMenu = mainMenu
    }
}

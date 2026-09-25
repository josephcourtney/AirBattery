//
//  AppDelegate.swift
//  AirBattery
//
//  Created by apple on 2023/9/4.
//
import AppKit
import SwiftUI
import WidgetKit
import UserNotifications
import IOBluetooth
import Sparkle

@MainActor
public func runAirBatteryApplication() {
    AppDelegate.main()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let environment = AppEnvironment.shared
    private var keepAliveActivity: NSObjectProtocol?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
    var menu = NSMenu()
    var startTime = Date()
    let nc = NSWorkspace.shared.notificationCenter
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        if response.actionIdentifier == "DELAY_30_MIN" {
            let deviceName =
                response.notification.request.content.userInfo["customInfo"]
                    as? String ?? ""
            Task { @MainActor in
                AppEnvironment.shared.alerts.snooze(deviceName: deviceName)
            }
        }
        completionHandler()
    }
    
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if AppPreferences.showOn == "sbar" || AppPreferences.showOn == "none" {
            presentSettings()
            return false
        }

        DockPopoverController.shared.toggle()
        return true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        registerNotificationCategory()

        installMainMenuIfNeeded()

        AppPreferences.registerDefaults()
        AppPreferences.machineType = getMacDeviceType()
        AppPreferences.deviceName = getMacDeviceName()
        InternalBattery.status = getPowerState()
        
        let settingsItem = menu.addItem(
            withTitle: "Settings...".local,
            action: #selector(openSetting),
            keyEquivalent: ""
        )
        settingsItem.target = self
        let aboutItem = menu.addItem(
            withTitle: "About AirBattery".local,
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        
        if !FileManager.default.fileExists(atPath: BatterySnapshotStore.nearcastDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: BatterySnapshotStore.nearcastDirectory, withIntermediateDirectories: true, attributes: nil)
                print("ℹ️ Folder created at: \(BatterySnapshotStore.nearcastDirectory.path)")
            } catch {
                print("⚠️ Failed to create folder: \(error)")
            }
        } else {
            let oldFiles = getFiles(withExtension: "json", in: BatterySnapshotStore.nearcastDirectory)
            for url in oldFiles { try? FileManager.default.removeItem(at: url) }
        }
        
        startTime = Date()
        nc.addObserver(self, selector: #selector(onDisplayWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceIsConnected(notification:fromDevice:)))
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        AppPreferences.launchAtLogin = isLoginItemEnabled()
        print("⚙️ Launch AirBattery at login = \(AppPreferences.launchAtLogin)")
        print("⚙️ Icon mode = \(AppPreferences.showOn)")
        if AppPreferences.nearCast {
            if isNearcastCredentialValid(
                groupID: AppPreferences.nearcastGroupID,
                sharingKey: AppPreferences.nearcastSharingKey
            ) {
                environment.nearcast.resume()
            } else {
                AppPreferences.nearCast = false
            }
        }
        if let result = process(path: "/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"]) { SPBluetoothDataModel.shared.data = result }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("⚠️ Notification authorization denied: \(error.localizedDescription)") }
        }
        UNUserNotificationCenter.current().delegate = self
        
        environment.ble.startScan()
        environment.hid.startScan()
        environment.magicBattery.startScan()
        environment.iDevices.startScan()
        environment.monitoring.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            BatterySnapshotStore.writeCurrentSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        if AppPreferences.nearCast {
            let nearcast = environment.nearcast
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                nearcast.refeshAll()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        StatusBarController.shared.install()
        SurfaceController.shared.apply(
            AppPreferences.showOn,
            settingsVisible: false
        )
        NSApp.dockTile.contentView = NSHostingView(rootView: MultiBatteryView())
        NSApp.dockTile.display()

        let opts: ProcessInfo.ActivityOptions = [.automaticTerminationDisabled, .suddenTerminationDisabled]
        keepAliveActivity = ProcessInfo.processInfo.beginActivity(options: opts, reason: "AirBattery menu bar monitoring")

        if AppPreferences.showOn == "dock" || AppPreferences.showOn == "both" {
            let tipID = "ab.docktile-power.note"
            let never = AppPreferences.neverRemind
            if !never.contains(tipID) {
                let alert = createAlert(title: "AirBattery Tips".local, message: "Displaying AirBattery on the Dock will consume more power, it is better to use Menu Bar mode or Widgets.".local, button1: "Don't remind me again", button2: "OK")
                if alert.runModal() == .alertFirstButtonReturn { AppPreferences.neverRemind = never + [tipID] }
            }
        }
        
        if AppPreferences.readBTHID {
            let tipID = "ab.third-party-device.note"
            let never = AppPreferences.neverRemind
            if !never.contains(tipID) {
                let alert = createAlert(title: "AirBattery Tips".local, message: "If some of your devices shows battery level in the Bluetooth menu, but AirBattery doesn't find it. Try disconnecting and reconnecting it, and wait a few minutes.".local, button1: "Don't remind me again", button2: "OK")
                if alert.runModal() == .alertFirstButtonReturn { AppPreferences.neverRemind = never + [tipID] }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        environment.monitoring.stop()
        if let act = keepAliveActivity {
            ProcessInfo.processInfo.endActivity(act)
        }

        _ = process(path: "/usr/bin/killall", arguments: ["idevicesyslog"])
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    
    @objc nonisolated func onDisplayWake() {
        Task { @MainActor [weak self] in
            self?.handleDisplayWake()
        }
    }

    private func handleDisplayWake() {
        if AppPreferences.readBTHID {
            let hid = environment.hid
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                hid.run(.wake)
            }
        }
    }
    
    @objc nonisolated func deviceIsConnected(
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
              !DeviceStore.shared.isNameBlocked(name: name)
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
    
    @objc nonisolated func handleURLEvent(
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
            BatterySnapshotStore.writeCurrentSnapshot()
        case "reloadwingets":
            print("Reloading all widgets...")
            BatterySnapshotStore.writeCurrentSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
        case "settings":
            presentSettings()
        default:
            print("Unknow command!")
        }
    }
     
    @MainActor
    @objc func openAbout() {
        openAboutPanel()
    }

    @MainActor
    @objc func confirmQuit() {
        let response = createAlert(
            level: .warning,
            title: "Quit AirBattery?",
            message:
                "AirBattery will stop monitoring device batteries until you launch it again.",
            button1: "Quit",
            button2: "Cancel"
        ).runModal()
        if response == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
    
    @objc func openSetting() {
        presentSettings()
    }

    func presentSettings() {
        SettingsWindowController.shared.present()
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
    
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        DockPopoverController.shared.hide()
        return menu
    }
}

//
//  AirBatteryApp.swift
//  AirBattery
//
//  Created by apple on 2023/9/4.
//
import AppKit
import SwiftUI
import WidgetKit
import UserNotifications
import IOBluetooth
import ServiceManagement
import Sparkle

@MainActor
let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)
@MainActor
let netcastService = MultipeerService(serviceType: "airbattery-nc")
let ncFolder = AirBatteryModel.getNearcastURL()
let systemUUID = getMacDeviceUUID()
@MainActor
let bleBattery = BLEBattery()
let btdBattery = BTDBattery()

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let settingsScene = NSHostingSceneRepresentation {
        Settings {
            SettingsView()
        }
    }

    private var keepAliveActivity: NSObjectProtocol?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
    var showOn: String {
        get { AppPreferences.showOn }
        set { AppPreferences.showOn = newValue }
    }
    var machineType: String {
        get { AppPreferences.machineType }
        set { AppPreferences.machineType = newValue }
    }
    var deviceName: String {
        get { AppPreferences.deviceName }
        set { AppPreferences.deviceName = newValue }
    }
    var nearcastGroupID: String {
        get { AppPreferences.nearcastGroupID }
        set { AppPreferences.nearcastGroupID = newValue }
    }
    var nearcastSharingKey: String {
        get { AppPreferences.nearcastSharingKey }
        set { AppPreferences.nearcastSharingKey = newValue }
    }
    var nearCast: Bool {
        get { AppPreferences.nearCast }
        set { AppPreferences.nearCast = newValue }
    }
    var launchAtLogin: Bool {
        get { AppPreferences.launchAtLogin }
        set { AppPreferences.launchAtLogin = newValue }
    }
    var intBattOnStatusBar: Bool { AppPreferences.intBattOnStatusBar }
    var batteryPercent: String { AppPreferences.batteryPercent }
    var alertSound: Bool { AppPreferences.alertSound }
    var readBTHID: Bool { AppPreferences.readBTHID }
    var hideLevel: Int { AppPreferences.hideLevel }
    var disappearTime: Int { AppPreferences.disappearTime }
    var whitelistMode: Bool { AppPreferences.whitelistMode }
    var iosBatteryStyle: Bool { AppPreferences.iosBatteryStyle }
    var updateInterval: Int { AppPreferences.updateInterval }
    var carouselMode: Bool { AppPreferences.carouselMode }
    var alertLevel: Int { AppPreferences.alertLevel }
    var fullyLevel: Int { AppPreferences.fullyLevel }
    
    var menu = NSMenu()
    var startTime = Date()
    let nc = NSWorkspace.shared.notificationCenter
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        if response.actionIdentifier == "DELAY_30_MIN" {
            let deviceName =
                response.notification.request.content.userInfo["customInfo"]
                    as? String ?? ""
            Task { @MainActor in
                lowPowerNoteDelay[deviceName] =
                    Date().timeIntervalSince1970 + 1800
            }
        }
        completionHandler()
    }
    
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if showOn == "sbar" || showOn == "none" {
            presentSettings()
            return false
        }

        DockPopoverController.shared.toggle()
        return true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        registerNotificationCategory()

        NSApplication.shared.addSceneRepresentation(settingsScene)
        installMainMenuIfNeeded()

        // default defaults (used if not set)
        UserDefaults.standard.register(
            defaults: [
                "showOn": "sbar",
                "machineType": "mac",
                "deviceName": "Mac",
                "launchAtLogin": false,
                "intBattOnStatusBar": true,
                "updateInterval": 1,
                "widgetInterval": 0,
                "hideLevel": 90,
                "nearCast": false,
                "readBTHID": true,
                "whitelistMode": false,
                "neverRemindMe": [String]()
            ]
        )
        
        AirBatteryModel.migrateLegacySharedStorageIfNeeded()

        machineType = getMacDeviceType()
        deviceName = getMacDeviceName()
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
        
        //处理旧版偏好设置
        if let alertList = (UserDefaults.standard.object(forKey: "alertList") ?? []) as? [String] {
            let alerts: [btAlert] = alertList.map({
                btAlert(name: $0, full: fullyLevel == 100 ? 99 : fullyLevel, fullOn: true, fullSound: alertSound, low: alertLevel, lowOn: true, lowSound: alertSound)
            })
            UserDefaults.standard.set([], forKey: "alertList")
            UserDefaults.standard.set(object: alerts, forKey: "alertList")
        }
        
        if !FileManager.default.fileExists(atPath: ncFolder.path) {
            do {
                try FileManager.default.createDirectory(at: ncFolder, withIntermediateDirectories: true, attributes: nil)
                print("ℹ️ Folder created at: \(ncFolder.path)")
            } catch {
                print("⚠️ Failed to create folder: \(error)")
            }
        } else {
            let oldFiles = getFiles(withExtension: "json", in: ncFolder)
            for url in oldFiles { try? FileManager.default.removeItem(at: url) }
        }
        
        startTime = Date()
        nc.addObserver(self, selector: #selector(onDisplayWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceIsConnected(notification:fromDevice:)))
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        launchAtLogin = isLoginItemEnabled()
        print("⚙️ Launch AirBattery at login = \(launchAtLogin)")
        print("⚙️ Icon mode = \(showOn)")
        migrateLegacyNearcastCredentialsIfNeeded()
        if nearCast {
            if isNearcastCredentialValid(
                groupID: nearcastGroupID,
                sharingKey: nearcastSharingKey
            ) {
                netcastService.resume()
            } else {
                nearCast = false
            }
        }
        if let result = process(path: "/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"]) { SPBluetoothDataModel.shared.data = result }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("⚠️ Notification authorization denied: \(error.localizedDescription)") }
        }
        UNUserNotificationCenter.current().delegate = self
        
        bleBattery.startScan()
        btdBattery.startScan()
        MagicBattery.shared.startScan()
        IDeviceBattery.shared.startScan()
        MonitoringCoordinator.shared.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            AirBatteryModel.writeData()
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        if nearCast {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                netcastService.refeshAll()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        StatusBarController.shared.install()
        SurfaceController.shared.apply(
            showOn,
            settingsVisible: false
        )
        NSApp.dockTile.contentView = NSHostingView(rootView: MultiBatteryView())
        NSApp.dockTile.display()

        let opts: ProcessInfo.ActivityOptions = [.automaticTerminationDisabled, .suddenTerminationDisabled]
        keepAliveActivity = ProcessInfo.processInfo.beginActivity(options: opts, reason: "AirBattery menu bar monitoring")

        if showOn == "dock" || showOn == "both" {
            let tipID = "ab.docktile-power.note"
            let never = AppPreferences.neverRemind
            if !never.contains(tipID) {
                let alert = createAlert(title: "AirBattery Tips".local, message: "Displaying AirBattery on the Dock will consume more power, it is better to use Menu Bar mode or Widgets.".local, button1: "Don't remind me again", button2: "OK")
                if alert.runModal() == .alertFirstButtonReturn { AppPreferences.neverRemind = never + [tipID] }
            }
        }
        
        if readBTHID {
            let tipID = "ab.third-party-device.note"
            let never = AppPreferences.neverRemind
            if !never.contains(tipID) {
                let alert = createAlert(title: "AirBattery Tips".local, message: "If some of your devices shows battery level in the Bluetooth menu, but AirBattery doesn't find it. Try disconnecting and reconnecting it, and wait a few minutes.".local, button1: "Don't remind me again", button2: "OK")
                if alert.runModal() == .alertFirstButtonReturn { AppPreferences.neverRemind = never + [tipID] }
            }
            // Bootstrap Enhanced HID scan incrementally with a short initial window
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                LogReader.shared.run(.bootstrap)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MonitoringCoordinator.shared.stop()
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
        if readBTHID {
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                LogReader.shared.run(.wake)
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
        guard readBTHID,
              Date().timeIntervalSince(startTime) >= 10,
              !AirBatteryModel.checkIfBlocked(name: name)
        else {
            return
        }

        print("ℹ️ \(name) (\(address)) connected")
        DispatchQueue.global(qos: .utility).async {
            usleep(2_500_000)

            if !isAppleDevice {
                SPBluetoothDataModel.shared.refeshData { _ in
                    LogReader.shared.run(.connect)
                    MagicBattery.shared.getIOBTBattery()
                    MagicBattery.shared.getOtherBTBattery()
                }
                return
            }

            if let known = AirBatteryModel.getByName(name),
               !["Trackpad", "Keyboard", "MMouse", "Mouse"]
                   .contains(known.deviceType) {
                return
            }

            SPBluetoothDataModel.shared.refeshData { _ in
                MagicBattery.shared.scanDevices()
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
            AirBatteryModel.writeData()
        case "reloadwingets":
            print("Reloading all widgets...")
            AirBatteryModel.writeData()
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
    
    @objc func openSetting() {
        presentSettings()
    }

    func presentSettings() {
        SurfaceController.shared.syncActivation(
            surfaceSelection: AppPreferences.showOn,
            settingsVisible: true
        )
        NSApp.activate()
        settingsScene.environment.openSettings()
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

extension NSImage {
    func resized(to maxSize: NSSize) -> NSImage {
        let aspectWidth = maxSize.width / self.size.width
        let aspectHeight = maxSize.height / self.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        let newSize = NSSize(width: self.size.width * aspectRatio, height: self.size.height * aspectRatio)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        newImage.unlockFocus()
        
        return newImage
    }
}

public extension UserDefaults {
    func set<T: Codable>(object: T, forKey: String) {
        if let jsonData = try? JSONEncoder().encode(object) {
            set(jsonData, forKey: forKey)
        }
    }
    
    func get<T: Codable>(objectType: T.Type, forKey: String) -> T? {
        guard let result = value(forKey: forKey) as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(objectType, from: result)
    }
}

@discardableResult
func isLoginItemEnabled() -> Bool {
    switch SMAppService.mainApp.status {
    case .enabled, .requiresApproval:
        return true
    case .notRegistered, .notFound:
        return false
    @unknown default:
        return false
    }
}

@discardableResult
func ensureLoginItem(enabled: Bool) -> Bool {
    let service = SMAppService.mainApp
    do {
        if enabled {
            if service.status == .notRegistered || service.status == .notFound {
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
        return true
    } catch {
        NSLog("[AirBattery] SMAppService main-app registration failed: \(error.localizedDescription)")
        return false
    }
}


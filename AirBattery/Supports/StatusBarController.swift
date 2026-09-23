import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()

    private(set) var statusItem: NSStatusItem!
    private(set) var pinnedItems: [NSStatusItem] = []
    private(set) var isMenuOpen = false

    private let menu = NSMenu()

    private override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    func install() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem.button {
            let internalBattery = getPowerState()
            let width: CGFloat =
                internalBattery.hasBattery &&
                    AppPreferences.intBattOnStatusBar
                    ? 42
                    : 36
            statusItem.length = width

            let host = StatusItemHostingView(
                rootView: mainBatteryView()
            )
            host.frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: 21.5
            )
            host.autoresizingMask = [.width]

            button.image = NSImage()
            button.addSubview(host)
        }

        rebuildMenu()
        statusItem.menu = menu
    }

    func setMenuBarVisible(_ visible: Bool) {
        guard statusItem != nil else { return }
        statusItem.isVisible = visible
        for item in pinnedItems {
            item.isVisible = visible
        }
    }

    func setLength(_ width: CGFloat) {
        statusItem?.length = width
    }

    func cancelMenuTracking() {
        menu.cancelTracking()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        isMenuOpen = true
        DockPopoverController.shared.hide()
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        isMenuOpen = false
    }

    func refreshPinnedItems(unpin: String? = nil) {
        var pinnedNames = AppPreferences.pinnedNames
        guard !pinnedNames.isEmpty || !pinnedItems.isEmpty else {
            return
        }

        if let unpin {
            pinnedNames.removeAll { $0 == unpin }
        }

        var allDevices = AirBatteryModel.getAll()
        for file in getFiles(withExtension: "json", in: ncFolder) {
            allDevices += AirBatteryModel.ncGetAll(url: file)
        }

        let pinnedDevices = allDevices.filter {
            pinnedNames.contains($0.deviceName)
        }
        let deviceNames = Set(pinnedDevices.map(\.deviceName))

        for device in pinnedDevices {
            if let index = pinnedItems.firstIndex(where: {
                $0.button?.toolTip == device.deviceName
            }) {
                pinnedItems[index].button?.title =
                    "\(device.batteryLevel)" +
                    (device.isCharging != 0 ? "⚡︎" : "%")
                continue
            }

            let item = NSStatusBar.system.statusItem(
                withLength: NSStatusItem.variableLength
            )
            if let button = item.button {
                let icon = getDeviceIcon(device)
                if let source = NSImage(named: icon) {
                    let image = source.resized(
                        to: NSSize(width: 17, height: 17)
                    )
                    image.isTemplate = true
                    button.image = image
                }
                button.title =
                    "\(device.batteryLevel)" +
                    (device.isCharging != 0 ? "⚡︎" : "%")
                button.toolTip = device.deviceName
            }
            pinnedItems.append(item)
        }

        let expired = pinnedItems.filter {
            guard let name = $0.button?.toolTip else { return true }
            return !pinnedNames.contains(name) || !deviceNames.contains(name)
        }
        for item in expired {
            NSStatusBar.system.removeStatusItem(item)
        }
        let expiredIDs = Set(expired.compactMap { $0.button?.toolTip })
        pinnedItems.removeAll {
            guard let name = $0.button?.toolTip else { return true }
            return expiredIDs.contains(name)
        }
    }

    private func rebuildMenu() {
        var allDevices = AirBatteryModel.getAll()
        let internalBattery = InternalBattery.status
        if internalBattery.hasBattery {
            allDevices.insert(
                AirBatteryModel.internalBatteryDevice(from: internalBattery),
                at: 0
            )
        }

        let host = NSHostingView(
            rootView: popover(fromDock: false, allDevice: allDevices)
        )
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 1)
        host.layoutSubtreeIfNeeded()
        host.frame.size.height = ceil(max(host.fittingSize.height, 1))

        let item = NSMenuItem()
        item.view = host

        menu.removeAllItems()
        menu.addItem(item)
    }
}

@MainActor
func refeshPinnedBar(unpin: String? = nil) {
    StatusBarController.shared.refreshPinnedItems(unpin: unpin)
}

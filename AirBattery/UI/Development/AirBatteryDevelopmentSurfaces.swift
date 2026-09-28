import AirBatteryShared
import AppKit
import SwiftUI

/// Narrow package-only construction seam used by development harnesses.
///
/// These helpers deliberately reuse AirBattery's production surface components
/// without starting the production service graph. They are package-scoped so
/// they do not become part of AirBatteryKit's public API.
@MainActor
package enum AirBatteryDevelopmentSurfaces {
    package static func popover(
        devices: [Device],
        fromDock: Bool = false,
        mergeEarbuds: Bool = true,
        mergeThreshold: Int = 5
    ) -> AnyView {
        let presentations = AirPodsPresentation.logicalPresentations(
            from: devices,
            mergeEarbuds: mergeEarbuds,
            mergeThreshold: mergeThreshold
        )

        return AnyView(
            ZStack {
                if fromDock {
                    Color.clear.background(BlurView(material: .menu))
                }

                VStack(spacing: 0) {
                    PopoverToolbarSurfaceContent(
                        fromDock: fromDock,
                        nearcastEnabled: false,
                        onHide: {},
                        onAbout: {},
                        onSettings: {},
                        onQuit: {},
                        onRefreshNearcast: {}
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        if presentations.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "battery.0percent")
                                    .frame(width: 22, height: 22)
                                    .foregroundStyle(.secondary)
                                Text("No battery devices")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                        } else {
                            ForEach(Array(presentations.enumerated()), id: \.element.id) { index, presentation in
                                MenuDeviceRowContent(
                                    presentation: presentation,
                                    compactName: fromDock,
                                    showBatteryTrailing: true,
                                    expanded: false
                                )
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)

                                if index < presentations.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .popoverDevicePanelSurface()
                    .offset(y: 2.5)
                }
            }
            .frame(width: 352)
            .fixedSize(horizontal: false, vertical: true)
            .modifier(PopoverHostSurfaceModifier(fromDock: fromDock))
        )
    }

    package static func statusMenu(
        devices: [Device],
        mergeEarbuds: Bool = true,
        mergeThreshold: Int = 5
    ) -> NSMenu {
        let root = popover(
            devices: devices,
            mergeEarbuds: mergeEarbuds,
            mergeThreshold: mergeThreshold
        )
        let host = ContentFittingHostingView(width: 352, rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 352, height: 1)
        host.layoutSubtreeIfNeeded()
        host.resizeToFitContent()

        let item = NSMenuItem()
        item.view = host

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item)
        return menu
    }

    package static func dockTile(
        devices: [Device],
        darkMode: Bool,
        showMacAsPercent: Bool = false,
        mergeEarbuds: Bool = true,
        mergeThreshold: Int = 5
    ) -> AnyView {
        let presentations = AirPodsPresentation.logicalPresentations(
            from: devices,
            mergeEarbuds: mergeEarbuds,
            mergeThreshold: mergeThreshold
        )

        return AnyView(
            DockTileSurfaceContent(
                presentations: Array(presentations.prefix(4)),
                darkMode: darkMode,
                showMacAsPercent: showMacAsPercent
            )
        )
    }

    package static var settingsWindowContentSize: CGSize {
        AirBatterySettingsWindowConfiguration.initialContentSize
    }

    package static func settingsWindow() -> AnyView {
        AnyView(SettingsView(initialSelection: .display))
    }

    package static func configureSettingsWindow(_ window: NSWindow) {
        AirBatterySettingsWindowConfiguration.apply(to: window)
    }

    package static func displaySettings() -> AnyView {
        AnyView(DisplayView())
    }

    package static func batteryGlyph(device: Device) -> AnyView {
        AnyView(BatteryView(item: device))
    }

    package static func configureStatusItem(
        _ statusItem: NSStatusItem,
        device: Device,
        colorfulBattery: Bool = true,
        iosBatteryStyle: Bool = false,
        batteryPercent: String = "outside",
        hideLevel: Int = 90
    ) {
        let item = iBattery(
            hasBattery: device.hasBattery,
            isCharging: device.isCharging != 0,
            isCharged: device.isCharged,
            acPowered: device.acPowered || device.isCharging != 0,
            timeLeft: "",
            batteryLevel: device.batteryLevel,
            lowPower: device.lowPower
        )
        let width: CGFloat =
            batteryPercent == "outside" && device.batteryLevel <= hideLevel
                ? 76
                : 42
        statusItem.length = width

        guard let button = statusItem.button else { return }
        button.subviews.forEach { $0.removeFromSuperview() }

        let root = StatusBarBatteryContent(
            item: item,
            showMacBattery: true,
            colorfulBattery: colorfulBattery,
            iosBatteryStyle: iosBatteryStyle,
            batteryPercent: batteryPercent,
            hideLevel: hideLevel
        )
        let host = StatusItemHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 21.5)
        host.autoresizingMask = [.width]

        button.image = NSImage()
        button.toolTip = "AirBattery — \(device.deviceName) \(device.batteryLevel) percent"
        button.addSubview(host)
    }
}

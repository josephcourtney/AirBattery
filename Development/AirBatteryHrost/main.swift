import AirBatteryKit
import AirBatteryShared
import AirBatteryWidgetKit
import AppKit
import Hrost
import SwiftUI

enum AirBatteryHrostScenario: String, CaseIterable, HrostScenario {
    case empty
    case singleDevice = "single-device"
    case airPods = "airpods"
    case charging
    case manyDevices = "many-devices"
    case longNames = "long-names"
    case noBattery = "no-battery"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .empty: "Empty"
        case .singleDevice: "Single Device"
        case .airPods: "AirPods"
        case .charging: "Charging"
        case .manyDevices: "Many Devices"
        case .longNames: "Long Names"
        case .noBattery: "No Battery Data"
        }
    }

    var devices: [Device] {
        switch self {
        case .empty:
            []

        case .singleDevice:
            [Self.mac(level: 73)]

        case .airPods:
            [
                Self.mac(level: 64),
                Self.device(
                    id: "airpods-case",
                    type: "ap_case",
                    name: "AirPods Pro (Case)",
                    level: 81
                ),
                Self.device(
                    id: "airpods-left",
                    type: "ap_pod_left",
                    name: "AirPods Pro 🄻",
                    level: 56,
                    parentName: "AirPods Pro"
                ),
                Self.device(
                    id: "airpods-right",
                    type: "ap_pod_right",
                    name: "AirPods Pro 🅁",
                    level: 53,
                    parentName: "AirPods Pro"
                ),
            ]

        case .charging:
            [
                Self.mac(level: 42, charging: 1, acPowered: true),
                Self.device(
                    id: "iphone",
                    type: "iPhone",
                    name: "iPhone",
                    level: 28,
                    charging: 1
                ),
                Self.device(
                    id: "mouse",
                    type: "MMouse",
                    name: "Magic Mouse",
                    level: 9
                ),
            ]

        case .manyDevices:
            [
                Self.mac(level: 88),
                Self.device(id: "iphone", type: "iPhone", name: "iPhone", level: 67),
                Self.device(id: "watch", type: "Watch", name: "Apple Watch", level: 44),
                Self.device(id: "keyboard", type: "Keyboard", name: "Magic Keyboard", level: 91),
                Self.device(id: "mouse", type: "MMouse", name: "Magic Mouse", level: 35),
                Self.device(id: "trackpad", type: "Trackpad", name: "Magic Trackpad", level: 58),
                Self.device(id: "beats", type: "Headphones", name: "Beats Studio Pro", level: 76),
                Self.device(id: "ipad", type: "iPad", name: "iPad", level: 22),
            ]

        case .longNames:
            [
                Self.mac(level: 61),
                Self.device(
                    id: "long-keyboard",
                    type: "Keyboard",
                    name: "Joseph’s Extremely Long Descriptive Magic Keyboard Name",
                    level: 47
                ),
                Self.device(
                    id: "long-headphones",
                    type: "Headphones",
                    name: "Conference Room Headphones With An Implausibly Long Device Name",
                    level: 83
                ),
            ]

        case .noBattery:
            [
                Self.device(
                    id: "unknown",
                    type: "general_bt",
                    name: "Connected Device Without Battery Data",
                    level: 0,
                    hasBattery: false
                ),
            ]
        }
    }

    var statusDevice: Device {
        devices.first(where: { $0.deviceID == "@MacInternalBattery" })
            ?? devices.first
            ?? Self.device(
                id: "no-battery",
                type: "mac",
                name: "This Mac",
                level: 0,
                hasBattery: false
            )
    }

    private static func mac(
        level: Int,
        charging: Int = 0,
        acPowered: Bool = false
    ) -> Device {
        device(
            id: "@MacInternalBattery",
            type: "macbook",
            name: "This Mac",
            level: level,
            charging: charging,
            acPowered: acPowered
        )
    }

    private static func device(
        id: String,
        type: String,
        name: String,
        level: Int,
        charging: Int = 0,
        acPowered: Bool = false,
        hasBattery: Bool = true,
        parentName: String = ""
    ) -> Device {
        Device(
            hasBattery: hasBattery,
            deviceID: id,
            deviceType: type,
            deviceName: name,
            batteryLevel: level,
            isCharging: charging,
            acPowered: acPowered,
            parentName: parentName,
            lastUpdate: 1_800_000_000
        )
    }
}

@MainActor
struct AirBatteryHrostManifest: HrostManifest {
    let name = "AirBattery"
    let scenarios = AirBatteryHrostScenario.allCases
    let surfaces: [HrostSurface<AirBatteryHrostScenario>]

    var capturePresets: [HrostCapturePreset] {
        [
            HrostCapturePreset(
                id: "smoke",
                title: "Smoke",
                selection: HrostCaptureSelection(
                    scenarios: .only([AirBatteryHrostScenario.singleDevice.id]),
                    variants: .defaults,
                    appearances: [.system]
                )
            ),
            HrostCapturePreset(
                id: "visual-regression",
                title: "Visual Regression",
                selection: HrostCaptureSelection(
                    scenarios: .only([
                        AirBatteryHrostScenario.airPods.id,
                        AirBatteryHrostScenario.charging.id,
                        AirBatteryHrostScenario.longNames.id,
                        AirBatteryHrostScenario.noBattery.id,
                    ]),
                    variants: .defaultsPlus(["medium"]),
                    appearances: [.light, .dark]
                )
            ),
            HrostCapturePreset(
                id: "edge-cases",
                title: "Edge Cases",
                selection: HrostCaptureSelection(
                    scenarios: .only([
                        AirBatteryHrostScenario.empty.id,
                        AirBatteryHrostScenario.manyDevices.id,
                        AirBatteryHrostScenario.longNames.id,
                        AirBatteryHrostScenario.noBattery.id,
                    ]),
                    variants: .defaults,
                    appearances: [.light, .dark]
                )
            ),
            HrostCapturePreset(
                id: "airpods",
                title: "AirPods",
                selection: HrostCaptureSelection(
                    surfaces: .only([
                        "main-popover",
                        "status-menu",
                        "status-item",
                        "dock-tile",
                        "overview-widget",
                        "battery-glyph",
                    ]),
                    scenarios: .only([AirBatteryHrostScenario.airPods.id]),
                    variants: .defaultsPlus(["medium"]),
                    appearances: [.light, .dark]
                )
            ),
            HrostCapturePreset(
                id: "everything",
                title: "Everything",
                selection: HrostCaptureSelection(
                    variants: .allCompatible,
                    appearances: Set(HrostAppearance.allCases)
                )
            ),
        ]
    }

    init() {
        let popoverVariants = [
            HrostVariant(
                id: "regular",
                title: "Regular",
                size: CGSize(width: 352, height: 400)
            ),
            HrostVariant(
                id: "compact",
                title: "Compact",
                size: CGSize(width: 352, height: 260)
            ),
            HrostVariant(
                id: "tall",
                title: "Tall",
                size: CGSize(width: 352, height: 560)
            ),
        ]
        let dockVariants = [
            HrostVariant(
                id: "dock",
                title: "Dock Tile",
                size: CGSize(width: 128, height: 128)
            ),
        ]
        let widgetVariants = [
            HrostVariant(
                id: "small",
                title: "Small",
                size: CGSize(width: 170, height: 170)
            ),
            HrostVariant(
                id: "medium",
                title: "Medium",
                size: CGSize(width: 360, height: 170)
            ),
            HrostVariant(
                id: "large",
                title: "Large",
                size: CGSize(width: 360, height: 360)
            ),
        ]

        surfaces = [
            .popover(
                id: "main-popover",
                title: "Main Popover",
                contentSize: CGSize(width: 352, height: 400),
                variants: popoverVariants
            ) { context in
                AirBatteryDevelopmentSurfaces.popover(
                    devices: context.scenario.devices
                )
            },

            .menu(id: "status-menu", title: "Status Menu") { context in
                AirBatteryDevelopmentSurfaces.statusMenu(
                    devices: context.scenario.devices
                )
            },

            .statusItem(id: "status-item", title: "Status Item") { statusItem, context in
                AirBatteryDevelopmentSurfaces.configureStatusItem(
                    statusItem,
                    device: context.scenario.statusDevice
                )
            },

            .view(
                id: "dock-tile",
                title: "Dock Tile",
                variants: dockVariants
            ) { context in
                AirBatteryDevelopmentSurfaces.dockTile(
                    devices: context.scenario.devices,
                    darkMode: context.environment.appearance == .dark
                )
            },

            .window(
                id: "display-settings",
                title: "Display Settings",
                initialSize: CGSize(width: 740, height: 720)
            ) { _ in
                AirBatteryDevelopmentSurfaces.displaySettings()
            },

            .widget(
                id: "overview-widget",
                title: "Overview Widget",
                variants: widgetVariants
            ) { context in
                AirBatteryWidgetDevelopmentSurfaces.overview(
                    devices: context.scenario.devices,
                    family: widgetFamily(for: context.variant.id)
                )
                .padding(12)
            },

            .view(id: "battery-glyph", title: "Battery Glyph") { context in
                AirBatteryDevelopmentSurfaces.batteryGlyph(
                    device: context.scenario.statusDevice
                )
                .padding(16)
            },
        ]
    }
}

private func widgetFamily(for variantID: String) -> AirBatteryWidgetDevelopmentFamily {
    switch variantID {
    case "medium": .medium
    case "large": .large
    default: .small
    }
}

private func configureHarnessDefaults() {
    let defaults = UserDefaults.standard
    defaults.set(false, forKey: "nearCast")
    defaults.set(true, forKey: "twsMergeEnabled")
    defaults.set(5, forKey: "twsMerge")
    defaults.set("both", forKey: "showOn")
    defaults.set("auto", forKey: "appearance")
    defaults.set("icon", forKey: "showThisMac")
    defaults.set(true, forKey: "carouselMode")
    defaults.set(true, forKey: "intBattOnStatusBar")
    defaults.set(true, forKey: "colorfulBattery")
    defaults.set(false, forKey: "iosBatteryStyle")
    defaults.set("outside", forKey: "batteryPercent")
    defaults.set(90, forKey: "hideLevel")
}

@main
struct AirBatteryHrost {
    @MainActor
    static func main() {
        configureHarnessDefaults()
        HrostMain.run(AirBatteryHrostManifest())
    }
}

import AppKit
import SwiftUI
import WidgetKit

struct DisplayView: View {
    @AppStorage("showOn") var showOn = "sbar"
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("showThisMac") var showThisMac = "icon"
    @AppStorage("carouselMode") var carouselMode = true
    @AppStorage("colorfulBattery") var colorfulBattery = false
    @AppStorage("iosBatteryStyle") var iosBatteryStyle = false
    @AppStorage("intBattOnStatusBar") var intBattOnStatusBar = true
    @AppStorage("batteryPercent") var batteryPercent = "outside"
    @AppStorage("hideLevel") var hideLevel = 90
    @AppStorage("twsMergeEnabled") private var twsMergeEnabled = true
    @AppStorage("twsMerge") private var twsMerge = 5
    @AppStorage("revListOnWidget") var revListOnWidget = false
    @AppStorage("widgetInterval") var widgetInterval = 0
    @AppStorage("deviceName") var deviceName = "Mac"

    @State private var levelList = [95, 90, 80, 70, 60, 50, 40, 30, 20, 10]

    var body: some View {
        ScrollView {
            SForm(noSpacer: true) {
                SGroupBox(label: "Surfaces") {
                    SPicker(
                        "Show AirBattery",
                        selection: $showOn,
                        tips: "Choose whether AirBattery itself appears in the menu bar, Dock, both, or neither. Widgets are available independently."
                    ) {
                        Text("Menu Bar").tag("sbar")
                        Text("Dock").tag("dock")
                        Text("Both").tag("both")
                        Text("None").tag("none")
                    }
                    .onChange(of: showOn) { _, newValue in
                        applySurfaceSelection(newValue)
                    }

                    Divider().opacity(0.5)

                    SPicker("Appearance", selection: $appearance) {
                        Text("Automatic").tag("auto")
                        Text("Light").tag("false")
                        Text("Dark").tag("true")
                    }
                    .pickerStyle(.segmented)
                }

                SGroupBox(label: "Menu Bar") {
                    SToggle(
                        "Show this Mac’s battery",
                        isOn: $intBattOnStatusBar,
                        tips: "When enabled, the menu-bar item displays this Mac’s battery. When disabled, it uses the AirBattery status icon instead."
                    )
                    Divider().opacity(0.5)
                    SToggle("Use battery colors", isOn: $colorfulBattery)
                        .disabled(!intBattOnStatusBar)
                    Divider().opacity(0.5)
                    SPicker("Battery style", selection: $iosBatteryStyle) {
                        Text("macOS").tag(false)
                        Text("iOS").tag(true)
                    }
                    .disabled(!intBattOnStatusBar)
                    Divider().opacity(0.5)
                    SPicker("Percentage", selection: $batteryPercent) {
                        Text("Hidden").tag("hide")
                        Text("Inside").tag("inside")
                        Text("Outside").tag("outside")
                    }
                    .disabled(!intBattOnStatusBar)
                    Divider().opacity(0.5)
                    SPicker("Hide percentage above", selection: $hideLevel) {
                        Text("Never").tag(100)
                        ForEach(levelList, id: \.self) { number in
                            Text("\(number)%").tag(number)
                        }
                        if !levelList.contains(hideLevel) && hideLevel != 100 {
                            Text("\(hideLevel)%").tag(hideLevel)
                        }
                    }
                    .disabled(!intBattOnStatusBar || batteryPercent == "hide")

                    Text("Yellow continues to mean Low Power Mode (or a genuinely low battery), matching macOS battery semantics.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SGroupBox(label: "Device Rows") {
                    SPicker(
                        "Earbud merging",
                        selection: $twsMergeEnabled,
                        tips: "When off, left and right battery levels are always shown separately. When enabled, they merge only when their charging states match and their levels are within the configured threshold."
                    ) {
                        Text("Off").tag(false)
                        Text("Within threshold").tag(true)
                    }
                    if twsMergeEnabled {
                        Divider().opacity(0.5)
                        SSteper(
                            "Merge threshold (%)",
                            value: $twsMerge,
                            min: 0,
                            max: 99,
                            tips: "Merge left and right earbud levels when their difference is at most this percentage."
                        )
                    }
                }

                SGroupBox(label: "Dock") {
                    SPicker(
                        "Built-in battery",
                        selection: $showThisMac,
                        tips: "Choose how this Mac’s built-in battery appears in the Dock icon."
                    ) {
                        Text("Hidden").tag("hidden")
                        Text("Device Icon").tag("icon")
                        Text("Percent").tag("percent")
                    }
                    Divider().opacity(0.5)
                    SToggle(
                        "Carousel Mode",
                        isOn: $carouselMode,
                        tips: "Cycle through logical devices when more devices are available than fit in the Dock tile."
                    )
                }

                SGroupBox(label: "Widgets") {
                    SToggle("Reverse device list", isOn: $revListOnWidget)
                    Divider().opacity(0.5)
                    SPicker("Refresh interval", selection: $widgetInterval) {
                        Text("System Default").tag(-1)
                        Text("Same as Discovery").tag(0)
                    }
                    Divider().opacity(0.5)
                    SButton("Reload all widgets", buttonTitle: "Reload") {
                        AirBatteryModel.writeData()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }

                SGroupBox(label: "Preview") {
                    DisplaySurfacePreview(
                        mergeEarbuds: twsMergeEnabled,
                        mergeThreshold: twsMerge,
                        reverseWidgetOrder: revListOnWidget,
                        showMacInDock: showThisMac != "hidden",
                        showMacAsPercent: showThisMac == "percent",
                        menuBarShowsMac: intBattOnStatusBar,
                        colorfulBattery: colorfulBattery,
                        iosBatteryStyle: iosBatteryStyle,
                        batteryPercent: batteryPercent,
                        hideLevel: hideLevel,
                        appearance: appearance
                    )
                }
            }
        }
    }

    private func applySurfaceSelection(_ newValue: String) {
        SurfaceController.shared.apply(
            newValue,
            settingsVisible: true
        )

        if newValue == "dock" || newValue == "both" {
            _ = createAlert(
                title: "AirBattery Tips".local,
                message: "Displaying AirBattery on the Dock will consume more power; Menu Bar mode or Widgets generally use less.".local,
                button1: "OK"
            ).runModal()
        }

    }

}

private struct DisplaySurfacePreview: View {
    let mergeEarbuds: Bool
    let mergeThreshold: Int
    let reverseWidgetOrder: Bool
    let showMacInDock: Bool
    let showMacAsPercent: Bool
    let menuBarShowsMac: Bool
    let colorfulBattery: Bool
    let iosBatteryStyle: Bool
    let batteryPercent: String
    let hideLevel: Int
    let appearance: String

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var widgetPreviewPercentages = true
    @State private var widgetPreviewLabels = true
    @State private var livePreviewDevices = [Device]()
    @State private var livePreviewInternalBattery = InternalBattery.status
    @ObservedObject private var monitoring = MonitoringCoordinator.shared

    private var previewColorScheme: ColorScheme {
        switch appearance {
        case "true":
            return .dark
        case "false":
            return .light
        default:
            return systemColorScheme
        }
    }

    private var previewDevices: [Device] {
        livePreviewDevices.contains(where: \.hasBattery)
            ? livePreviewDevices
            : sampleDevices
    }

    private var previewInternalBattery: iBattery {
        livePreviewInternalBattery.hasBattery
            ? livePreviewInternalBattery
            : sampleInternalBattery
    }

    private var presentations: [LogicalDevicePresentation] {
        AirBatteryModel.logicalPresentations(
            from: previewDevices,
            mergeEarbuds: mergeEarbuds,
            mergeThreshold: mergeThreshold
        )
    }

    private var widgetStoredPreviewDevices: [Device] {
        AirBatteryModel.widgetStoredDevices(
            from: previewDevices.filter {
                $0.deviceID != "@MacInternalBattery"
            },
            internalBattery: previewDevices.first {
                $0.deviceID == "@MacInternalBattery"
            },
            reverse: reverseWidgetOrder
        )
    }

    private var dockPresentations: [LogicalDevicePresentation] {
        Array(
            presentations
                .filter {
                    showMacInDock ||
                        $0.representative.deviceID != "@MacInternalBattery"
                }
                .prefix(4)
        )
    }

    private var widgetRingDevices: [Device] {
        AirBatteryModel.widgetPresentationOrder(
            from: widgetStoredPreviewDevices
        )
    }

    private var singleBatteryPreviewDevice: Device? {
        widgetRingDevices.first {
            $0.deviceID != "@MacInternalBattery"
        } ?? widgetRingDevices.first
    }

    private let familyColumns = [
        GridItem(
            .adaptive(minimum: 340, maximum: 360),
            spacing: 16,
            alignment: .top
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            previewSection("Menu Bar") {
                HStack {
                    StatusBarBatteryContent(
                        item: previewInternalBattery,
                        showMacBattery: menuBarShowsMac,
                        colorfulBattery: colorfulBattery,
                        iosBatteryStyle: iosBatteryStyle,
                        batteryPercent: batteryPercent,
                        hideLevel: hideLevel
                    )
                    Spacer()
                }
                .frame(height: 28)
            }

            Divider().opacity(0.35)

            previewSection("Popover") {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 8.5)

                    PopoverToolbarSurfaceContent(
                        fromDock: false,
                        nearcastEnabled: false,
                        onHide: {},
                        onAbout: {},
                        onSettings: {},
                        onQuit: {},
                        onRefreshNearcast: {}
                    )

                    VStack(spacing: 0) {
                        ForEach(presentations.indices, id: \.self) { index in
                            MenuDeviceRowContent(
                                presentation: presentations[index]
                            )
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)

                            if index != presentations.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .popoverDevicePanelSurface()
                    .offset(y: 2.5)

                    Color.clear.frame(height: 8.5)
                }
                .frame(width: 352)
                .liquidGlassEffect(
                    cornerRadius: 10,
                    interactive: false,
                    tint: .primary.opacity(0.04)
                )
            }

            Divider().opacity(0.35)

            previewSection("Dock") {
                DockTileSurfaceContent(
                    presentations: dockPresentations,
                    darkMode: previewColorScheme == .dark,
                    showMacAsPercent: showMacAsPercent
                )
            }

            Divider().opacity(0.35)

            VStack(alignment: .leading, spacing: 14) {
                Text("Widgets")
                    .font(.headline)

                Text(
                    "Battery Overview replaces the historical Battery List " +
                    "and Battery Rings variants for new widgets. Each placed " +
                    "widget can independently show or hide percentages and labels."
                )
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 18) {
                    Toggle(
                        "Percentages",
                        isOn: $widgetPreviewPercentages
                    )
                    .toggleStyle(.switch)
                    .fixedSize()

                    Toggle(
                        "Labels",
                        isOn: $widgetPreviewLabels
                    )
                    .toggleStyle(.switch)
                    .fixedSize()

                    Spacer()
                }

                LazyVGrid(
                    columns: familyColumns,
                    alignment: .leading,
                    spacing: 24
                ) {
                    widgetFamilyPreview(
                        "Battery Overview — Small",
                        family: .small
                    ) {
                        WidgetOverviewRingsSurfaceContent(
                            devices: widgetRingDevices,
                            family: .small,
                            showPercentages: widgetPreviewPercentages,
                            showLabels: widgetPreviewLabels
                        )
                    }

                    widgetFamilyPreview(
                        "Battery Overview — Medium",
                        family: .medium
                    ) {
                        WidgetOverviewRingsSurfaceContent(
                            devices: widgetRingDevices,
                            family: .medium,
                            showPercentages: widgetPreviewPercentages,
                            showLabels: widgetPreviewLabels
                        )
                    }

                    widgetFamilyPreview(
                        "Battery Overview — Large",
                        family: .large
                    ) {
                        WidgetOverviewRingsSurfaceContent(
                            devices: widgetRingDevices,
                            family: .large,
                            showPercentages: widgetPreviewPercentages,
                            showLabels: widgetPreviewLabels
                        )
                    }

                    widgetFamilyPreview(
                        "Single Battery — Small",
                        family: .small
                    ) {
                        WidgetSingleBatterySurfaceContent(
                            item: singleBatteryPreviewDevice,
                            deviceName:
                                singleBatteryPreviewDevice?.deviceName ?? "",
                            warningText: "Right click to configure"
                        )
                    }
                }

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, previewColorScheme)
        .onAppear {
            refreshPreviewData()
        }
        .onReceive(monitoring.$secondTick) { _ in
            refreshPreviewData()
        }
    }

    private func refreshPreviewData() {
        let internalBattery = InternalBattery.status
        var devices = AirBatteryModel.getAll()
        if internalBattery.hasBattery {
            devices.insert(ib2ab(internalBattery), at: 0)
        }
        livePreviewInternalBattery = internalBattery
        livePreviewDevices = devices
    }

    @ViewBuilder
    private func previewSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func widgetFamilyPreview<Content: View>(
        _ title: String,
        family: WidgetPreviewFamily,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ZStack {
                content()
                    .padding(family.hostPadding)
            }
            .frame(
                width: family.size.width,
                height: family.size.height,
                alignment: .center
            )
            .liquidGlassPanel(
                cornerRadius: 22,
                interactive: false,
                tint: .primary.opacity(0.01)
            )
            .shadow(
                color: .black.opacity(
                    previewColorScheme == .dark ? 0.16 : 0.07
                ),
                radius: 7,
                y: 2
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sampleInternalBattery: iBattery {
        iBattery(
            hasBattery: true,
            isCharging: false,
            isCharged: false,
            acPowered: false,
            timeLeft: "02:14",
            batteryLevel: 69,
            lowPower: true
        )
    }

    private var sampleDevices: [Device] {
        let now = Date().timeIntervalSince1970
        return [
            Device(
                deviceID: "@MacInternalBattery",
                deviceType: "macbookpro",
                deviceName: "LT-0801530",
                batteryLevel: 69,
                isCharging: 0,
                lowPower: true,
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-iphone",
                deviceType: "iPhone",
                deviceName: "Joseph’s iPhone",
                deviceModel: "iPhone14,7",
                batteryLevel: 86,
                isCharging: 0,
                lastUpdate: now,
                batterySource: .ble
            ),
            Device(
                deviceID: "preview-watch",
                deviceType: "Watch",
                deviceName: "Joseph’s Apple Watch",
                batteryLevel: 54,
                isCharging: 1,
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-airpods-case",
                deviceType: "ap_case",
                deviceName: "Joseph’s AirPods (Case)",
                batteryLevel: 100,
                isCharging: 0,
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-airpods-left",
                deviceType: "ap_pod_left",
                deviceName: "Joseph’s AirPods Left",
                batteryLevel: 96,
                isCharging: 1,
                parentName: "Joseph’s AirPods",
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-airpods-right",
                deviceType: "ap_pod_right",
                deviceName: "Joseph’s AirPods Right",
                batteryLevel: 98,
                isCharging: 1,
                parentName: "Joseph’s AirPods",
                lastUpdate: now
            )
        ]
    }
}

private enum WidgetPreviewFamily {
    case small
    case medium
    case large

    var size: CGSize {
        switch self {
        case .small:
            return CGSize(width: 172, height: 172)
        case .medium:
            return CGSize(width: 352, height: 172)
        case .large:
            return CGSize(width: 352, height: 368)
        }
    }

    var hostPadding: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 8
        case .large:
            return 10
        }
    }
}


import AppKit
import SwiftUI

struct StatusBarBatteryContent: View {
    let item: iBattery
    let showMacBattery: Bool
    let colorfulBattery: Bool
    let iosBatteryStyle: Bool
    let batteryPercent: String
    let hideLevel: Int

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if item.hasBattery && showMacBattery {
                if batteryPercent == "outside", item.batteryLevel <= hideLevel {
                    Text("\(item.batteryLevel)%")
                        .font(.system(size: 11))
                }

                if iosBatteryStyle {
                    iosBattery
                } else {
                    macOSBattery
                }
            } else {
                Image("bolt.square.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
    }

    @ViewBuilder
    private var macOSBattery: some View {
        let width = round(max(2, min(19, Double(item.batteryLevel) / 100 * 19)))
        ZStack(alignment: .leading) {
            Image(
                colorfulBattery || batteryPercent == "inside"
                    ? "batt_outline_bold"
                    : "batt_outline"
            )

            if batteryPercent == "inside", item.batteryLevel <= hideLevel {
                StatusBarBatteryLevelContent(item: item)
                    .scaleEffect(0.9)
                    .foregroundColor(
                        colorfulBattery
                            ? Color(getPowerColor(ib2ab(item)))
                            : .primary
                    )
                    .offset(x: item.batteryLevel < 100 ? -1 : -0.5)
            } else {
                Rectangle()
                    .fill(
                        colorfulBattery
                            ? Color(getPowerColor(ib2ab(item)))
                            : (item.batteryLevel <= 10 ? .red : .primary)
                    )
                    .frame(width: width, height: 8, alignment: .leading)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 1.5,
                            style: .continuous
                        )
                    )
                    .offset(x: 2)

                if item.acPowered {
                    powerOverlay(xOffset: 6)
                }
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private var iosBattery: some View {
        ZStack(alignment: .leading) {
            Image("battery.100percent")
                .resizable()
                .scaledToFit()
                .frame(width: 27)
                .opacity(0.4)
                .mask {
                    HStack {
                        Spacer().frame(minWidth: 0)
                        Rectangle().frame(
                            width: min(
                                25,
                                CGFloat(100 - item.batteryLevel) / 100 * 27
                            )
                        )
                    }
                }

            Image("battery.100percent")
                .resizable()
                .scaledToFit()
                .foregroundColor(
                    colorfulBattery
                        ? Color(getPowerColor(ib2ab(item)) + "2")
                        : (item.batteryLevel <= 10 ? .red : .primary)
                )
                .frame(width: 27)
                .mask {
                    HStack {
                        Rectangle().frame(
                            width: max(
                                2,
                                CGFloat(item.batteryLevel) / 100 * 27
                            )
                        )
                        Spacer().frame(minWidth: 0)
                    }
                }

            if batteryPercent == "inside", item.batteryLevel <= hideLevel {
                if colorfulBattery {
                    StatusBarBatteryLevelContent(item: item)
                        .foregroundColor(.white)
                } else {
                    StatusBarBatteryLevelContent(item: item)
                        .foregroundColor(.white)
                        .blendMode(.destinationOut)
                }
            } else if item.acPowered {
                powerOverlay(xOffset: 6.5)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private func powerOverlay(xOffset: CGFloat) -> some View {
        let name = "batt_" +
            ((item.isCharging || item.isCharged) ? "bolt" : "plug")
        Image(name + "_mask")
            .blendMode(.destinationOut)
            .offset(x: xOffset)
        Image(name)
            .offset(x: xOffset)
            .foregroundColor(.blackWhite)
    }
}

struct StatusBarBatteryLevelContent: View {
    let item: iBattery

    var body: some View {
        Group {
            if item.acPowered {
                HStack(spacing: -1) {
                    Text("\(item.batteryLevel)")
                        .font(
                            .system(
                                size: item.batteryLevel > 99 ? 10 : 11,
                                weight: .medium
                            )
                        )
                        .tracking(item.batteryLevel > 99 ? -0.3 : 0)
                        .offset(y: item.batteryLevel > 99 ? 0.4 : 0.5)

                    Image(
                        (item.isCharging || item.isCharged)
                            ? "bolt.fill"
                            : "powerplug.portrait.fill"
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 5)
                    .padding(.leading, 1)
                    .offset(y: item.batteryLevel < 100 ? 0.5 : 0)
                }
                .offset(x: item.batteryLevel < 100 ? 0.5 : -0.5)
                .offset(
                    y: (item.acPowered && item.batteryLevel < 100) ? -0.5 : 0
                )
            } else {
                Text("\(item.batteryLevel)")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .frame(maxHeight: 12, alignment: .center)
        .frame(maxWidth: 24, alignment: .center)
    }
}

struct SurfaceBatteryGlyph: View {
    let item: Device

    var body: some View {
        let width = round(
            max(1, min(19, Double(item.batteryLevel) / 100 * 19))
        )

        ZStack {
            ZStack(alignment: .leading) {
                Image("batt_outline_bold")
                Rectangle()
                    .fill(Color(getPowerColor(item)))
                    .frame(width: width, height: 8, alignment: .leading)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 1.5,
                            style: .continuous
                        )
                    )
                    .offset(x: 2)
            }

            if item.deviceID == "@MacInternalBattery" {
                if item.acPowered {
                    chargingOverlay(
                        isPlug: !(item.isCharging != 0 || item.isCharged)
                    )
                }
            } else if item.isCharging != 0 {
                chargingOverlay(isPlug: item.isCharging == 5)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private func chargingOverlay(isPlug: Bool) -> some View {
        let name = "batt_" + (isPlug ? "plug" : "bolt")
        Image(name + "_mask")
            .blendMode(.destinationOut)
            .offset(x: -1.5)
        Image(name)
            .offset(x: -1.5)
            .foregroundColor(.blackWhite)
    }
}

struct PopoverToolbarSurfaceContent: View {
    var fromDock = false
    var nearcastEnabled = false
    let onHide: () -> Void
    let onAbout: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void
    let onRefreshNearcast: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            if fromDock {
                PopoverToolbarSurfaceButton(
                    systemName: "minus.circle",
                    help: "Hide".local,
                    hoverColor: .myYellow,
                    action: onHide
                )
            }

            PopoverToolbarSurfaceButton(
                systemName: "info.circle",
                help: "About AirBattery".local,
                action: onAbout
            )

            PopoverToolbarSurfaceButton(
                systemName: "gearshape",
                help: "Settings".local,
                action: onSettings
            )

            PopoverToolbarSurfaceButton(
                systemName: "xmark.circle",
                help: "Quit AirBattery".local,
                hoverColor: .red,
                action: onQuit
            )

            Spacer()

            if nearcastEnabled {
                PopoverToolbarSurfaceButton(
                    systemName:
                        "antenna.radiowaves.left.and.right.circle",
                    help: "Refresh Nearcast".local,
                    action: onRefreshNearcast
                )
            }
        }
        .padding(.top, fromDock ? 8 : 6)
        .padding(.bottom, 4)
        .padding(.horizontal, 8)
    }
}

private struct PopoverToolbarSurfaceButton: View {
    let systemName: String
    let help: String
    var hoverColor: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 28, height: 28)
                .foregroundColor(
                    isHovered ? hoverColor : .secondary
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                    .fill(
                        isHovered
                            ? hoverColor.opacity(0.12)
                            : Color.clear
                    )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .accessibilityLabel(Text(help))
        .onHover { isHovered = $0 }
    }
}

private struct PopoverDevicePanelSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        Color.primary.opacity(
                            colorScheme == .dark ? 0.055 : 0.025
                        )
                    )
                    .padding(.vertical, -1)
                    .padding(.horizontal, 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        Color(nsColor: .separatorColor).opacity(0.5),
                        lineWidth: 0.75
                    )
                    .padding(.vertical, -1)
                    .padding(.horizontal, 5)
            )
    }
}

extension View {
    func popoverDevicePanelSurface() -> some View {
        modifier(PopoverDevicePanelSurfaceModifier())
    }
}

struct MenuDeviceRowContent: View {
    let presentation: LogicalDevicePresentation
    var compactName = false
    var alerted = false
    var pinned = false
    var showBatteryTrailing = true
    var now = Date().timeIntervalSince1970

    var body: some View {
        if presentation.components.count > 1 {
            airPodsContent
        } else if let component = presentation.components.first {
            singleDeviceContent(component.device)
        }
    }

    @ViewBuilder
    private var airPodsContent: some View {
        HStack(spacing: 8) {
            Image(getDeviceIcon(presentation.representative))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.blackWhite)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    stalePrefix +
                        (compactName
                            ? presentation.compactName
                            : presentation.displayName)
                )
                .font(.system(size: 12))
                .foregroundColor(.blackWhite)
                .lineLimit(1)

                HStack(spacing: 10) {
                    ForEach(presentation.components.prefix(3)) { component in
                        MenuBatteryComponentContent(component: component)
                    }
                }
            }

            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private func singleDeviceContent(_ device: Device) -> some View {
        HStack {
            Image(getDeviceIcon(device))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.blackWhite)
                .frame(width: 22, height: 22, alignment: .center)

            HStack(spacing: 1) {
                Text(
                    stalePrefix +
                        (compactName
                            ? presentation.compactName
                            : presentation.displayName)
                )
                .font(.system(size: 12))
                .foregroundColor(.blackWhite)
                .frame(height: 24, alignment: .center)

                Spacer().frame(width: 0.5)

                if alerted {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blackWhite)
                }

                if pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blackWhite)
                        .offset(y: 0.2)
                }
            }
            .padding(.horizontal, 7)

            Spacer()

            if device.hasBattery && showBatteryTrailing {
                Text("\(device.batteryLevel)%")
                    .foregroundColor(
                        device.batteryLevel <= 10 ? .darkMyRed : .primary
                    )
                    .font(.system(size: 11))
                SurfaceBatteryGlyph(item: device)
                    .scaleEffect(0.85)
            }
        }
    }

    private var stalePrefix: String {
        (now - presentation.newestUpdate) / 60 > 10 ? "⚠︎ " : ""
    }
}

struct MenuBatteryComponentContent: View {
    let component: BatteryComponentPresentation

    var body: some View {
        HStack(spacing: 3) {
            Image(getDeviceIcon(component.device))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.blackWhite)
                .frame(width: 11, height: 11)

            Text("\(component.level)%")
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundColor(
                    component.level <= 10 ? .darkMyRed : .primary
                )

            if component.charging != 0 {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .fixedSize()
        .help(component.label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(component.label), \(component.level) percent" +
                (component.charging != 0 ? ", charging" : "")
        )
    }
}

struct DockTileSurfaceContent: View {
    let presentations: [LogicalDevicePresentation]
    let darkMode: Bool
    let showMacAsPercent: Bool

    var body: some View {
        ZStack {
            Group {
                Image(darkMode ? "background_dark" : "background")
                RoundedRectangle(cornerRadius: 23.5, style: .continuous)
                    .strokeBorder(
                        darkMode ? .white : .black,
                        lineWidth: 2
                    )
                    .frame(width: 104, height: 104)
                    .opacity(darkMode ? 0.25 : 0)
                RoundedRectangle(cornerRadius: 23.5, style: .continuous)
                    .strokeBorder(.black, lineWidth: 1)
                    .frame(width: 104, height: 104)
                    .opacity(darkMode ? 0.55 : 0.2)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    dockCell(at: 0)
                    dockCell(at: 1)
                }
                HStack(spacing: 8) {
                    dockCell(at: 2)
                    dockCell(at: 3)
                }
            }
        }
        .frame(width: 128, height: 128, alignment: .center)
    }

    @ViewBuilder
    private func dockCell(at index: Int) -> some View {
        if presentations.indices.contains(index) {
            DockLogicalDeviceCell(
                presentation: presentations[index],
                darkMode: darkMode,
                showMacAsPercent: showMacAsPercent
            )
        } else {
            Color.clear
                .frame(width: 42, height: 42)
        }
    }
}

struct DockLogicalDeviceCell: View {
    let presentation: LogicalDevicePresentation
    let darkMode: Bool
    let showMacAsPercent: Bool

    var body: some View {
        Group {
            if presentation.components.count >= 3 {
                VStack(spacing: 0) {
                    componentGauge(at: 0, diameter: 19)
                    HStack(spacing: 2) {
                        componentGauge(at: 1, diameter: 16)
                        componentGauge(at: 2, diameter: 16)
                    }
                }
                .frame(width: 42, height: 42)
            } else if presentation.components.count == 2 {
                HStack(spacing: 2) {
                    componentGauge(at: 0, diameter: 18)
                    componentGauge(at: 1, diameter: 18)
                }
                .frame(width: 42, height: 42)
            } else if let component = presentation.components.first {
                DockComponentGauge(
                    device: component.device,
                    darkMode: darkMode,
                    diameter: 38,
                    showPercentInsteadOfIcon:
                        component.device.deviceID == "@MacInternalBattery" &&
                        showMacAsPercent
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func componentGauge(
        at index: Int,
        diameter: CGFloat
    ) -> some View {
        if presentation.components.indices.contains(index) {
            DockComponentGauge(
                device: presentation.components[index].device,
                darkMode: darkMode,
                diameter: diameter,
                showPercentInsteadOfIcon: false
            )
        }
    }

    private var accessibilitySummary: String {
        let values = presentation.components.map {
            "\($0.label) \($0.level) percent" +
                ($0.charging != 0 ? ", charging" : "")
        }
        .joined(separator: ", ")
        return "\(presentation.compactName), \(values)"
    }
}

struct DockComponentGauge: View {
    let device: Device
    let darkMode: Bool
    let diameter: CGFloat
    let showPercentInsteadOfIcon: Bool

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    darkMode
                        ? Color.white.opacity(0.2)
                        : Color.black.opacity(0.13),
                    style: StrokeStyle(
                        lineWidth: max(2, diameter * 0.15),
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(135))

            Circle()
                .trim(
                    from: 0,
                    to: Double(device.batteryLevel) / 100 * 0.75
                )
                .stroke(
                    Color(getPowerColor(device)),
                    style: StrokeStyle(
                        lineWidth: max(2, diameter * 0.13),
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(135))

            if showPercentInsteadOfIcon {
                Text("\(device.batteryLevel)")
                    .font(
                        .system(
                            size: max(5, diameter * 0.28),
                            weight: .bold
                        )
                    )
                    .foregroundColor(darkMode ? .white : .black)
            } else {
                Image(getDeviceIcon(device))
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(
                        device.isCharging != 0
                            ? Color("dark_" + getPowerColor(device))
                            : .blackWhite
                    )
                    .frame(
                        width: diameter * 0.46,
                        height: diameter * 0.46
                    )
            }

            if diameter >= 24 {
                Text(device.hasBattery ? "\(device.batteryLevel)" : "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(darkMode ? .white : .black)
                    .offset(y: diameter * 0.47)
                    .scaleEffect(0.7)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

enum WidgetOverviewFamily {
    case small
    case medium
    case large
}

struct WidgetOverviewRingsSurfaceContent: View {
    let devices: [Device]
    let family: WidgetOverviewFamily
    let showPercentages: Bool
    let showLabels: Bool

    private var items: [Device] {
        let limit: Int
        switch family {
        case .small:
            limit = 4
        case .medium:
            limit = 8
        case .large:
            limit = 9
        }
        return Array(devices.filter(\.hasBattery).prefix(limit))
    }

    private var columns: Int {
        switch family {
        case .small:
            return 2
        case .medium:
            return 4
        case .large:
            return 3
        }
    }

    private var rowCount: Int {
        guard !items.isEmpty else { return 0 }
        return (items.count + columns - 1) / columns
    }

    private var diameter: CGFloat {
        switch family {
        case .small:
            if showPercentages && showLabels { return 46 }
            if showPercentages || showLabels { return 52 }
            return 58
        case .medium:
            if showPercentages && showLabels { return 44 }
            if showPercentages || showLabels { return 50 }
            return 58
        case .large:
            if showPercentages && showLabels { return 58 }
            if showPercentages || showLabels { return 64 }
            return 72
        }
    }

    private var horizontalSpacing: CGFloat {
        switch family {
        case .small:
            return showPercentages || showLabels ? 13 : 17
        case .medium:
            return showPercentages || showLabels ? 14 : 18
        case .large:
            return showPercentages || showLabels ? 10 : 12
        }
    }

    private var verticalSpacing: CGFloat {
        switch family {
        case .small:
            return showPercentages && showLabels ? 5 : 9
        case .medium:
            return showPercentages && showLabels ? 5 : 9
        case .large:
            return showPercentages && showLabels ? 14 : 18
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                Text("No battery devices")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: verticalSpacing) {
                    ForEach(0..<rowCount, id: \.self) { row in
                        overviewRow(start: row * columns)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func overviewRow(start: Int) -> some View {
        let end = min(start + columns, items.count)
        HStack(spacing: horizontalSpacing) {
            ForEach(start..<end, id: \.self) { index in
                OverviewRingCell(
                    item: items[index],
                    diameter: diameter,
                    showPercentage: showPercentages,
                    showLabel: showLabels
                )
            }
        }
    }
}

private struct OverviewRingCell: View {
    let item: Device
    let diameter: CGFloat
    let showPercentage: Bool
    let showLabel: Bool

    private var lineWidth: CGFloat {
        diameter >= 64 ? 7 : 6
    }

    private var ringFraction: Double {
        showPercentage ? 0.78 : 1
    }

    private var ringRotation: Double {
        showPercentage ? 129.6 : 270
    }

    var body: some View {
        VStack(spacing: annotationSpacing) {
            ZStack {
                Circle()
                    .trim(from: 0, to: ringFraction)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .opacity(0.15)
                    .rotationEffect(.degrees(ringRotation))

                Circle()
                    .trim(
                        from: 0,
                        to: Double(item.batteryLevel) / 100 * ringFraction
                    )
                    .stroke(
                        Color(getPowerColor(item)),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .rotationEffect(.degrees(ringRotation))

                Image(getDeviceIcon(item))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: diameter * 0.45,
                        height: diameter * 0.45
                    )

                if item.isCharging != 0 {
                    Image("batt_bolt_mask")
                        .resizable()
                        .scaledToFit()
                        .frame(width: diameter * 0.2)
                        .blendMode(.destinationOut)
                        .offset(y: -diameter * 0.51)

                    Image("batt_bolt")
                        .resizable()
                        .scaledToFit()
                        .frame(width: diameter * 0.17)
                        .foregroundColor(
                            item.batteryLevel == 100
                                ? .myGreen
                                : .primary
                        )
                        .offset(y: -diameter * 0.51)
                }
            }
            .frame(width: diameter, height: diameter)
            .compositingGroup()

            if showPercentage {
                HStack(spacing: 2) {
                    Text("\(item.batteryLevel)%")
                        .monospacedDigit()
                    if item.isCharging != 0 {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .bold))
                    }
                }
                .font(percentageFont)
                .fixedSize()
            }

            if showLabel {
                Text(shortLabel)
                    .font(labelFont)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: diameter + 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var annotationSpacing: CGFloat {
        showPercentage ? 0 : 2
    }

    private var percentageFont: Font {
        .system(
            size: diameter >= 64 ? 12 : (diameter <= 46 ? 9 : 10),
            weight: .medium
        )
    }

    private var labelFont: Font {
        .system(size: diameter >= 64 ? 10 : (diameter <= 46 ? 8 : 8.5))
    }

    private var shortLabel: String {
        if item.deviceID == "@MacInternalBattery" {
            return "Mac"
        }

        switch item.deviceType {
        case "ap_case":
            return "Case"
        case "ap_pod_left":
            return "L"
        case "ap_pod_right":
            return "R"
        case "ap_pod_all":
            return "Earbuds"
        default:
            return DevicePresentationNaming.compactName(
                deviceType: item.deviceType,
                displayName: item.deviceName
            )
        }
    }

    private var accessibilitySummary: String {
        var values = [shortLabel, "\(item.batteryLevel) percent"]
        if item.isCharging != 0 {
            values.append("charging")
        }
        return values.joined(separator: ", ")
    }
}


struct WidgetSingleBatterySurfaceContent: View {
    let item: Device?
    let deviceName: String
    let warningText: String

    private let lineWidth = 10.0

    var body: some View {
        if let item {
            VStack(spacing: 10) {
                ZStack {
                    Group {
                        Group {
                            Circle()
                                .trim(from: 0, to: 0.8)
                                .stroke(
                                    style: StrokeStyle(
                                        lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                                .opacity(0.15)

                            Circle()
                                .trim(
                                    from: 0,
                                    to: Double(item.batteryLevel) /
                                        100 * 0.8
                                )
                                .stroke(
                                    Color(getPowerColor(item)),
                                    style: StrokeStyle(
                                        lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                        }
                        .rotationEffect(.degrees(126))

                        Image(getDeviceIcon(item))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)

                        if item.isCharging != 0 || item.acPowered {
                            Image("batt_bolt_mask")
                                .interpolation(.high)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18)
                                .blendMode(.destinationOut)
                                .offset(y: -55.5)

                            Image("batt_bolt")
                                .interpolation(.high)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16)
                                .foregroundColor(
                                    item.batteryLevel == 100
                                        ? .myGreen
                                        : .primary
                                )
                                .offset(y: -55.5)
                        }
                    }
                    .frame(width: 110, height: 110)

                    Text(item.hasBattery ? "\(item.batteryLevel)%" : "")
                        .font(.system(size: 17))
                        .offset(x: 1, y: 47)
                }
                .compositingGroup()

                Text(item.deviceName)
                    .font(.system(size: 12))
                    .frame(width: 144)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .offset(y: item.isCharging != 0 ? 5 : 3.5)
        } else {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: 98, height: 98)
                        .rotationEffect(.degrees(126))
                        .opacity(0.15)

                    Image(systemName: "gearshape")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Text(
                    deviceName.isEmpty
                        ? "Choose a device"
                        : "Searching: " + deviceName
                )
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 150)
                .lineLimit(1)
                .truncationMode(.middle)

                if deviceName.isEmpty {
                    Text(warningText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 150)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                deviceName.isEmpty
                    ? "Choose a device. \(warningText)"
                    : "Searching for \(deviceName)"
            )
        }
    }
}

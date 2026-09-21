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
            if presentation.components.count > 1 {
                VStack(spacing: 2) {
                    Image(getDeviceIcon(presentation.representative))
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.blackWhite)
                        .frame(width: 13, height: 13)

                    HStack(spacing: 1) {
                        ForEach(presentation.components.prefix(3)) { component in
                            DockComponentGauge(
                                device: component.device,
                                darkMode: darkMode,
                                diameter:
                                    presentation.components.count >= 3 ? 12 : 16,
                                showPercentInsteadOfIcon: false
                            )
                        }
                    }
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

struct WidgetLogicalDeviceRow: View {
    let presentation: LogicalDevicePresentation
    var rowHeight: CGFloat = 31

    var body: some View {
        HStack(spacing: 7) {
            Image(getDeviceIcon(presentation.representative))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)

            Text(
                "\(isStale ? "⚠︎ " : "")\(presentation.displayName)"
            )
            .font(.system(size: 11))
            .lineLimit(1)
            .frame(height: rowHeight, alignment: .center)

            Spacer(minLength: 6)

            HStack(spacing: 7) {
                ForEach(presentation.components.prefix(3)) { component in
                    HStack(spacing: 2) {
                        if presentation.components.count > 1 {
                            Text(component.label)
                                .foregroundColor(.secondary)
                        }
                        Text("\(component.level)%")
                            .foregroundColor(
                                component.level <= 10
                                    ? .darkMyRed
                                    : .primary
                            )
                            .monospacedDigit()
                        if component.charging != 0 {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 10))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var isStale: Bool {
        (Date().timeIntervalSince1970 - presentation.newestUpdate) / 60 > 10
    }

    private var accessibilitySummary: String {
        let batteries = presentation.components.map { component in
            "\(component.label) \(component.level) percent" +
                (component.charging != 0 ? ", charging" : "")
        }
        .joined(separator: ", ")
        return "\(presentation.displayName), \(batteries)"
    }
}

struct WidgetListSurfaceContent: View {
    let presentations: [LogicalDevicePresentation]
    var rowHeight: CGFloat = 31

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(presentations.indices, id: \.self) { index in
                WidgetLogicalDeviceRow(
                    presentation: presentations[index],
                    rowHeight: rowHeight
                )
                if index != presentations.count - 1 {
                    Divider()
                }
            }
            Spacer()
        }
        .offset(y: 4)
        .padding(.vertical, 8)
        .padding(.horizontal, 18)
    }
}

struct WidgetBatteryRingsSurfaceContent: View {
    let devices: [Device]
    private let lineWidth = 5.0

    private var items: [Device] {
        Array(devices.filter(\.hasBattery).prefix(8))
    }

    var body: some View {
        VStack(spacing: 7) {
            batteryRow(Array(items.prefix(4)))
            if items.count > 4 {
                batteryRow(Array(items.dropFirst(4)))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func batteryRow(_ row: [Device]) -> some View {
        HStack(spacing: 10) {
            ForEach(row, id: \.self) { item in
                batteryTile(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func batteryTile(_ item: Device) -> some View {
        VStack(spacing: 1) {
            ZStack {
                Group {
                    Circle()
                        .trim(from: 0.0, to: 0.78)
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
                            from: CGFloat(
                                abs(
                                    min(
                                        Double(item.batteryLevel) /
                                            100.0 * 0.78,
                                        0.78
                                    ) - 0.001
                                )
                            ),
                            to: CGFloat(
                                abs(
                                    min(
                                        Double(item.batteryLevel) /
                                            100.0 * 0.78,
                                        0.78
                                    ) - 0.0005
                                )
                            )
                        )
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .foregroundColor(Color(getPowerColor(item)))
                        .shadow(
                            color: .black,
                            radius: lineWidth * 0.6
                        )
                        .clipShape(
                            Circle()
                                .trim(from: 0.0, to: 0.78)
                                .stroke(
                                    style: StrokeStyle(
                                        lineWidth: lineWidth,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                        )
                        .opacity(item.batteryLevel == 100 ? 0 : 1)

                    Circle()
                        .trim(
                            from: 0.0,
                            to: Double(item.batteryLevel) / 100.0 * 0.78
                        )
                        .stroke(
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .foregroundColor(Color(getPowerColor(item)))
                }
                .rotationEffect(.degrees(129.6))

                Image(getDeviceIcon(item))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 21, height: 21)
            }
            .frame(width: 46, height: 46)

            HStack(spacing: 2) {
                Text("\(item.batteryLevel)%")
                    .foregroundColor(
                        item.batteryLevel <= 10 ? .darkMyRed : .primary
                    )
                if item.isCharging != 0 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(size: 8.5, weight: .medium))

            Text(shortDeviceLabel(item))
                .font(.system(size: 7.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 54)
        }
        .frame(width: 58)
    }

    private func shortDeviceLabel(_ item: Device) -> String {
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
}

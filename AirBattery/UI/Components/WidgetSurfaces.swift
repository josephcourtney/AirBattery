import AppKit
import SwiftUI

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

    private var presentations: [LogicalDevicePresentation] {
        AirPodsPresentation.widgetLogicalPresentations(from: devices)
    }

    private var groupedPresentations: [LogicalDevicePresentation] {
        presentations.filter { $0.components.count > 1 }
    }

    private var singlePresentations: [LogicalDevicePresentation] {
        presentations.filter { $0.components.count == 1 }
    }

    private var flatItems: [Device] {
        Array(
            presentations
                .flatMap(\.components)
                .map(\.device)
                .prefix(family == .medium ? 8 : 9)
        )
    }

    private var usesMediumGroupedLayout: Bool {
        family == .medium &&
            groupedPresentations.count == 1 &&
            singlePresentations.count <= 4 &&
            groupedPresentations[0].components.count <= 3
    }

    var body: some View {
        Group {
            if presentations.isEmpty {
                Text("No battery devices")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                switch family {
                case .small:
                    smallOverview
                case .medium:
                    if usesMediumGroupedLayout,
                       let group = groupedPresentations.first {
                        mediumGroupedOverview(group)
                    } else {
                        flatOverview(columns: 4, diameter: 42)
                    }
                case .large:
                    largeOverview
                }
            }
        }
    }

    private var smallOverview: some View {
        let values = Array(presentations.prefix(4))
        let rows = (values.count + 1) / 2

        return VStack(spacing: showLabels ? 4 : 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: showLabels ? 11 : 16) {
                    ForEach(rowItems(values, row: row, columns: 2)) { presentation in
                        smallLogicalCell(presentation)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func smallLogicalCell(
        _ presentation: LogicalDevicePresentation
    ) -> some View {
        if presentation.components.count > 1 {
            CompactCompoundBatteryMeter(
                presentation: presentation,
                style: .overviewSmall,
                showPercentages: showPercentages,
                showLabel: showLabels
            )
        } else if let component = presentation.components.first {
            OverviewRingCell(
                item: component.device,
                diameter: showPercentages && showLabels ? 46 : 52,
                showPercentage: showPercentages,
                showLabel: showLabels,
                showEstimate: false
            )
        }
    }

    @ViewBuilder
    private func mediumGroupedOverview(_ group: LogicalDevicePresentation) -> some View {
        VStack(spacing: 4) {
            if !singlePresentations.isEmpty {
                HStack(spacing: 14) {
                    ForEach(singlePresentations.prefix(4)) { presentation in
                        if let component = presentation.components.first {
                            OverviewRingCell(
                                item: component.device,
                                diameter: showPercentages && showLabels ? 42 : 48,
                                showPercentage: showPercentages,
                                showLabel: showLabels,
                                showEstimate: showLabels
                            )
                        }
                    }
                }
            }

            Divider()
                .opacity(0.45)
                .padding(.horizontal, 12)

            HStack(spacing: 6) {
                Image(getDeviceIcon(group.representative))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundColor(.secondary)

                Text(group.displayName)
                    .font(.system(size: 9.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 14)

            HStack(spacing: 22) {
                ForEach(group.components.prefix(3)) { component in
                    OverviewRingCell(
                        item: component.device,
                        diameter: showPercentages && showLabels ? 36 : 42,
                        showPercentage: showPercentages,
                        showLabel: showLabels,
                        showEstimate: showLabels
                    )
                }
            }
            .padding(.bottom, showLabels ? 4 : 0)
        }
        .padding(.vertical, 5)
    }

    private var largeOverview: some View {
        let group = groupedPresentations.first
        let singles = Array(singlePresentations.prefix(group == nil ? 8 : 4))
        let rows = (singles.count + 1) / 2

        return VStack(spacing: 13) {
            VStack(spacing: 10) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(rowItems(singles, row: row, columns: 2)) { presentation in
                            LargeLogicalDeviceCell(
                                presentation: presentation,
                                showPercentage: showPercentages,
                                showLabel: showLabels
                            )
                        }
                        if rowItems(singles, row: row, columns: 2).count == 1 {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 62)
                        }
                    }
                }
            }

            if let group {
                Divider().opacity(0.45)

                HStack(spacing: 7) {
                    Image(getDeviceIcon(group.representative))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.secondary)
                    Text(group.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                }

                HStack(spacing: 26) {
                    ForEach(group.components.prefix(3)) { component in
                        OverviewRingCell(
                            item: component.device,
                            diameter: 58,
                            showPercentage: showPercentages,
                            showLabel: showLabels,
                            showEstimate: showLabels
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func flatOverview(columns: Int, diameter: CGFloat) -> some View {
        let rows = flatItems.isEmpty ? 0 : (flatItems.count + columns - 1) / columns
        VStack(spacing: 6) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(rowDeviceItems(row: row, columns: columns), id: \.self) { item in
                        OverviewRingCell(
                            item: item,
                            diameter: diameter,
                            showPercentage: showPercentages,
                            showLabel: showLabels,
                            showEstimate: showLabels
                        )
                    }
                }
            }
        }
    }

    private func rowItems(
        _ values: [LogicalDevicePresentation],
        row: Int,
        columns: Int
    ) -> [LogicalDevicePresentation] {
        let start = row * columns
        guard start < values.count else { return [] }
        let end = min(start + columns, values.count)
        return Array(values[start..<end])
    }

    private func rowDeviceItems(row: Int, columns: Int) -> [Device] {
        let start = row * columns
        guard start < flatItems.count else { return [] }
        let end = min(start + columns, flatItems.count)
        return Array(flatItems[start..<end])
    }
}

private enum CompactCompoundMeterStyle {
    case overviewSmall
    case singleSmall

    var caseDiameter: CGFloat {
        switch self {
        case .overviewSmall: return 24
        case .singleSmall: return 50
        }
    }

    var secondaryDiameter: CGFloat {
        switch self {
        case .overviewSmall: return 20
        case .singleSmall: return 42
        }
    }

    var horizontalSpacing: CGFloat {
        switch self {
        case .overviewSmall: return 5
        case .singleSmall: return 14
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .overviewSmall: return 0
        case .singleSmall: return 2
        }
    }
}

private struct CompactCompoundBatteryMeter: View {
    let presentation: LogicalDevicePresentation
    let style: CompactCompoundMeterStyle
    let showPercentages: Bool
    let showLabel: Bool

    private var caseComponent: BatteryComponentPresentation? {
        presentation.components.first { $0.role == .caseBattery } ??
            presentation.components.first
    }

    private var secondaryComponents: [BatteryComponentPresentation] {
        Array(
            presentation.components
                .filter { component in
                    guard let caseComponent else { return true }
                    return component.id != caseComponent.id
                }
                .prefix(2)
        )
    }

    var body: some View {
        VStack(spacing: style.verticalSpacing) {
            if let caseComponent {
                CompactComponentGauge(
                    component: caseComponent,
                    diameter: style.caseDiameter,
                    showPercentage: showPercentages,
                    showRole: style == .singleSmall
                )
            }

            if !secondaryComponents.isEmpty {
                HStack(spacing: style.horizontalSpacing) {
                    ForEach(secondaryComponents) { component in
                        CompactComponentGauge(
                            component: component,
                            diameter: style.secondaryDiameter,
                            showPercentage: showPercentages,
                            showRole: style == .singleSmall
                        )
                    }
                }
            }

            if showLabel {
                Text(
                    style == .singleSmall
                        ? presentation.displayName
                        : presentation.compactName
                )
                .font(
                    .system(
                        size: style == .singleSmall ? 11 : 7.5,
                        weight: style == .singleSmall ? .medium : .regular
                    )
                )
                .foregroundColor(style == .singleSmall ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: style == .singleSmall ? 150 : 72)
            }

            if style == .singleSmall,
               let caseComponent,
               let estimate = BatteryEstimateFormatting.compact(
                   level: caseComponent.device.batteryLevel,
                   charging: caseComponent.device.isCharging != 0 || caseComponent.device.acPowered,
                   charged: caseComponent.device.isCharged,
                   secondsRemaining: caseComponent.device.estimatedSecondsRemaining,
                   lastUpdate: caseComponent.device.lastUpdate,
                   historyEstimate: BatteryHistorySharedReader.estimate(for: caseComponent.device)
               ) {
                Text(estimate)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(
            width: style == .singleSmall ? 154 : 72,
            height: style == .singleSmall ? 150 : 70,
            alignment: .center
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let batteryValues = presentation.components.map { component in
            "\(component.label) \(component.level) percent"
        }
        return ([presentation.displayName] + batteryValues).joined(separator: ", ")
    }
}

private struct CompactComponentGauge: View {
    let component: BatteryComponentPresentation
    let diameter: CGFloat
    let showPercentage: Bool
    let showRole: Bool

    private var lineWidth: CGFloat {
        diameter >= 40 ? 6 : 3.5
    }

    private var fraction: Double { 0.76 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .opacity(0.15)
                    .rotationEffect(.degrees(133))

                Circle()
                    .trim(
                        from: 0,
                        to: Double(component.level) / 100 * fraction
                    )
                    .stroke(
                        Color(getPowerColor(component.device)),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .rotationEffect(.degrees(133))

                Image(getDeviceIcon(component.device))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: diameter * 0.45, height: diameter * 0.45)
            }
            .frame(width: diameter, height: diameter)

            if showPercentage {
                HStack(spacing: 1) {
                    Text("\(component.level)%")
                        .monospacedDigit()
                    if component.charging != 0 || component.device.acPowered {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: diameter >= 40 ? 6.5 : 4.5, weight: .bold))
                            .foregroundColor(.myGreen)
                    }
                }
                .font(
                    .system(
                        size: diameter >= 40 ? 9.5 : 6.5,
                        weight: .medium
                    )
                )
                .fixedSize()
            }

            if showRole {
                Text(shortRole)
                    .font(.system(size: 7.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var shortRole: String {
        switch component.role {
        case .caseBattery: return "Case"
        case .leftEarbud: return "L"
        case .rightEarbud: return "R"
        case .earbuds: return "L/R"
        case .primary: return component.label
        }
    }
}

private struct LargeLogicalDeviceCell: View {
    let presentation: LogicalDevicePresentation
    let showPercentage: Bool
    let showLabel: Bool

    private var item: Device {
        presentation.components.first?.device ?? presentation.representative
    }

    var body: some View {
        HStack(spacing: 9) {
            OverviewRingCell(
                item: item,
                diameter: 54,
                showPercentage: false,
                showLabel: false,
                showEstimate: false
            )

            VStack(alignment: .leading, spacing: 2) {
                if showLabel {
                    Text(presentation.displayName)
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                if showPercentage {
                    HStack(spacing: 2) {
                        Text("\(item.batteryLevel)%")
                            .monospacedDigit()
                        if item.isCharging != 0 || item.acPowered {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.myGreen)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                }

                if showLabel, let estimate = BatteryEstimateFormatting.compact(
                    level: item.batteryLevel,
                    charging: item.isCharging != 0 || item.acPowered,
                    charged: item.isCharged,
                    secondsRemaining: item.estimatedSecondsRemaining,
                    lastUpdate: item.lastUpdate,
                    historyEstimate: BatteryHistorySharedReader.estimate(for: item)
                ) {
                    Text(estimate)
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
    }
}

private struct OverviewRingCell: View {
    let item: Device
    let diameter: CGFloat
    let showPercentage: Bool
    let showLabel: Bool
    let showEstimate: Bool
    var labelOverride: String? = nil

    private var lineWidth: CGFloat {
        diameter >= 64 ? 7 : (diameter < 42 ? 5 : 6)
    }

    private var ringFraction: Double { 0.78 }

    private var ringRotation: Double { 129.6 }

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
            }
            .frame(width: diameter, height: diameter)

            if showPercentage {
                HStack(spacing: 2) {
                    Text("\(item.batteryLevel)%")
                        .monospacedDigit()
                    if item.isCharging != 0 || item.acPowered {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.myGreen)
                    }
                }
                .font(percentageFont)
                .fixedSize()
            }

            if showLabel {
                Text(labelOverride ?? shortLabel)
                    .font(labelFont)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: diameter + 22)
            }

            if showEstimate, let estimate = compactEstimate {
                Text(estimate)
                    .font(.system(size: diameter >= 54 ? 8.5 : 7.5))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
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

    private var compactEstimate: String? {
        BatteryEstimateFormatting.compact(
            level: item.batteryLevel,
            charging: item.isCharging != 0 || item.acPowered,
            charged: item.isCharged,
            secondsRemaining: item.estimatedSecondsRemaining,
            lastUpdate: item.lastUpdate,
            historyEstimate: BatteryHistorySharedReader.estimate(for: item)
        )
    }

    private var accessibilitySummary: String {
        var values = [labelOverride ?? shortLabel, "\(item.batteryLevel) percent"]
        if item.isCharging != 0 || item.acPowered {
            values.append("charging")
        }
        if let compactEstimate {
            values.append(compactEstimate)
        }
        return values.joined(separator: ", ")
    }
}

struct BatteryRingSurfaceCell: View {
    let item: Device
    let diameter: CGFloat
    let showPercentage: Bool
    let showLabel: Bool
    let estimate: BatteryTimeEstimate?

    var body: some View {
        OverviewRingCell(
            item: item,
            diameter: diameter,
            showPercentage: showPercentage,
            showLabel: showLabel,
            showEstimate: false
        )
    }
}

struct WidgetSingleBatterySurfaceContent: View {
    let item: Device?
    var presentation: LogicalDevicePresentation? = nil
    let deviceName: String
    let warningText: String

    private let lineWidth = 10.0

    private var resolvedPresentation: LogicalDevicePresentation? {
        if let presentation {
            return presentation
        }

        let presentations = AirPodsPresentation.widgetLogicalPresentations(
            from: BatterySnapshotStore.read()
        )

        if let item {
            return presentations.first { presentation in
                presentation.components.contains { component in
                    component.device.deviceID == item.deviceID &&
                        component.device.deviceType == item.deviceType
                }
            }
        }

        guard !deviceName.isEmpty else { return nil }
        return presentations.first { presentation in
            presentation.displayName == deviceName ||
                presentation.components.contains {
                    $0.device.deviceName == deviceName
                }
        }
    }

    var body: some View {
        if let resolvedPresentation,
           resolvedPresentation.components.count > 1 {
            CompactCompoundBatteryMeter(
                presentation: resolvedPresentation,
                style: .singleSmall,
                showPercentages: true,
                showLabel: true
            )
        } else if let item {
            VStack(spacing: 6) {
                ZStack {
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
                                to: Double(item.batteryLevel) / 100 * 0.8
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
                    .frame(width: 110, height: 110)

                    Image(getDeviceIcon(item))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)

                    HStack(spacing: 3) {
                        Text(item.hasBattery ? "\(item.batteryLevel)%" : "")
                            .monospacedDigit()
                        if item.isCharging != 0 || item.acPowered {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.myGreen)
                        }
                    }
                    .font(.system(size: 17))
                    .offset(x: 1, y: 47)
                }

                Text(item.deviceName)
                    .font(.system(size: 12))
                    .frame(width: 144)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let estimate = BatteryEstimateFormatting.compact(
                    level: item.batteryLevel,
                    charging: item.isCharging != 0 || item.acPowered,
                    charged: item.isCharged,
                    secondsRemaining: item.estimatedSecondsRemaining,
                    lastUpdate: item.lastUpdate,
                    historyEstimate: BatteryHistorySharedReader.estimate(for: item)
                ) {
                    Text(estimate)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .offset(y: 2)
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


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
        AirBatteryModel.widgetLogicalPresentations(from: devices)
    }

    private var groupedPresentations: [LogicalDevicePresentation] {
        presentations.filter { $0.components.count > 1 }
    }

    private var singlePresentations: [LogicalDevicePresentation] {
        presentations.filter { $0.components.count == 1 }
    }

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
        return Array(
            presentations
                .flatMap(\.components)
                .map(\.device)
                .prefix(limit)
        )
    }

    private var usesGroupedLayout: Bool {
        family != .small &&
            groupedPresentations.count == 1 &&
            singlePresentations.count <= 4 &&
            groupedPresentations[0].components.count <= 3
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
            if showPercentages && showLabels { return 42 }
            if showPercentages || showLabels { return 48 }
            return 54
        case .large:
            if showPercentages && showLabels { return 58 }
            if showPercentages || showLabels { return 64 }
            return 72
        }
    }

    private var groupedDiameter: CGFloat {
        switch family {
        case .small:
            return diameter
        case .medium:
            return showPercentages && showLabels ? 38 : 44
        case .large:
            return showPercentages && showLabels ? 54 : 62
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

    private var showsEstimates: Bool {
        family != .small && showLabels
    }

    var body: some View {
        Group {
            if items.isEmpty {
                Text("No battery devices")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            } else if usesGroupedLayout, let group = groupedPresentations.first {
                groupedOverview(group)
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
    private func groupedOverview(_ group: LogicalDevicePresentation) -> some View {
        VStack(spacing: family == .large ? 9 : 4) {
            if !singlePresentations.isEmpty {
                HStack(spacing: family == .large ? 18 : 14) {
                    ForEach(singlePresentations.prefix(4)) { presentation in
                        if let component = presentation.components.first {
                            OverviewRingCell(
                                item: component.device,
                                diameter: diameter,
                                showPercentage: showPercentages,
                                showLabel: showLabels,
                                showEstimate: showsEstimates
                            )
                        }
                    }
                }
            }

            Divider()
                .opacity(0.45)
                .padding(.horizontal, family == .large ? 18 : 12)

            HStack(spacing: 6) {
                Image(getDeviceIcon(group.representative))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundColor(.secondary)

                Text(group.displayName)
                    .font(.system(size: family == .large ? 11 : 9.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text("\(group.components.count) components")
                    .font(.system(size: family == .large ? 9 : 8))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, family == .large ? 20 : 14)

            HStack(spacing: family == .large ? 28 : 22) {
                ForEach(group.components.prefix(3)) { component in
                    OverviewRingCell(
                        item: component.device,
                        diameter: groupedDiameter,
                        showPercentage: showPercentages,
                        showLabel: true,
                        showEstimate: showsEstimates
                    )
                }
            }
        }
        .padding(.vertical, family == .large ? 8 : 5)
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
                    showLabel: showLabels,
                    showEstimate: showsEstimates
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
    let showEstimate: Bool

    private var lineWidth: CGFloat {
        diameter >= 64 ? 7 : (diameter < 42 ? 5 : 6)
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
                Text(shortLabel)
                    .font(labelFont)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: diameter + 18)
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
            lastUpdate: item.lastUpdate
        )
    }

    private var accessibilitySummary: String {
        var values = [shortLabel, "\(item.batteryLevel) percent"]
        if item.isCharging != 0 || item.acPowered {
            values.append("charging")
        }
        if let compactEstimate {
            values.append(compactEstimate)
        }
        return values.joined(separator: ", ")
    }
}

// Settings uses the same cohesive ring renderer as widgets. The history-based
// estimate is rendered separately by the settings detail views, so this adapter
// intentionally accepts it only to preserve that call-site API while avoiding a
// second ring implementation.
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
    let deviceName: String
    let warningText: String

    private let lineWidth = 10.0

    var body: some View {
        if let item {
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
                    lastUpdate: item.lastUpdate
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

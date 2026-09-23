import AppKit
import SwiftUI

enum WidgetOverviewFamily {
    case small
    case medium
    case large
}

private enum WidgetEstimateText {
    private static let defaults =
        UserDefaults(suiteName: "group.com.josephcourtney.AirBattery") ?? .standard
    private static let historyKey = "batteryHistory.v1"

    static func compact(for item: Device, now: Date = Date()) -> String? {
        let charging = item.isCharging != 0 || item.acPowered
        if item.isCharged || (charging && item.batteryLevel >= 100) {
            return "Full"
        }

        if item.deviceID != "@MacInternalBattery",
           let estimate = historyEstimate(for: item, now: now) {
            return "\(estimate.kind == .charging ? "Full" : "Empty") " +
                estimate.endDate.formatted(date: .omitted, time: .shortened)
        }

        guard let stored = item.estimatedSecondsRemaining,
              stored.isFinite,
              stored >= 0
        else {
            return nil
        }
        let elapsed = max(0, now.timeIntervalSince1970 - item.lastUpdate)
        let remaining = max(0, stored - elapsed)
        let target = now.addingTimeInterval(remaining).formatted(
            date: .omitted,
            time: .shortened
        )
        return "\(charging ? "Full" : "Empty") \(target)"
    }

    private static func historyEstimate(
        for device: Device,
        now: Date
    ) -> BatteryTimeEstimate? {
        guard let data = defaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode(
                  [String: [BatteryHistorySample]].self,
                  from: data
              )
        else {
            return nil
        }
        let key = DeviceDisplayNameStore.key(
            canonicalID: device.deviceID,
            deviceType: device.deviceType
        )
        return BatteryTimeEstimator.estimate(
            samples: history[key] ?? [],
            now: now
        )
    }
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
            VStack(spacing: 0) {
                OverviewRingCell(
                    item: presentation.representative,
                    diameter: showPercentages && showLabels ? 40 : 46,
                    showPercentage: showPercentages,
                    showLabel: showLabels,
                    showEstimate: false,
                    labelOverride: presentation.compactName
                )
                if showLabels {
                    Text(componentSummary(presentation))
                        .font(.system(size: 6.5, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: 72)
                }
            }
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
                        diameter: showPercentages && showLabels ? 38 : 44,
                        showPercentage: showPercentages,
                        showLabel: showLabels,
                        showEstimate: showLabels
                    )
                }
            }
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

    private func componentSummary(_ presentation: LogicalDevicePresentation) -> String {
        presentation.components.prefix(3).map { component in
            let prefix: String
            switch component.role {
            case .caseBattery: prefix = "C"
            case .leftEarbud: prefix = "L"
            case .rightEarbud: prefix = "R"
            case .earbuds: prefix = "E"
            case .primary: prefix = ""
            }
            return "\(prefix)\(component.level)"
        }.joined(separator: " · ")
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
                        .lineLimit(1)
                        .truncationMode(.tail)
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

                if showLabel, let estimate = WidgetEstimateText.compact(for: item) {
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
        WidgetEstimateText.compact(for: item)
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

                if let estimate = WidgetEstimateText.compact(for: item) {
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

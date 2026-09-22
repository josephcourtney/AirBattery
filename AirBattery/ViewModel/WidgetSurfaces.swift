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
            if showPercentages && showLabels { return 72 }
            if showPercentages || showLabels { return 80 }
            return 90
        }
    }

    private var horizontalSpacing: CGFloat {
        switch family {
        case .small:
            return showPercentages || showLabels ? 18 : 20
        case .medium:
            return showPercentages || showLabels ? 14 : 18
        case .large:
            return showPercentages || showLabels ? 20 : 24
        }
    }

    private var verticalSpacing: CGFloat {
        switch family {
        case .small:
            return showPercentages && showLabels ? 0 : 5
        case .medium:
            return showPercentages && showLabels ? 5 : 9
        case .large:
            return showPercentages && showLabels ? 12 : 18
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
                BatteryRingSurfaceCell(
                    item: items[index],
                    diameter: diameter,
                    showPercentage: showPercentages,
                    showLabel: showLabels
                )
            }
        }
    }
}

struct BatteryRingSurfaceCell: View {
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

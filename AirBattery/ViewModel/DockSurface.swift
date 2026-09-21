import AppKit
import SwiftUI

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


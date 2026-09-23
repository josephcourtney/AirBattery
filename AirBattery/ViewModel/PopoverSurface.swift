import AppKit
import SwiftUI

struct PopoverToolbarSurfaceContent: View {
    var fromDock = false
    var nearcastEnabled = false
    let onHide: () -> Void
    let onAbout: () -> Void
    let onSettings: () -> Void
    let onQuit: () -> Void
    let onRefreshNearcast: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if fromDock {
                PopoverToolbarSurfaceButton(
                    systemName: "minus.circle",
                    help: "Hide".local,
                    hoverColor: .myYellow,
                    action: onHide
                )
            }

            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.myGreen.gradient)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 27, height: 27)

            Text("AirBattery")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            if nearcastEnabled {
                PopoverToolbarSurfaceButton(
                    systemName: "antenna.radiowaves.left.and.right.circle",
                    help: "Refresh Nearcast".local,
                    action: onRefreshNearcast
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
                systemName: "power",
                help: "Quit AirBattery".local,
                hoverColor: .red,
                action: onQuit
            )
        }
        .padding(.top, fromDock ? 8 : 6)
        .padding(.bottom, 5)
        .padding(.horizontal, 11)
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
                .font(.system(size: 14, weight: .regular))
                .frame(width: 27, height: 27)
                .foregroundColor(isHovered ? hoverColor : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
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
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        Color.primary.opacity(
                            colorScheme == .dark ? 0.045 : 0.02
                        )
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

    @State private var isExpanded = false

    var body: some View {
        if presentation.components.count > 1 {
            groupedDeviceContent
        } else if let component = presentation.components.first {
            singleDeviceContent(component.device)
        }
    }

    private var groupedDeviceContent: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 13, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(isExpanded ? "Collapse components" : "Show components")

                Image(getDeviceIcon(presentation.representative))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blackWhite)
                    .frame(width: 22, height: 22)

                Text(
                    stalePrefix +
                        (compactName
                            ? presentation.compactName
                            : presentation.displayName)
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blackWhite)
                .lineLimit(1)

                Spacer(minLength: 5)

                HStack(spacing: 4) {
                    ForEach(presentation.components.prefix(3)) { component in
                        MenuBatteryComponentContent(component: component)
                    }
                }
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.components.enumerated()), id: \.element.id) {
                        index,
                        component in
                        MenuBatteryComponentRow(component: component)
                        if index < presentation.components.count - 1 {
                            Divider()
                                .padding(.leading, 29)
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func singleDeviceContent(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(getDeviceIcon(device))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blackWhite)
                    .frame(width: 22, height: 22, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(stalePrefix + primaryName(for: device))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blackWhite)
                            .lineLimit(1)

                        if alerted {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }

                        if pinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }

                        if device.isCharging != 0 || device.acPowered {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.myGreen)
                        }
                    }

                    if let secondary = secondaryName(for: device) {
                        Text(secondary)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if device.hasBattery && showBatteryTrailing {
                    HStack(spacing: 7) {
                        Text("\(device.batteryLevel)%")
                            .foregroundColor(
                                device.batteryLevel <= 10 ? .darkMyRed : .primary
                            )
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .frame(minWidth: 34, alignment: .trailing)

                        LinearBatterySurface(item: device, width: 88, height: 7)
                    }
                }
            }

            if showBatteryTrailing, let estimate = fullEstimate(for: device) {
                Text(estimate)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .padding(.leading, 30)
            }
        }
    }

    private func primaryName(for device: Device) -> String {
        if device.deviceID == "@MacInternalBattery" {
            return "Mac"
        }
        return compactName ? presentation.compactName : presentation.displayName
    }

    private func secondaryName(for device: Device) -> String? {
        guard device.deviceID == "@MacInternalBattery" else { return nil }
        return device.deviceName == "Mac" ? nil : device.deviceName
    }

    private func fullEstimate(for device: Device) -> String? {
        BatteryEstimateFormatting.full(
            level: device.batteryLevel,
            charging: device.isCharging != 0 || device.acPowered,
            charged: device.isCharged,
            secondsRemaining: device.estimatedSecondsRemaining,
            lastUpdate: device.lastUpdate,
            now: Date(timeIntervalSince1970: now)
        )
    }

    private var stalePrefix: String {
        (now - presentation.newestUpdate) / 60 > 10 ? "⚠︎ " : ""
    }
}

private struct LinearBatterySurface: View {
    let item: Device
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.13))
                Capsule()
                    .fill(Color(getPowerColor(item)))
                    .frame(
                        width: proxy.size.width * CGFloat(
                            min(max(item.batteryLevel, 0), 100)
                        ) / 100
                    )
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

struct MenuBatteryComponentContent: View {
    let component: BatteryComponentPresentation

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(getDeviceIcon(component.device))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blackWhite)
                    .frame(width: 10, height: 10)

                Text("\(component.level)%")
                    .font(.system(size: 9.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(
                        component.level <= 10 ? .darkMyRed : .primary
                    )

                if component.charging != 0 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.myGreen)
                }
            }

            LinearBatterySurface(
                item: component.device,
                width: 42,
                height: 3
            )
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
        .fixedSize()
        .help(component.label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(component.label), \(component.level) percent" +
                (component.charging != 0 ? ", charging" : "")
        )
    }
}

private struct MenuBatteryComponentRow: View {
    let component: BatteryComponentPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Image(getDeviceIcon(component.device))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blackWhite)
                    .frame(width: 17, height: 17)

                Text(component.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                if component.charging != 0 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.myGreen)
                }

                Spacer(minLength: 5)

                Text("\(component.level)%")
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(
                        component.level <= 10 ? .darkMyRed : .primary
                    )
                    .frame(minWidth: 34, alignment: .trailing)

                LinearBatterySurface(
                    item: component.device,
                    width: 84,
                    height: 6
                )
            }

            if let estimate = BatteryEstimateFormatting.full(
                level: component.device.batteryLevel,
                charging: component.device.isCharging != 0 || component.device.acPowered,
                charged: component.device.isCharged,
                secondsRemaining: component.device.estimatedSecondsRemaining,
                lastUpdate: component.device.lastUpdate
            ) {
                Text(estimate)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 5)
    }
}

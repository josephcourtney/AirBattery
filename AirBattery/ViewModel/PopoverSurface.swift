import AppKit
import SwiftUI

struct PopoverToolbarSurfaceContent: View {
    var fromDock = false
    var nearcastEnabled = false
    let onHide: () -> Void
    let onMore: () -> Void
    let onSettings: () -> Void
    let onRefreshNearcast: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            if fromDock {
                PopoverToolbarSurfaceButton(
                    systemName: "minus.circle",
                    help: "Hide".local,
                    hoverColor: .myYellow,
                    action: onHide
                )
            }

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 23, height: 23)
                .clipShape(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                )

            Text("AirBattery")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if nearcastEnabled {
                PopoverToolbarSurfaceButton(
                    systemName:
                        "antenna.radiowaves.left.and.right.circle",
                    help: "Refresh Nearcast".local,
                    action: onRefreshNearcast
                )
            }

            PopoverToolbarSurfaceButton(
                systemName: "gearshape",
                help: "Settings".local,
                action: onSettings
            )

            PopoverToolbarSurfaceButton(
                systemName: "ellipsis.circle",
                help: "More".local,
                action: onMore
            )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }
}

private struct PopoverToolbarSurfaceButton: View {
    let systemName: String
    let help: String
    var hoverColor: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
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
                        isPressed
                            ? hoverColor.opacity(0.18)
                            : (isHovered
                                ? hoverColor.opacity(0.12)
                                : Color.primary.opacity(0.035))
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            Color(nsColor: .separatorColor).opacity(0.35),
                            lineWidth: 0.5
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .accessibilityLabel(Text(help))
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
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
    var estimate: BatteryTimeEstimate?

    init(
        presentation: LogicalDevicePresentation,
        compactName: Bool = false,
        alerted: Bool = false,
        pinned: Bool = false,
        showBatteryTrailing: Bool = true,
        now: Double = Date().timeIntervalSince1970,
        estimate: BatteryTimeEstimate? = nil
    ) {
        self.presentation = presentation
        self.compactName = compactName
        self.alerted = alerted
        self.pinned = pinned
        self.showBatteryTrailing = showBatteryTrailing
        self.now = now
        self.estimate = estimate
    }

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
                Text(stalePrefix + resolvedPresentationName)
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
                Text(stalePrefix + resolvedPresentationName)
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
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 4) {
                        Text("\(device.batteryLevel)%")
                            .foregroundColor(
                                device.batteryLevel <= 10 ? .darkMyRed : .primary
                            )
                            .font(.system(size: 11))
                        SurfaceBatteryGlyph(item: device)
                            .scaleEffect(0.85)
                    }
                    if let estimate {
                        Text(popoverEstimateText(estimate))
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize()
                    }
                }
            }
        }
    }

    private var resolvedPresentationName: String {
        let key = DeviceDisplayNameStore.key(
            canonicalID: presentation.representative.deviceID,
            deviceType: presentation.representative.deviceType
        )
        if let custom = DeviceDisplayNameStore.override(forKey: key) {
            return custom
        }
        return compactName
            ? presentation.compactName
            : presentation.displayName
    }

    private var stalePrefix: String {
        (now - presentation.newestUpdate) / 60 > 10 ? "⚠︎ " : ""
    }
}

struct PopoverCompoundDeviceSurfaceContent: View {
    let presentation: LogicalDevicePresentation
    var compactName = false
    var estimates: [String: BatteryTimeEstimate] = [:]
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Image(getDeviceIcon(presentation.representative))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.blackWhite)
                        .frame(width: 22, height: 22)

                    Text(resolvedPresentationName)
                        .font(.system(size: 12))
                        .foregroundColor(.blackWhite)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let primary = presentation.components.first {
                        VStack(alignment: .trailing, spacing: 0) {
                            HStack(spacing: 4) {
                                Text("\(primary.level)%")
                                    .font(.system(size: 11, weight: .medium))
                                    .monospacedDigit()
                                SurfaceBatteryGlyph(item: primary.device)
                                    .scaleEffect(0.85)
                            }
                            if let estimate = estimates[primary.id] {
                                Text(popoverEstimateText(estimate))
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .fixedSize()
                            }
                        }
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(resolvedPresentationName), " +
                    (isExpanded ? "collapse components" : "expand components")
            )

            if isExpanded {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(presentation.components.prefix(3)) { component in
                        VStack(spacing: 2) {
                            BatteryRingSurfaceCell(
                                item: component.device,
                                diameter: 42,
                                showPercentage: true,
                                showLabel: true
                            )
                            if let estimate = estimates[component.id] {
                                Text(popoverEstimateText(estimate))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .fixedSize()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 7)
            }
        }
    }

    private var resolvedPresentationName: String {
        let key = DeviceDisplayNameStore.key(
            canonicalID: presentation.representative.deviceID,
            deviceType: presentation.representative.deviceType
        )
        if let custom = DeviceDisplayNameStore.override(forKey: key) {
            return custom
        }
        return compactName
            ? presentation.compactName
            : presentation.displayName
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

private func popoverEstimateText(_ estimate: BatteryTimeEstimate) -> String {
    let totalMinutes = max(1, Int((estimate.duration / 60).rounded()))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    let duration: String
    if hours > 0, minutes > 0 {
        duration = "\(hours)h \(minutes)m"
    } else if hours > 0 {
        duration = "\(hours)h"
    } else {
        duration = "\(minutes)m"
    }
    return estimate.kind == .charging
        ? "~\(duration) to full"
        : "~\(duration) left"
}

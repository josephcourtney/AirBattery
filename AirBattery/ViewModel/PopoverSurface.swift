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

            Menu {
                Button("About AirBattery".local, action: onAbout)
                Divider()
                Button("Quit AirBattery".local, action: onQuit)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .regular))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More".local)
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

struct PopoverCompoundDeviceSurfaceContent: View {
    let presentation: LogicalDevicePresentation
    var compactName = false
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

                    Text(
                        compactName
                            ? presentation.compactName
                            : presentation.displayName
                    )
                    .font(.system(size: 12))
                    .foregroundColor(.blackWhite)
                    .lineLimit(1)

                    Spacer(minLength: 4)

                    if let primary = presentation.components.first {
                        Text("\(primary.level)%")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                        SurfaceBatteryGlyph(item: primary.device)
                            .scaleEffect(0.85)
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(presentation.displayName), " +
                    (isExpanded ? "collapse components" : "expand components")
            )

            if isExpanded {
                HStack(spacing: 18) {
                    ForEach(presentation.components.prefix(3)) { component in
                        BatteryRingSurfaceCell(
                            item: component.device,
                            diameter: 42,
                            showPercentage: true,
                            showLabel: true
                        )
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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


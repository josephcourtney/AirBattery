import AppKit
import SwiftUI

struct BlurView: NSViewRepresentable {
    
    private let material: NSVisualEffectView.Material
    
    init(material: NSVisualEffectView.Material) {
        self.material = material
    }
    
    func makeNSView(context: Context) -> some NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.material = material
    }
}

struct PopoverHostSurfaceModifier: ViewModifier {
    let fromDock: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if fromDock {
            content.liquidGlassEffect(
                cornerRadius: 8,
                interactive: true,
                tint: .primary.opacity(0.04)
            )
        } else {
            content
        }
    }
}

enum DeviceActions {
    static func configureBatteryAlert(
        for device: Device,
        onChange: @escaping ([btAlert]) -> Void
    ) {
        let alerts =
            UserDefaults.standard.get(objectType: [btAlert].self, forKey: "alertList") ?? []
        let initial = alerts.first { $0.name == device.deviceName } ??
            btAlert(
                name: device.deviceName,
                full: 80,
                fullOn: true,
                fullSound: true,
                low: 20,
                lowOn: true,
                lowSound: true
            )

        let controller = AlertWindowController()
        controller.showAlert(
            with: initial,
            iconName: getDeviceIcon(device),
            onConfirm: { newAlert in
                var updated =
                    UserDefaults.standard.get(
                        objectType: [btAlert].self,
                        forKey: "alertList"
                    ) ?? []
                updated.removeAll { $0.name == device.deviceName }
                updated.append(newAlert)
                UserDefaults.standard.set(object: updated, forKey: "alertList")
                onChange(updated)
            },
            onCancel: {}
        )
    }

    @MainActor
    static func togglePin(for device: Device) -> [String] {
        var names = AppPreferences.pinnedNames
        if names.contains(device.deviceName) {
            names.removeAll { $0 == device.deviceName }
            AppPreferences.pinnedNames = names
            refeshPinnedBar(unpin: device.deviceName)
        } else {
            names.append(device.deviceName)
            AppPreferences.pinnedNames = names
            refeshPinnedBar()
        }
        return names
    }
}

struct DeviceRowHoverControls: View {
    let infoText: String
    let infoColor: Color
    let device: Device
    let alerted: Bool
    let pinned: Bool
    let canPin: Bool
    let canHide: Bool
    let onAlert: () -> Void
    let onPin: () -> Void
    let onCopy: () -> Void
    let onHide: () -> Void

    init(
        infoText: String,
        infoColor: Color = .secondary,
        device: Device,
        alerted: Bool,
        pinned: Bool,
        canPin: Bool = true,
        canHide: Bool = false,
        onAlert: @escaping () -> Void,
        onPin: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onHide: @escaping () -> Void = {}
    ) {
        self.infoText = infoText
        self.infoColor = infoColor
        self.device = device
        self.alerted = alerted
        self.pinned = pinned
        self.canPin = canPin
        self.canHide = canHide
        self.onAlert = onAlert
        self.onPin = onPin
        self.onCopy = onCopy
        self.onHide = onHide
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(infoText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(infoColor)

            Spacer().frame(width: 1)

            if device.hasBattery {
                DeviceRowActionButton(
                    imageName: alerted
                        ? "bell.circle.fill"
                        : "bell.circle",
                    help: alerted ? "Edit battery alert" : "Add battery alert",
                    action: onAlert
                )

                if canPin {
                    DeviceRowActionButton(
                        imageName: pinned
                            ? "pin.circle.fill"
                            : "pin.circle",
                        help: pinned ? "Unpin from menu bar" : "Pin to menu bar",
                        action: onPin
                    )
                }

                DeviceRowActionButton(
                    imageName: "list.clipboard.fill.circle",
                    help: "Copy device name",
                    action: onCopy
                )

                if canHide {
                    DeviceRowActionButton(
                        imageName: "eye.slash.circle",
                        help: "Hide device",
                        action: onHide
                    )
                }
            }
        }
    }
}

private struct DeviceRowActionButton: View {
    let imageName: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundColor(
                    isHovered ? .accentColor : .secondary
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .onHover { isHovered = $0 }
    }
}


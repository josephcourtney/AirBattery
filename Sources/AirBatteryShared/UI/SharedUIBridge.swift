import SwiftUI

package enum SharedDeviceIconCatalog {
    package static func icon(for device: Device) -> String {
        getDeviceIcon(device)
    }
}

package enum SharedWidgetOverviewFamily {
    case small
    case medium
    case large

    fileprivate var internalFamily: WidgetOverviewFamily {
        switch self {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }
}

package struct SharedWidgetOverviewRingsSurfaceContent: View {
    private let devices: [Device]
    private let family: SharedWidgetOverviewFamily
    private let showPercentages: Bool
    private let showLabels: Bool

    package init(
        devices: [Device],
        family: SharedWidgetOverviewFamily,
        showPercentages: Bool,
        showLabels: Bool
    ) {
        self.devices = devices
        self.family = family
        self.showPercentages = showPercentages
        self.showLabels = showLabels
    }

    package var body: some View {
        WidgetOverviewRingsSurfaceContent(
            devices: devices,
            family: family.internalFamily,
            showPercentages: showPercentages,
            showLabels: showLabels
        )
    }
}

package struct SharedWidgetSingleBatterySurfaceContent: View {
    private let item: Device?
    private let presentation: LogicalDevicePresentation?
    private let deviceName: String
    private let warningText: String

    package init(
        item: Device?,
        presentation: LogicalDevicePresentation? = nil,
        deviceName: String,
        warningText: String
    ) {
        self.item = item
        self.presentation = presentation
        self.deviceName = deviceName
        self.warningText = warningText
    }

    package var body: some View {
        WidgetSingleBatterySurfaceContent(
            item: item,
            presentation: presentation,
            deviceName: deviceName,
            warningText: warningText
        )
    }
}

package struct SharedBatteryRingSurfaceCell: View {
    private let item: Device
    private let diameter: CGFloat
    private let showPercentage: Bool
    private let showLabel: Bool
    private let estimate: BatteryTimeEstimate?

    package init(
        item: Device,
        diameter: CGFloat,
        showPercentage: Bool,
        showLabel: Bool,
        estimate: BatteryTimeEstimate?
    ) {
        self.item = item
        self.diameter = diameter
        self.showPercentage = showPercentage
        self.showLabel = showLabel
        self.estimate = estimate
    }

    package var body: some View {
        BatteryRingSurfaceCell(
            item: item,
            diameter: diameter,
            showPercentage: showPercentage,
            showLabel: showLabel,
            estimate: estimate
        )
    }
}

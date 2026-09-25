import SwiftUI

typealias WidgetOverviewFamily = SharedWidgetOverviewFamily

struct WidgetOverviewRingsSurfaceContent: View {
    let devices: [Device]
    let family: WidgetOverviewFamily
    let showPercentages: Bool
    let showLabels: Bool

    var body: some View {
        SharedWidgetOverviewRingsSurfaceContent(
            devices: devices,
            family: family,
            showPercentages: showPercentages,
            showLabels: showLabels
        )
    }
}

struct WidgetSingleBatterySurfaceContent: View {
    let item: Device?
    var presentation: LogicalDevicePresentation? = nil
    let deviceName: String
    let warningText: String

    var body: some View {
        SharedWidgetSingleBatterySurfaceContent(
            item: item,
            presentation: presentation,
            deviceName: deviceName,
            warningText: warningText
        )
    }
}

struct BatteryRingSurfaceCell: View {
    let item: Device
    let diameter: CGFloat
    let showPercentage: Bool
    let showLabel: Bool
    let estimate: BatteryTimeEstimate?

    var body: some View {
        SharedBatteryRingSurfaceCell(
            item: item,
            diameter: diameter,
            showPercentage: showPercentage,
            showLabel: showLabel,
            estimate: estimate
        )
    }
}

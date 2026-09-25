//
//  DoubleBatteryWidget.swift
//  AirBatteryWidgetExtension
//
//  Created by apple on 2024/2/20.
//

import SwiftUI
import WidgetKit

struct SingleBatteryWidgetEntryView: View {
    let entry: SimpleEntry

    private var item: Device? {
        guard !entry.deviceName.isEmpty else { return nil }
        return entry.data.first { $0.deviceName == entry.deviceName }
    }

    private var presentation: LogicalDevicePresentation? {
        guard !entry.deviceName.isEmpty else { return nil }
        let presentations = AirPodsPresentation.widgetLogicalPresentations(
            from: entry.data
        )

        if let item {
            return presentations.first { presentation in
                presentation.components.contains { component in
                    component.device.deviceID == item.deviceID &&
                        component.device.deviceType == item.deviceType
                }
            }
        }

        return presentations.first { presentation in
            presentation.displayName == entry.deviceName ||
                presentation.components.contains {
                    $0.device.deviceName == entry.deviceName
                }
        }
    }

    var body: some View {
        if !entry.mainApp {
            Text(
                "AirBattery is not running\n" +
                    "Launch the app to make\nthe widget work"
            )
            .multilineTextAlignment(.center)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.gray)
        } else {
            SharedWidgetSingleBatterySurfaceContent(
                item: item,
                presentation: presentation,
                deviceName: entry.deviceName,
                warningText: "Right click to configure".local
            )
        }
    }
}

public struct SingleBatteryWidget: Widget {
    let kind: String = "widget.battery.part3"

    public init() {}

    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SingleBatteryConfigurationIntent.self,
            provider: SingleBatteryTimelineProvider()
        ) { entry in
            SingleBatteryWidgetEntryView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Single Battery")
        .description("Displays one selected device from AirBattery")
        .contentMarginsDisabled()
        .supportedFamilies([.systemSmall])
    }
}

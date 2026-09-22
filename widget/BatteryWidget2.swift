//
//  DoubleBatteryWidget.swift
//  AirBatteryWidgetExtension
//
//  Created by apple on 2024/2/20.
//

import WidgetKit
import SwiftUI

struct SingleBatteryWidgetEntryView: View {
    let entry: SimpleEntry

    private var item: Device? {
        guard !entry.deviceName.isEmpty else { return nil }
        return entry.data.first { $0.deviceName == entry.deviceName }
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
            WidgetSingleBatterySurfaceContent(
                item: item,
                deviceName: entry.deviceName,
                warningText: "Right click to configure".local
            )
        }
    }
}

struct SingleBatteryWidget: Widget {
    let kind: String = "widget.battery.part3"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SingleBatteryConfigurationIntent.self,
            provider: SingleBatteryTimelineProvider()
        ) { entry in
            SingleBatteryWidgetEntryView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "airbattery://settings"))
        }
        .configurationDisplayName("Single Battery")
        .description("Displays one selected device from AirBattery")
        .contentMarginsDisabled()
        .supportedFamilies([.systemSmall])
    }
}

//
//  BatteryWidget3.swift
//  AirBattery
//
//  Created by apple on 2024/6/8.
//

import WidgetKit
import SwiftUI

struct batteryWidgetEntryView3 : View {
    var entry: ViewSizeTimelineProvider.Entry
    
    var body: some View {
        VStack {
            switch entry.family {
            case .systemSmall:
                SmallWidgetView2(entry: entry)
            case .systemMedium:
                doubleBatteryWidgetEntryView2(entry: entry)
            case .systemLarge:
                EmptyView()
            case .systemExtraLarge:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }.widgetURL(URL(string: "airbattery://reloadwingets"))
    }
}

struct SmallWidgetView2: View {
    var entry: ViewSizeTimelineProvider.Entry

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
            WidgetIconRingsSurfaceContent(
                devices: entry.data,
                family: .small
            )
        }
    }
}

struct doubleBatteryWidgetEntryView2: View {
    var entry: ViewSizeTimelineProvider.Entry

    var body: some View {
        if !entry.mainApp {
            Text(
                "AirBattery is not running\n" +
                    "Launch the app to make the widget work"
            )
            .multilineTextAlignment(.center)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.gray)
        } else {
            WidgetIconRingsSurfaceContent(
                devices: entry.data,
                family: .medium
            )
        }
    }
}

struct batteryWidget3: Widget {
    let kind: String = "widget.battery.part4"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ViewSizeTimelineProvider()) { entry in
            batteryWidgetEntryView3(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .liquidGlassWidgetBackground()
        }
        .configurationDisplayName("Battery Rings — Icons (Legacy)")
        .description("Legacy icon-rings widget. Use Battery Overview for new widgets.")
        .disableContentMarginsIfNeeded()
        .supportedFamilies([.systemMedium, .systemSmall])
    }
}

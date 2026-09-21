//
//  DoubleBatteryWidget.swift
//  AirBatteryWidgetExtension
//
//  Created by apple on 2024/2/20.
//

import WidgetKit
import SwiftUI

struct LargeWidgetView2: View {
    var entry: ViewSizeTimelineProvider.Entry

    private var presentations: [LogicalDevicePresentation] {
        Array(AirBatteryModel.widgetLogicalPresentations(from: entry.data).prefix(11))
    }

    var body: some View {
        if !entry.mainApp {
            Text("AirBattery is not running\nLaunch the app to make the widget work")
                .multilineTextAlignment(.center)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.gray)
        } else if presentations.isEmpty {
            VStack(alignment: .leading) {
                ForEach(0..<11) { index in
                    VStack {
                        HStack {
                            Image("blank")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text("                       ")
                                .font(.system(size: 11))
                                .frame(height: 20)
                                .padding(.horizontal, 7)
                            Spacer()
                        }
                        if index != 10 {
                            Divider().padding(.top, -2)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(presentations.indices, id: \.self) { index in
                    let presentation = presentations[index]
                    WidgetLogicalDeviceRow(
                        presentation: presentation,
                        rowHeight: 20
                    )
                    if index != presentations.count - 1 {
                        Divider().padding(.top, -2)
                    }
                }
                Spacer()
            }
            .offset(y: 4)
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
        }
    }
}

struct doubleRowBatteryWidgetEntryView: View {
    var entry: ViewSizeTimelineProvider.Entry

    private var items: [Device] {
        Array(entry.data.filter(\.hasBattery).prefix(8))
    }

    var body: some View {
        if !entry.mainApp {
            Text(
                "AirBattery is not running\n" +
                    "Launch the app to make the widget work"
            )
            .multilineTextAlignment(.center)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.gray)
        } else if items.isEmpty {
            Text("No battery data")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        } else {
            WidgetBatteryRingsSurfaceContent(devices: items)
        }
    }
}

struct singleBatteryWidgetEntryView: View {
    var entry: ViewSizeTimelineProvider.Entry
    var item: Device?
    var deviceName: String
    var warringText: String

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
                deviceName: deviceName,
                warningText: warringText
            )
        }
    }
}

struct batteryWidgetEntryView2: View {
    var entry: ViewSizeTimelineProvider.Entry
    
    var body: some View {
        VStack {
            switch entry.family {
            case .systemSmall:
                if #available(macOS 14, *) {
                    let item = entry.deviceName != "" ? entry.data.first(where: { $0.deviceName == entry.deviceName }) : nil
                    singleBatteryWidgetEntryView(entry: entry, item: item, deviceName: entry.deviceName, warringText: "Right click to configure".local)
                } else {
                    let deviceName = AirBatteryModel.singleDeviceName()
                    let item = deviceName != "" ? entry.data.first(where: { $0.deviceName == deviceName }) : nil
                    singleBatteryWidgetEntryView(entry: entry, item: item, deviceName: deviceName, warringText: "Select a Device in Preferences".local)
                }
            case .systemMedium:
                doubleRowBatteryWidgetEntryView(entry: entry)
            case .systemLarge:
                LargeWidgetView2(entry: entry)
            case .systemExtraLarge:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }.widgetURL(URL(string: "airbattery://reloadwingets"))
    }
}

@available(macOS 14, *)
struct batteryWidget2New: Widget {
    let kind: String = "widget.battery.part3"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: ViewSizeTimelineProviderNew()) { entry in
            batteryWidgetEntryView2(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .liquidGlassWidgetBackground()
        }
        .configurationDisplayName("Single Battery")
        .description("Displays one selected device from AirBattery")
        .disableContentMarginsIfNeeded()
        .supportedFamilies([.systemSmall])
    }
}

struct batteryWidget2: Widget {
    let kind: String = "widget.battery.part2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ViewSizeTimelineProvider()) { entry in
            batteryWidgetEntryView2(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .liquidGlassWidgetBackground()
        }
        .configurationDisplayName("Battery Rings")
        .description("Displays up to eight labeled device batteries")
        .disableContentMarginsIfNeeded()
        .supportFamily()
    }
}

//
//  widget.swift
//  widget
//
//  Created by apple on 2024/2/18.
//

import SwiftUI
import WidgetKit

struct SingleBatteryTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            data: [],
            mainApp: true,
            deviceName: ""
        )
    }

    func snapshot(
        for configuration: SingleBatteryConfigurationIntent,
        in context: Context
    ) async -> SimpleEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(
        for configuration: SingleBatteryConfigurationIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {
        Timeline(
            entries: [makeEntry(configuration: configuration)],
            policy: .atEnd
        )
    }

    private func makeEntry(
        configuration: SingleBatteryConfigurationIntent
    ) -> SimpleEntry {
        let mainApp = BatterySnapshotStore.isFresh()

        var data = BatterySnapshotStore.read()
        for file in getFiles(withExtension: "json", in: BatterySnapshotStore.nearcastDirectory) {
            data += BatterySnapshotStore.nearcastDevicesForWidget(at: file)
        }
        data = AirPodsPresentation.widgetPresentationOrder(from: data)

        return SimpleEntry(
            date: Date(),
            data: data,
            mainApp: mainApp,
            deviceName: configuration.deviceName
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: [Device]
    let mainApp: Bool
    let deviceName: String
}

struct BatteryOverviewEntry: TimelineEntry {
    let date: Date
    let data: [Device]
    let family: WidgetFamily
    let mainApp: Bool
    let showPercentages: Bool
    let showLabels: Bool
}

private enum BatteryOverviewPreviewData {
    static func devices(at date: Date) -> [Device] {
        let timestamp = date.timeIntervalSince1970
        return AirPodsPresentation.widgetPresentationOrder(from: [
            Device(
                deviceID: "preview-airpods-case",
                deviceType: "ap_case",
                deviceName: "AirPods Pro (Case)",
                deviceModel: "Airpods Pro 2",
                batteryLevel: 64,
                isCharging: 0,
                parentName: "AirPods Pro",
                lastUpdate: timestamp
            ),
            Device(
                deviceID: "preview-airpods-left",
                deviceType: "ap_pod_left",
                deviceName: "AirPods Pro Left",
                deviceModel: "Airpods Pro 2",
                batteryLevel: 88,
                isCharging: 0,
                parentName: "AirPods Pro",
                lastUpdate: timestamp
            ),
            Device(
                deviceID: "preview-airpods-right",
                deviceType: "ap_pod_right",
                deviceName: "AirPods Pro Right",
                deviceModel: "Airpods Pro 2",
                batteryLevel: 82,
                isCharging: 1,
                parentName: "AirPods Pro",
                lastUpdate: timestamp
            ),
            Device(
                deviceID: "preview-mac",
                deviceType: "macbookpro",
                deviceName: "MacBook Pro",
                batteryLevel: 76,
                isCharging: 1,
                lastUpdate: timestamp
            ),
            Device(
                deviceID: "preview-iphone",
                deviceType: "iPhone",
                deviceName: "iPhone",
                batteryLevel: 42,
                isCharging: 0,
                lastUpdate: timestamp
            ),
            Device(
                deviceID: "preview-watch",
                deviceType: "Watch",
                deviceName: "Apple Watch",
                batteryLevel: 68,
                isCharging: 0,
                lastUpdate: timestamp
            ),
            Device(
                deviceID: "preview-mouse",
                deviceType: "MMouse",
                deviceName: "Magic Mouse",
                batteryLevel: 91,
                isCharging: 0,
                lastUpdate: timestamp
            ),
        ])
    }
}

struct BatteryOverviewTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BatteryOverviewEntry {
        makePreviewEntry(
            family: context.family,
            showPercentages: true,
            showLabels: true
        )
    }

    func snapshot(
        for configuration: BatteryOverviewConfigurationIntent,
        in context: Context
    ) async -> BatteryOverviewEntry {
        if context.isPreview {
            return makePreviewEntry(
                family: context.family,
                showPercentages: configuration.showPercentages,
                showLabels: configuration.showLabels
            )
        }
        return makeEntry(configuration: configuration, family: context.family)
    }

    func timeline(
        for configuration: BatteryOverviewConfigurationIntent,
        in context: Context
    ) async -> Timeline<BatteryOverviewEntry> {
        Timeline(
            entries: [
                makeEntry(
                    configuration: configuration,
                    family: context.family
                )
            ],
            policy: .atEnd
        )
    }

    private func makePreviewEntry(
        family: WidgetFamily,
        showPercentages: Bool,
        showLabels: Bool
    ) -> BatteryOverviewEntry {
        let date = Date()
        return BatteryOverviewEntry(
            date: date,
            data: BatteryOverviewPreviewData.devices(at: date),
            family: family,
            mainApp: true,
            showPercentages: showPercentages,
            showLabels: showLabels
        )
    }

    private func makeEntry(
        configuration: BatteryOverviewConfigurationIntent,
        family: WidgetFamily
    ) -> BatteryOverviewEntry {
        let mainApp = BatterySnapshotStore.isFresh()

        var data = BatterySnapshotStore.read()
        for file in getFiles(withExtension: "json", in: BatterySnapshotStore.nearcastDirectory) {
            data += BatterySnapshotStore.nearcastDevicesForWidget(at: file)
        }

        data = AirPodsPresentation.widgetPresentationOrder(from: data)

        return BatteryOverviewEntry(
            date: Date(),
            data: data,
            family: family,
            mainApp: mainApp,
            showPercentages: configuration.showPercentages,
            showLabels: configuration.showLabels
        )
    }
}

struct BatteryOverviewEntryView: View {
    let entry: BatteryOverviewEntry

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
            SharedWidgetOverviewRingsSurfaceContent(
                devices: entry.data,
                family: overviewFamily,
                showPercentages: entry.showPercentages,
                showLabels: entry.showLabels
            )
            .widgetURL(URL(string: "airbattery://reloadwingets"))
        }
    }

    private var overviewFamily: SharedWidgetOverviewFamily {
        switch entry.family {
        case .systemSmall:
            return .small
        case .systemMedium:
            return .medium
        default:
            return .large
        }
    }
}

public struct BatteryOverviewWidget: Widget {
    let kind = "widget.battery.overview"

    public init() {}

    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BatteryOverviewConfigurationIntent.self,
            provider: BatteryOverviewTimelineProvider()
        ) { entry in
            BatteryOverviewEntryView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Battery Overview")
        .description(
            "Displays device battery rings with optional percentages and labels."
        )
        .contentMarginsDisabled()
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

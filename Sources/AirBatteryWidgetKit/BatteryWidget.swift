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

        func device(
            _ id: String,
            _ type: String,
            _ name: String,
            model: String? = nil,
            level: Int,
            charging: Int = 0,
            parent: String = ""
        ) -> Device {
            Device(
                deviceID: id,
                deviceType: type,
                deviceName: name,
                deviceModel: model,
                batteryLevel: level,
                isCharging: charging,
                parentName: parent,
                lastUpdate: timestamp
            )
        }

        return AirPodsPresentation.widgetPresentationOrder(from: [
            device(
                "preview-airpods-case", "ap_case", "AirPods Pro (Case)",
                model: "Airpods Pro 2", level: 64, parent: "AirPods Pro"
            ),
            device(
                "preview-airpods-left", "ap_pod_left", "AirPods Pro Left",
                model: "Airpods Pro 2", level: 88, parent: "AirPods Pro"
            ),
            device(
                "preview-airpods-right", "ap_pod_right", "AirPods Pro Right",
                model: "Airpods Pro 2", level: 82, charging: 1, parent: "AirPods Pro"
            ),
            device("preview-mac", "macbookpro", "MacBook Pro", level: 76, charging: 1),
            device("preview-iphone", "iPhone", "iPhone", level: 42),
            device("preview-watch", "Watch", "Apple Watch", level: 68),
            device("preview-mouse", "MMouse", "Magic Mouse", level: 91),
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
        let entry: BatteryOverviewEntry
        if context.isPreview {
            entry = makePreviewEntry(
                family: context.family,
                showPercentages: configuration.showPercentages,
                showLabels: configuration.showLabels
            )
        } else {
            entry = makeEntry(
                configuration: configuration,
                family: context.family
            )
        }

        return Timeline(entries: [entry], policy: .atEnd)
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

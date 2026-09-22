//
//  widget.swift
//  widget
//
//  Created by apple on 2024/2/18.
//

import WidgetKit
import SwiftUI

let ncFolder = AirBatteryModel.getNearcastURL()

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
        let mainApp = AirBatteryModel.snapshotIsFresh()

        var data = AirBatteryModel.readData()
        for file in getFiles(withExtension: "json", in: ncFolder) {
            data += AirBatteryModel.ncGetAll(url: file, fromWidget: true)
        }
        data = AirBatteryModel.widgetPresentationOrder(from: data)

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

struct BatteryOverviewTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BatteryOverviewEntry {
        BatteryOverviewEntry(
            date: Date(),
            data: [],
            family: context.family,
            mainApp: true,
            showPercentages: true,
            showLabels: true
        )
    }

    func snapshot(
        for configuration: BatteryOverviewConfigurationIntent,
        in context: Context
    ) async -> BatteryOverviewEntry {
        makeEntry(configuration: configuration, family: context.family)
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

    private func makeEntry(
        configuration: BatteryOverviewConfigurationIntent,
        family: WidgetFamily
    ) -> BatteryOverviewEntry {
        let mainApp = AirBatteryModel.snapshotIsFresh()

        var data = AirBatteryModel.readData()
        for file in getFiles(withExtension: "json", in: ncFolder) {
            data += AirBatteryModel.ncGetAll(
                url: file,
                fromWidget: true
            )
        }

        data = AirBatteryModel.widgetPresentationOrder(from: data)

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
            WidgetOverviewRingsSurfaceContent(
                devices: entry.data,
                family: overviewFamily,
                showPercentages: entry.showPercentages,
                showLabels: entry.showLabels
            )
        }
    }

    private var overviewFamily: WidgetOverviewFamily {
        switch entry.family {
        case .systemSmall:
            return .small
        default:
            return .medium
        }
    }
}

struct BatteryOverviewWidget: Widget {
    let kind = "widget.battery.overview"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BatteryOverviewConfigurationIntent.self,
            provider: BatteryOverviewTimelineProvider()
        ) { entry in
            BatteryOverviewEntryView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "airbattery://settings"))
        }
        .configurationDisplayName("Battery Overview")
        .description(
            "Displays device battery rings with optional percentages and labels."
        )
        .contentMarginsDisabled()
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

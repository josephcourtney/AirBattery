//
//  widget.swift
//  widget
//
//  Created by apple on 2024/2/18.
//

import WidgetKit
import SwiftUI

let fd = FileManager.default
let ud = UserDefaults.standard
let ncFolder = fd.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("NearcastData")

@available(macOS 14, *)
struct ViewSizeTimelineProviderNew: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: [],family: context.family, mainApp: true, deviceName: "")
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        var mainApp = false
        let apps = NSWorkspace.shared.runningApplications
        for app in apps as [NSRunningApplication] { if app.bundleIdentifier == "com.josephcourtney.AirBattery" { mainApp = true } }
        var data = AirBatteryModel.readData()
        let ncFiles = getFiles(withExtension: "json", in: ncFolder)
        for ncFile in ncFiles {
            let ncData = AirBatteryModel.ncGetAll(url: ncFile, fromWidget: true)
            data += ncData
        }
        data = AirBatteryModel.widgetPresentationOrder(from: data)
        if context.family == .systemSmall || context.family == .systemMedium {
            while data.count < 8 { data.append(Device(hasBattery: false, deviceID: "", deviceType: "blank", deviceName: "", batteryLevel: 0, isCharging: 0, lastUpdate: 0.0)) }
        } else if context.family ==  .systemLarge {
            if data.count >= 11 { data = Array(data[0..<11]) }
        }
        return SimpleEntry(date: Date(), data: data, family: context.family, mainApp: mainApp, deviceName: configuration.deviceName)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var mainApp = false
        let apps = NSWorkspace.shared.runningApplications
        for app in apps as [NSRunningApplication] { if app.bundleIdentifier == "com.josephcourtney.AirBattery" { mainApp = true } }
        var data = AirBatteryModel.readData()
        let ncFiles = getFiles(withExtension: "json", in: ncFolder)
        for ncFile in ncFiles {
            let ncData = AirBatteryModel.ncGetAll(url: ncFile, fromWidget: true)
            data += ncData
        }
        let entry: SimpleEntry
        data = AirBatteryModel.widgetPresentationOrder(from: data)
        if context.family == .systemSmall || context.family == .systemMedium {
            while data.count < 8 { data.append(Device(hasBattery: false, deviceID: "", deviceType: "blank", deviceName: "", batteryLevel: 0, isCharging: 0, lastUpdate: 0.0)) }
        } else if context.family ==  .systemLarge {
            if data.count >= 11 { data = Array(data[0..<11]) }
        }
        entry = SimpleEntry(date: Date(), data: data, family: context.family, mainApp: mainApp, deviceName: configuration.deviceName)
        let entries: [SimpleEntry] = [entry]
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct ViewSizeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: [],family: context.family, mainApp: true, deviceName: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        var mainApp = false
        let apps = NSWorkspace.shared.runningApplications
        for app in apps as [NSRunningApplication] { if app.bundleIdentifier == "com.josephcourtney.AirBattery" { mainApp = true } }
        var data = AirBatteryModel.readData()
        let ncFiles = getFiles(withExtension: "json", in: ncFolder)
        for ncFile in ncFiles {
            let ncData = AirBatteryModel.ncGetAll(url: ncFile, fromWidget: true)
            data += ncData
        }
        let entry: SimpleEntry
        data = AirBatteryModel.widgetPresentationOrder(from: data)
        if context.family == .systemSmall || context.family == .systemMedium {
            while data.count < 8 { data.append(Device(hasBattery: false, deviceID: "", deviceType: "blank", deviceName: "", batteryLevel: 0, isCharging: 0, lastUpdate: 0.0)) }
        } else if context.family ==  .systemLarge {
            if data.count >= 11 { data = Array(data[0..<11]) }
        }
        entry = SimpleEntry(date: Date(), data: data, family: context.family, mainApp: mainApp, deviceName: "")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        var mainApp = false
        let apps = NSWorkspace.shared.runningApplications
        for app in apps as [NSRunningApplication] { if app.bundleIdentifier == "com.josephcourtney.AirBattery" { mainApp = true } }
        var data = AirBatteryModel.readData()
        let ncFiles = getFiles(withExtension: "json", in: ncFolder)
        for ncFile in ncFiles {
            let ncData = AirBatteryModel.ncGetAll(url: ncFile, fromWidget: true)
            data += ncData
        }
        let entry: SimpleEntry
        data = AirBatteryModel.widgetPresentationOrder(from: data)
        if context.family == .systemSmall || context.family == .systemMedium {
            while data.count < 8 { data.append(Device(hasBattery: false, deviceID: "", deviceType: "blank", deviceName: "", batteryLevel: 0, isCharging: 0, lastUpdate: 0.0)) }
        } else if context.family ==  .systemLarge {
            if data.count >= 11 { data = Array(data[0..<11]) }
        }
        entry = SimpleEntry(date: Date(), data: data, family: context.family, mainApp: mainApp, deviceName: "")
        let entries: [SimpleEntry] = [entry]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: [Device]
    let family: WidgetFamily
    let mainApp: Bool
    let deviceName: String
    //let configuration: Any?
}

@available(macOS 14.0, *)
struct BatteryOverviewEntry: TimelineEntry {
    let date: Date
    let data: [Device]
    let family: WidgetFamily
    let mainApp: Bool
    let showPercentages: Bool
    let showLabels: Bool
}

@available(macOS 14.0, *)
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
        let mainApp = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.josephcourtney.AirBattery"
        }

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

@available(macOS 14.0, *)
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
            .widgetURL(URL(string: "airbattery://reloadwingets"))
        }
    }

    private var overviewFamily: WidgetOverviewFamily {
        switch entry.family {
        case .systemSmall:
            return .small
        case .systemMedium:
            return .medium
        case .systemLarge:
            return .large
        case .systemExtraLarge:
            return .large
        @unknown default:
            return .medium
        }
    }
}

@available(macOS 14.0, *)
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
                .liquidGlassWidgetBackground()
        }
        .configurationDisplayName("Battery Overview")
        .description(
            "Displays device battery rings with optional percentages and labels."
        )
        .disableContentMarginsIfNeeded()
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

struct batteryWidgetEntryView : View {
    var entry: ViewSizeTimelineProvider.Entry
    
    var body: some View {
        VStack {
            switch entry.family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            case .systemExtraLarge:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }.widgetURL(URL(string: "airbattery://reloadwingets"))
    }
}

struct LargeWidgetView : View {
    var entry: ViewSizeTimelineProvider.Entry

    private var presentations: [LogicalDevicePresentation] {
        Array(AirBatteryModel.widgetLogicalPresentations(from: entry.data).prefix(8))
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
        } else if presentations.isEmpty {
            VStack(alignment: .leading) {
                ForEach(0..<8) { index in
                    VStack {
                        HStack {
                            Image("blank")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                            Text("                       ")
                                .font(.system(size: 11))
                                .frame(height: 31)
                                .padding(.horizontal, 7)
                            Spacer()
                        }
                        if index != 7 {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
        } else {
            WidgetListSurfaceContent(
                presentations: presentations,
                rowHeight: 31
            )
        }
    }
}

struct SmallWidgetView: View {
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
            WidgetBatteryListRingsSurfaceContent(
                devices: entry.data,
                family: .small
            )
        }
    }
}

struct MediumWidgetView: View {
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
            WidgetBatteryListRingsSurfaceContent(
                devices: entry.data,
                family: .medium
            )
        }
    }
}

struct batteryWidget: Widget {
    let kind: String = "widget.battery"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ViewSizeTimelineProvider()) { entry in
            batteryWidgetEntryView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .liquidGlassWidgetBackground()
        }
        .configurationDisplayName("Battery List (Legacy)")
        .description("Legacy multi-device widget. Use Battery Overview for new widgets.")
        .disableContentMarginsIfNeeded()
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

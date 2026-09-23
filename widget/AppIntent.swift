//
//  AppIntent.swift
//  AirBattery
//
//  Created by apple on 2024/6/6.
//

import AppIntents
import WidgetKit

struct SingleBatteryConfigurationIntent: WidgetConfigurationIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Configuration"
    nonisolated(unsafe) static var description = IntentDescription(
        "AirBattery battery usage widget"
    )

    @Parameter(title: LocalizedStringResource("Enter Device Name"), default: "")
    var deviceName: String

    @Parameter(
        title: LocalizedStringResource("Show Time Estimate"),
        default: false
    )
    var showTimeEstimate: Bool

    init(deviceName: String, showTimeEstimate: Bool = false) {
        self.deviceName = deviceName
        self.showTimeEstimate = showTimeEstimate
    }

    init() {
        self.deviceName = ""
        self.showTimeEstimate = false
    }
}

struct BatteryOverviewConfigurationIntent: WidgetConfigurationIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource =
        "Battery Overview"
    nonisolated(unsafe) static var description = IntentDescription(
        "Choose whether the widget shows percentages, device labels, and battery time estimates."
    )

    @Parameter(
        title: LocalizedStringResource("Show Percentages"),
        default: true
    )
    var showPercentages: Bool

    @Parameter(
        title: LocalizedStringResource("Show Labels"),
        default: true
    )
    var showLabels: Bool

    @Parameter(
        title: LocalizedStringResource("Show Time Estimates"),
        default: false
    )
    var showTimeEstimates: Bool

    init(
        showPercentages: Bool,
        showLabels: Bool,
        showTimeEstimates: Bool = false
    ) {
        self.showPercentages = showPercentages
        self.showLabels = showLabels
        self.showTimeEstimates = showTimeEstimates
    }

    init() {
        self.showPercentages = true
        self.showLabels = true
        self.showTimeEstimates = false
    }
}

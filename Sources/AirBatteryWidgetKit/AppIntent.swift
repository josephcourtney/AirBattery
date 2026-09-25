//
//  AppIntent.swift
//  AirBattery
//
//  Created by apple on 2024/6/6.
//

import WidgetKit
import AppIntents

struct SingleBatteryConfigurationIntent: WidgetConfigurationIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Configuration"
    nonisolated(unsafe) static var description = IntentDescription("AirBattery battery usage widget")
    
    @Parameter(title: LocalizedStringResource("Enter Device Name"), default: "")
    var deviceName: String
    
    init(deviceName: String) {
        self.deviceName = deviceName
    }
    
    init() {
        self.deviceName = ""
    }
}


struct BatteryOverviewConfigurationIntent: WidgetConfigurationIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource =
        "Battery Overview"
    nonisolated(unsafe) static var description = IntentDescription(
        "Choose whether the widget shows percentages and device labels."
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

    init(showPercentages: Bool, showLabels: Bool) {
        self.showPercentages = showPercentages
        self.showLabels = showLabels
    }

    init() {
        self.showPercentages = true
        self.showLabels = true
    }
}


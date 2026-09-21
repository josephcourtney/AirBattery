//
//  widgetBundle.swift
//  widget
//
//  Created by apple on 2024/2/18.
//

import WidgetKit

@main
struct widgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryOverviewWidget()
        SingleBatteryWidget()
    }
}

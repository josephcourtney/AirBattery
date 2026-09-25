//
//  widgetBundle.swift
//  widget
//
//  Created by apple on 2024/2/18.
//

import AirBatteryWidgetKit
import SwiftUI
import WidgetKit

@main
struct widgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryOverviewWidget()
        SingleBatteryWidget()
    }
}

//
//  BatteryView.swift
//  AirBattery
//
//  Created by apple on 2024/2/23.
//

import SwiftUI

struct BatteryView: View {
    var item: Device

    var body: some View {
        SurfaceBatteryGlyph(item: item)
    }
}

struct mainBatteryView: View {
    @State var item: iBattery = InternalBattery.status
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("intBattOnStatusBar") var intBattOnStatusBar = true
    @AppStorage("colorfulBattery") var colorfulBattery = false
    @AppStorage("iosBatteryStyle") var iosBatteryStyle = false
    @AppStorage("batteryPercent") var batteryPercent = "outside"
    @AppStorage("internalLevel") var internalLevel = false
    @AppStorage("hideLevel") var hideLevel = 90
    
    @AppStorage("test_debug") var test_debug = false
    @AppStorage("test_hasib") var test_hasib = false
    @AppStorage("test_acpower") var test_ac = false
    @AppStorage("test_full") var test_full = false
    @AppStorage("test_iblevel") var test_iblevel = 100
    
    @State var factor = 0.0

    private var menuBarSummary: String {
        guard item.hasBattery && intBattOnStatusBar else {
            return "AirBattery — open battery overview"
        }
        var parts = ["AirBattery — This Mac \(item.batteryLevel) percent"]
        if item.lowPower {
            parts.append("Low Power Mode")
        }
        if item.isCharging {
            parts.append("charging")
        } else if item.isCharged {
            parts.append("fully charged")
        }
        return parts.joined(separator: ", ")
    }
    
    var body: some View {
        StatusBarBatteryContent(
            item: item,
            showMacBattery: intBattOnStatusBar,
            colorfulBattery: colorfulBattery,
            iosBatteryStyle: iosBatteryStyle,
            batteryPercent: batteryPercent,
            hideLevel: hideLevel
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(menuBarSummary))
        .help(menuBarSummary)
        .onReceive(dockTimer) { t in refeshPinnedBar() }
        .onReceive(mainTimer) { t in
            if item.hasBattery {
                InternalBattery.status = getPowerState()
                let width = statusBarItem.button?.frame.size.width
                if intBattOnStatusBar {
                    if test_debug {
                        InternalBattery.status = iBattery(hasBattery: test_hasib, isCharging: !test_full, isCharged: false, acPowered: test_ac, timeLeft: "", batteryLevel: test_iblevel)
                    } else {
                        InternalBattery.status = getPowerState()
                    }
                    item = InternalBattery.status
                    statusBarItem.button?.toolTip = menuBarSummary
                    if batteryPercent != "outside" {
                        if width != 42 { setStatusBar(width: 42) }
                    } else {
                        if item.batteryLevel > hideLevel {
                            if width != 42 { setStatusBar(width: 42) }
                        } else {
                            if width != 76 { setStatusBar(width: 76) }
                        }
                    }
                } else {
                    if width != 36 { setStatusBar(width: 36) }
                }
            } else {
                if test_debug {
                    let width = statusBarItem.button?.frame.size.width
                    if width != 36 { setStatusBar(width: 36) }
                    InternalBattery.status = iBattery(hasBattery: test_hasib, isCharging: !test_full, isCharged: false, acPowered: test_ac, timeLeft: "", batteryLevel: test_iblevel)
                    item = InternalBattery.status
                }
            }
        }
    }
}

struct BatteryLevelView: View {
    var item: iBattery

    var body: some View {
        StatusBarBatteryLevelContent(item: item)
    }
}

func setStatusBar(width: Double) {
    let iconView = NSHostingView(rootView: mainBatteryView())
    iconView.frame = NSRect(x: 0, y: 0, width: width, height: 21.5)
    statusBarItem.button?.subviews.removeAll()
    statusBarItem.button?.addSubview(iconView)
    statusBarItem.button?.frame = iconView.frame
}

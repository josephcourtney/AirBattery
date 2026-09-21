//
//  BatteryView.swift
//  AirBattery
//
//  Created by apple on 2024/2/23.
//

import AppKit
import SwiftUI

final class StatusItemHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

struct BatteryView: View {
    var item: Device

    var body: some View {
        SurfaceBatteryGlyph(item: item)
    }
}

struct mainBatteryView: View {
    @State var item: iBattery = InternalBattery.status
    @AppStorage("intBattOnStatusBar") var intBattOnStatusBar = true
    @AppStorage("colorfulBattery") var colorfulBattery = false
    @AppStorage("iosBatteryStyle") var iosBatteryStyle = false
    @AppStorage("batteryPercent") var batteryPercent = "outside"
    @AppStorage("hideLevel") var hideLevel = 90
    
    @AppStorage("test_debug") var test_debug = false
    @AppStorage("test_hasib") var test_hasib = false
    @AppStorage("test_acpower") var test_ac = false
    @AppStorage("test_full") var test_full = false
    @AppStorage("test_iblevel") var test_iblevel = 100
    
    @ObservedObject private var monitoring = MonitoringCoordinator.shared


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
        .onReceive(monitoring.$secondTick) { _ in
            if test_debug {
                InternalBattery.status = iBattery(
                    hasBattery: test_hasib,
                    isCharging: !test_full,
                    isCharged: false,
                    acPowered: test_ac,
                    timeLeft: "",
                    batteryLevel: test_iblevel
                )
            }

            item = InternalBattery.status
            StatusBarController.shared.statusItem.button?.toolTip = menuBarSummary

            guard item.hasBattery && intBattOnStatusBar else {
                if StatusBarController.shared.statusItem.length != 36 {
                    setStatusBar(width: 36)
                }
                return
            }

            let targetWidth: Double
            if batteryPercent != "outside" || item.batteryLevel > hideLevel {
                targetWidth = 42
            } else {
                targetWidth = 76
            }
            if StatusBarController.shared.statusItem.length != CGFloat(targetWidth) {
                setStatusBar(width: targetWidth)
            }
        }
    }
}

func setStatusBar(width: Double) {
    StatusBarController.shared.setLength(CGFloat(width))
}

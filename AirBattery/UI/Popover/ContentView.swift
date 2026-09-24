//
//  ContentView.swift
//  AirBattery
//
//  Created by apple on 2023/9/4.
//
import AppKit
import SwiftUI

struct MultiBatteryView: View {
    @AppStorage("showThisMac") var showThisMac = "icon"
    @AppStorage("carouselMode") var carouselMode = true
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("showOn") var showOn = "sbar"
    @AppStorage("twsMergeEnabled") private var twsMergeEnabled = true
    @AppStorage("twsMerge") private var twsMerge = 5

    @Environment(\.colorScheme) private var systemColorScheme
    @ObservedObject private var monitoring = AppEnvironment.shared.monitoring

    @State private var rollCount = 1
    @State private var lastTime = Double(Date().timeIntervalSince1970)
    @State private var presentationList: [LogicalDevicePresentation] = []

    var body: some View {
        DockTileSurfaceContent(
            presentations: presentationList,
            darkMode: darkMode,
            showMacAsPercent: showThisMac == "percent"
        )
        .onAppear {
            refreshDockPresentations(now: Date().timeIntervalSince1970)
        }
        .onChange(of: systemColorScheme) { _, _ in
            NSApp.dockTile.display()
        }
        .onChange(of: appearance) { _, _ in
            NSApp.dockTile.display()
        }
        .onChange(of: twsMergeEnabled) { _, _ in
            refreshDockPresentations(now: Date().timeIntervalSince1970)
        }
        .onChange(of: twsMerge) { _, _ in
            refreshDockPresentations(now: Date().timeIntervalSince1970)
        }
        .onReceive(monitoring.$fiveSecondTick) { time in
            guard showOn == "both" || showOn == "dock" else { return }
            refreshDockPresentations(now: time.timeIntervalSince1970)
            NSApp.dockTile.display()
        }
    }

    private var darkMode: Bool {
        switch appearance {
        case "true":
            return true
        case "false":
            return false
        default:
            return systemColorScheme == .dark
        }
    }

    private func refreshDockPresentations(now: Double) {
        var devices = DeviceStore.shared.getAll()
        for url in getFiles(withExtension: "json", in: BatterySnapshotStore.nearcastDirectory) {
            devices += BatterySnapshotStore.nearcastDevices(at: url)
        }

        let internalStatus = InternalBattery.status
        if internalStatus.hasBattery && showThisMac != "hidden" {
            devices.insert(ib2ab(internalStatus), at: 0)
        }

        let logical = AirPodsPresentation.logicalPresentations(
            from: devices,
            mergeEarbuds: twsMergeEnabled,
            mergeThreshold: twsMerge
        )

        if !carouselMode {
            rollCount = 1
        }

        var page = logicalPage(logical, page: rollCount)
        if page.isEmpty && !logical.isEmpty {
            rollCount = 1
            page = logicalPage(logical, page: rollCount)
        }
        presentationList = page

        if now - lastTime >= 20 && logical.count > 4 && carouselMode {
            lastTime = now
            rollCount += 1
        }
    }

    private func logicalPage(
        _ devices: [LogicalDevicePresentation],
        page: Int
    ) -> [LogicalDevicePresentation] {
        let start = max(0, (page - 1) * 4)
        guard start < devices.count else { return [] }
        return Array(devices[start..<min(start + 4, devices.count)])
    }


}



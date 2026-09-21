//
//  SettingsView.swift
//  AirBattery
//
//  Created by apple on 2023/9/7.
//

import SwiftUI
import WidgetKit
import AppKit

enum SettingsSection: String, Hashable {
    case general
    case display
    case devices
    case discovery
    case nearcast
    case debug

    var title: LocalizedStringKey {
        switch self {
        case .general: return "General"
        case .display: return "Display"
        case .devices: return "Devices"
        case .discovery: return "Discovery"
        case .nearcast: return "Nearcast"
        case .debug: return "Debug"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .display: return "rectangle.3.group"
        case .devices: return "rectangle.stack"
        case .discovery: return "antenna.radiowaves.left.and.right"
        case .nearcast: return "network"
        case .debug: return "ladybug"
        }
    }
}

struct SettingsView: View {
    @State private var selectedItem: SettingsSection? = .general
    @AppStorage("showDebug") var showDebug: Bool = false
    @ObservedObject private var discoveryPolicy = BLEDiscoveryPolicyStore.shared

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: 170,
                    ideal: 190,
                    max: 220
                )
        } detail: {
            detailView
                .id(selectedItem)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 760,
            idealWidth: 960,
            maxWidth: .infinity,
            minHeight: 540,
            idealHeight: 720,
            maxHeight: .infinity
        )
        .onChange(of: showDebug) { _, enabled in
            if !enabled && selectedItem == .debug {
                selectedItem = .general
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selectedItem) {
            settingsSidebarRow(.general)
            settingsSidebarRow(.display)
            settingsSidebarRow(
                .devices,
                badge: discoveryPolicy.reviewCount
            )
            settingsSidebarRow(.discovery)
            settingsSidebarRow(.nearcast)
            if showDebug {
                settingsSidebarRow(.debug)
            }
        }
        .listStyle(.sidebar)
        .accessibilityLabel("Settings sections")
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .display:
            DisplayView()
        case .devices:
            DevicesView()
        case .discovery:
            DiscoveryView()
        case .nearcast:
            NearcastView()
        case .debug:
            if showDebug {
                DebugView(selectedItem: $selectedItem)
            } else {
                GeneralView()
            }
        case .general, .none:
            GeneralView()
        }
    }

    @ViewBuilder
    private func settingsSidebarRow(
        _ section: SettingsSection,
        badge: Int = 0
    ) -> some View {
        HStack(spacing: 8) {
            Label(section.title, systemImage: section.systemImage)
            Spacer()
            if badge > 0 {
                Text("\(badge)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.18))
                    )
                    .accessibilityLabel("\(badge) devices need review")
            }
        }
        .tag(section)
    }

}


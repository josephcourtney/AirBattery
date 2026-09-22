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
        .background(SettingsWindowLifecycleObserver())
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

private struct SettingsWindowLifecycleObserver: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsWindowLifecycleView {
        SettingsWindowLifecycleView()
    }

    func updateNSView(
        _ nsView: SettingsWindowLifecycleView,
        context: Context
    ) {}
}

@MainActor
private final class SettingsWindowLifecycleView: NSView {
    private weak var observedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard observedWindow !== window else { return }

        let hadWindow = observedWindow != nil
        if let observedWindow {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.willCloseNotification,
                object: observedWindow
            )
        }

        observedWindow = window
        guard let window else {
            if hadWindow {
                syncActivation(settingsVisible: false)
            }
            return
        }

        configure(window)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
        syncActivation(settingsVisible: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func windowWillClose(_ notification: Notification) {
        syncActivation(settingsVisible: false)
    }

    private func configure(_ window: NSWindow) {
        window.title = "AirBattery Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert([.resizable, .fullSizeContentView])
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.titlebarSeparatorStyle = .automatic
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("AirBatterySettingsWindow")
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }

    private func syncActivation(settingsVisible: Bool) {
        SurfaceController.shared.syncActivation(
            surfaceSelection: AppPreferences.showOn,
            settingsVisible: settingsVisible
        )
    }
}

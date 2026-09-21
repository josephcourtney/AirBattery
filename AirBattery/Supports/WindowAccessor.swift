//
//  WindowAccessor.swift
//  xHistory
//
//  Created by apple on 2024/11/7.
//

import AppKit
import SwiftUI

@MainActor
final class SurfaceController {
    static let shared = SurfaceController()

    private init() {}

    func apply(
        _ surfaceSelection: String,
        settingsVisible: Bool
    ) {
        let showsMenuBar =
            surfaceSelection == "sbar" || surfaceSelection == "both"

        StatusBarController.shared.setMenuBarVisible(showsMenuBar)
        syncActivation(
            surfaceSelection: surfaceSelection,
            settingsVisible: settingsVisible
        )
    }

    func syncActivation(
        surfaceSelection: String,
        settingsVisible: Bool
    ) {
        let policy: NSApplication.ActivationPolicy
        if settingsVisible {
            policy = .regular
        } else {
            policy =
                surfaceSelection == "dock" || surfaceSelection == "both"
                    ? .regular
                    : .accessory
        }

        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AirBattery Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.contentViewController = hostingController
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.titlebarSeparatorStyle = .automatic
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("AirBatterySettingsWindow")

        super.init(window: window)
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        SurfaceController.shared.syncActivation(
            surfaceSelection:
                UserDefaults.standard.string(forKey: "showOn") ?? "sbar",
            settingsVisible: false
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }

        // Reassert these constraints when reopening in case SwiftUI/AppKit
        // changed them while the content hierarchy was being constructed.
        window.styleMask.insert([.resizable, .fullSizeContentView])
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        SurfaceController.shared.syncActivation(
            surfaceSelection:
                UserDefaults.standard.string(forKey: "showOn") ?? "sbar",
            settingsVisible: true
        )
        NSApp.activate()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)

    }
}


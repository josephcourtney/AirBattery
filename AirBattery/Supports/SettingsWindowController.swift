import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AirBattery Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.contentViewController = hostingController
        window.contentMinSize = NSSize(width: 900, height: 540)
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.contentResizeIncrements = NSSize(width: 1, height: 1)
        window.titlebarSeparatorStyle = .automatic
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("AirBatterySettingsWindow")
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }

        SurfaceController.shared.syncActivation(
            surfaceSelection: AppPreferences.showOn,
            settingsVisible: true
        )
        NSApp.activate()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        SurfaceController.shared.syncActivation(
            surfaceSelection: AppPreferences.showOn,
            settingsVisible: false
        )
    }
}

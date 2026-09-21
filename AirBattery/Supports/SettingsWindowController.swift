import AppKit
import SwiftUI

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
            surfaceSelection: AppPreferences.showOn,
            settingsVisible: false
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }

        window.styleMask.insert([.resizable, .fullSizeContentView])
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        SurfaceController.shared.syncActivation(
            surfaceSelection: AppPreferences.showOn,
            settingsVisible: true
        )
        NSApp.activate()
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}

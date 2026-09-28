import AppKit
import SwiftUI

@MainActor
package enum AirBatterySettingsWindowConfiguration {
    package static let initialContentSize = NSSize(width: 960, height: 680)

    package static func apply(to window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "AirBattery Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.contentMinSize = NSSize(width: 900, height: 540)
        window.contentMaxSize = NSSize(width: 1_180, height: 900)
        window.contentResizeIncrements = NSSize(width: 1, height: 1)
        window.titlebarSeparatorStyle = .automatic
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        // Installing an NSHostingController can resize its containing NSWindow
        // to SwiftUI's fitting size. Reassert the declared initial content size
        // after the content controller has been installed so a fresh settings
        // window opens at the intended 960x680 rather than an incidental fitting
        // size. Frame autosave, when enabled, is applied afterward and may still
        // restore a user-resized production window.
        window.setContentSize(initialContentSize)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init(
        initialSection: SettingsSection = .general,
        usesFrameAutosave: Bool = true
    ) {
        let hostingController = NSHostingController(
            rootView: SettingsView(initialSelection: initialSection)
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AirBatterySettingsWindowConfiguration.initialContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        AirBatterySettingsWindowConfiguration.apply(to: window)
        if usesFrameAutosave {
            window.setFrameAutosaveName("AirBatterySettingsWindow")
        }

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func developmentFixture(section: SettingsSection) -> SettingsWindowController {
        let controller = SettingsWindowController(initialSection: section, usesFrameAutosave: false)
        // Hrost's native-window host centers deterministic fixture windows.
        // Use the same canonical screen position here so translucent titlebar
        // and sidebar materials sample the same desktop backdrop on both hosts.
        controller.window?.center()
        return controller
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

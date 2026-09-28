import AppKit

@MainActor
public func runAirBatteryApplication() {
    AppDelegate.main()
}

/// Development-only package seam for launching the real AirBattery AppKit host
/// without starting live monitoring services. The normal production entry point
/// remains `runAirBatteryApplication()`.
@MainActor
package func runAirBatteryDisplaySettingsProductionFixture(
    onReady: @escaping @MainActor (NSWindow) -> Void
) {
    AppDelegate.fixtureMain(onReady: onReady)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator: ApplicationCoordinator?
    private let fixtureReady: (@MainActor (NSWindow) -> Void)?
    private var fixtureSettingsController: SettingsWindowController?

    init(environment: AppEnvironment) {
        coordinator = ApplicationCoordinator(environment: environment)
        fixtureReady = nil
        super.init()
    }

    private init(fixtureReady: @escaping @MainActor (NSWindow) -> Void) {
        coordinator = nil
        self.fixtureReady = fixtureReady
        super.init()
    }

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate(environment: .shared)
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    fileprivate static func fixtureMain(
        onReady: @escaping @MainActor (NSWindow) -> Void
    ) {
        let application = NSApplication.shared
        let delegate = AppDelegate(fixtureReady: onReady)
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        coordinator?.handleReopen() ?? false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        coordinator?.applicationWillFinishLaunching()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let fixtureReady {
            let controller = SettingsWindowController.developmentFixture(section: .display)
            fixtureSettingsController = controller
            controller.present()
            guard let window = controller.window else {
                NSApp.terminate(nil)
                return
            }
            // Let AppKit finish key-window ordering before the development
            // capture callback starts querying WindowServer.
            Task { @MainActor in
                await Task.yield()
                fixtureReady(window)
            }
            return
        }

        coordinator?.applicationDidFinishLaunching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.applicationWillTerminate()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        coordinator?.applicationDockMenu()
    }

    func presentSettings() {
        SettingsWindowController.shared.present()
    }

    @objc func confirmQuit() {
        let response = createAlert(
            level: .warning,
            title: "Quit AirBattery?",
            message:
                "AirBattery will stop monitoring device batteries until you launch it again.",
            button1: "Quit",
            button2: "Cancel"
        ).runModal()
        if response == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}

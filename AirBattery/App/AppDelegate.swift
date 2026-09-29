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

/// Development-only package seam for observing the Display settings surface
/// after the normal production coordinator and live monitoring graph have
/// started. Unlike the deterministic fixture path, this does not reset defaults,
/// suppress services, or substitute fixture state.
@MainActor
package func runAirBatteryDisplaySettingsLiveObservation(
    onReady: @escaping @MainActor (NSWindow) -> Void
) {
    AppDelegate.liveObservationMain(onReady: onReady)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator: ApplicationCoordinator?
    private let fixtureReady: (@MainActor (NSWindow) -> Void)?
    private let liveReady: (@MainActor (NSWindow) -> Void)?
    private var fixtureSettingsController: SettingsWindowController?
    private var liveSettingsController: SettingsWindowController?

    init(environment: AppEnvironment) {
        coordinator = ApplicationCoordinator(environment: environment)
        fixtureReady = nil
        liveReady = nil
        super.init()
    }

    private init(fixtureReady: @escaping @MainActor (NSWindow) -> Void) {
        coordinator = nil
        self.fixtureReady = fixtureReady
        liveReady = nil
        super.init()
    }

    private init(liveReady: @escaping @MainActor (NSWindow) -> Void) {
        coordinator = ApplicationCoordinator(environment: .shared)
        fixtureReady = nil
        self.liveReady = liveReady
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

    fileprivate static func liveObservationMain(
        onReady: @escaping @MainActor (NSWindow) -> Void
    ) {
        let application = NSApplication.shared
        let delegate = AppDelegate(liveReady: onReady)
        application.delegate = delegate
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

        if let liveReady {
            let controller = SettingsWindowController.liveObservation(section: .display)
            liveSettingsController = controller
            controller.present()
            guard let window = controller.window else {
                NSApp.terminate(nil)
                return
            }
            // The coordinator is fully live at this point. Yield once so the
            // settings selection and native window ordering settle before state
            // is sampled and WindowServer evidence is collected.
            Task { @MainActor in
                await Task.yield()
                liveReady(window)
            }
        }
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

import AppKit

@MainActor
public func runAirBatteryApplication() {
    AppDelegate.main()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator: ApplicationCoordinator

    init(environment: AppEnvironment) {
        coordinator = ApplicationCoordinator(environment: environment)
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

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        coordinator.handleReopen()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        coordinator.applicationWillFinishLaunching()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.applicationDidFinishLaunching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.applicationWillTerminate()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        coordinator.applicationDockMenu()
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

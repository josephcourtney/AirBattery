import AppKit
import Darwin
import Foundation

@MainActor
public func runAirBatteryApplication() {
    let environment = ProcessInfo.processInfo.environment
    guard let mode = environment["AIRBATTERY_HROST_XCUITEST"] else {
        AppDelegate.main()
        return
    }

    guard mode == "1" else {
        failHrostXCUITestLaunch("AIRBATTERY_HROST_XCUITEST must be '1' when present")
    }

    do {
        try configureHrostXCUITestFixture(environment: environment)
        AppDelegate.fixtureMain { _ in }
    } catch {
        failHrostXCUITestLaunch(error.localizedDescription)
    }
}

private struct HrostXCUITestLaunchError: LocalizedError {
    let detail: String
    var errorDescription: String? { detail }
}

@MainActor
private func configureHrostXCUITestFixture(environment: [String: String]) throws {
    let scenario = environment["AIRBATTERY_HROST_SCENARIO"] ?? ""
    let supportedScenarios: Set<String> = [
        "empty",
        "single-device",
        "airpods",
        "charging",
        "many-devices",
        "long-names",
        "no-battery",
    ]
    guard supportedScenarios.contains(scenario) else {
        throw HrostXCUITestLaunchError(
            detail: "AIRBATTERY_HROST_SCENARIO must name a deterministic fixture scenario"
        )
    }

    let appearance = environment["AIRBATTERY_HROST_APPEARANCE"] ?? ""
    switch appearance {
    case "system":
        NSApplication.shared.appearance = nil
    case "light":
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    case "dark":
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    default:
        throw HrostXCUITestLaunchError(
            detail: "AIRBATTERY_HROST_APPEARANCE must be system, light, or dark"
        )
    }

    let defaults = UserDefaults.standard
    defaults.set(false, forKey: "nearCast")
    defaults.set(true, forKey: "twsMergeEnabled")
    defaults.set(5, forKey: "twsMerge")
    defaults.set("both", forKey: "showOn")
    defaults.set("auto", forKey: "appearance")
    defaults.set("icon", forKey: "showThisMac")
    defaults.set(true, forKey: "carouselMode")
    defaults.set(true, forKey: "intBattOnStatusBar")
    defaults.set(true, forKey: "colorfulBattery")
    defaults.set(false, forKey: "iosBatteryStyle")
    defaults.set("outside", forKey: "batteryPercent")
    defaults.set(90, forKey: "hideLevel")
    defaults.set(false, forKey: "showDebug")
    defaults.removeObject(forKey: "bleDevicePolicyRules")
    defaults.removeObject(forKey: "bleLogicalDevicePolicyRulesV1")
    defaults.set(false, forKey: "readBLEDevice")
    defaults.set(false, forKey: "ideviceOverBLE")
    defaults.set("review", forKey: "bleDiscoveryMode")
}

private func failHrostXCUITestLaunch(_ detail: String) -> Never {
    FileHandle.standardError.write(
        Data("AirBattery: invalid Hrost XCUITest launch: \(detail)\n".utf8)
    )
    Darwin.exit(64)
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

        // Mark this development-only lifecycle so the synchronous Bluetooth
        // system_profiler prefetch can be omitted without changing production
        // startup. The real monitor services themselves still start normally.
        setenv("AIRBATTERY_HROST_LIVE_OBSERVATION", "1", 1)

        // The development harness is wrapped in a minimal SwiftPM-generated app
        // bundle rather than launched through AirBattery's Xcode target. Make the
        // GUI lifecycle explicit instead of depending on inferred activation
        // policy from that wrapper. SurfaceController may still adjust activation
        // later according to the live user's normal AirBattery preferences.
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

        if let liveReady {
            // Run the real post-launch surface/status setup, but suppress
            // first-launch tip dialogs that would block unattended evidence
            // collection. Monitoring and external services were already started
            // by applicationWillFinishLaunching above.
            coordinator?.applicationDidFinishLaunching(showLaunchTips: false)

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

import AirBatteryKit
import AppKit
import Darwin
import Foundation
import Hrost

private struct CaptureOptions {
    let surfaceID: String
    let scenarioID: String
    let variantID: String
    let appearance: HrostAppearance
    let output: URL
    let recordPresentationState: Bool
}

private struct CLIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@main
struct AirBatteryProductionHrost {
    @MainActor
    static func main() {
        do {
            let options = try parse(arguments: Array(CommandLine.arguments.dropFirst()))
            configureFixtureDefaults()
            applyAppearance(options.appearance)

            runAirBatteryDisplaySettingsProductionFixture { window in
                Task { @MainActor in
                    do {
                        let presentationState = try options.recordPresentationState
                            ? recordedPresentationState(scenarioID: options.scenarioID)
                            : nil
                        let identity = HrostCaptureIdentity(
                            applicationName: "AirBattery",
                            surfaceID: options.surfaceID,
                            surfaceTitle: "Display Settings",
                            surfaceKind: "window",
                            scenarioID: options.scenarioID,
                            scenarioTitle: try scenarioTitle(options.scenarioID),
                            variantID: options.variantID,
                            variantTitle: options.variantID == "default" ? "Default" : options.variantID,
                            environment: HrostEnvironment(appearance: options.appearance),
                            presentationState: presentationState
                        )
                        let bundle = try await HrostProductionCapture.window(
                            window,
                            identity: identity,
                            destination: options.output
                        )
                        print(bundle.url.path)
                        NSApplication.shared.terminate(nil)
                    } catch {
                        writeError("AirBatteryProductionHrost: capture failed: \(error.localizedDescription)\n")
                        Darwin.exit(2)
                    }
                }
            }
        } catch {
            writeError("AirBatteryProductionHrost: \(error.localizedDescription)\n")
            Darwin.exit(2)
        }
    }

    private static func parse(arguments: [String]) throws -> CaptureOptions {
        guard arguments.first == "capture" else {
            throw CLIError(message: "expected 'capture' command")
        }

        var surfaceID: String?
        var scenarioID: String?
        var variantID = "default"
        var appearance: HrostAppearance = .system
        var output: String?
        var recordPresentationState = false
        var index = 1

        func value(after option: String) throws -> String {
            guard index + 1 < arguments.count else {
                throw CLIError(message: "missing value for '\(option)'")
            }
            return arguments[index + 1]
        }

        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--surface":
                surfaceID = try value(after: option)
                index += 2
            case "--scenario":
                scenarioID = try value(after: option)
                index += 2
            case "--variant":
                variantID = try value(after: option)
                index += 2
            case "--appearance":
                let raw = try value(after: option)
                guard let parsed = HrostAppearance(rawValue: raw) else {
                    throw CLIError(message: "unknown appearance '\(raw)'")
                }
                appearance = parsed
                index += 2
            case "--output":
                output = try value(after: option)
                index += 2
            case "--record-state":
                recordPresentationState = true
                index += 1
            default:
                throw CLIError(message: "unknown capture option '\(option)'")
            }
        }

        guard surfaceID == "display-settings" else {
            throw CLIError(message: "only the 'display-settings' production fixture is implemented")
        }
        guard let scenarioID else {
            throw CLIError(message: "capture requires --scenario ID")
        }
        _ = try scenarioTitle(scenarioID)
        guard variantID == "default" else {
            throw CLIError(message: "display-settings supports only the default variant")
        }
        guard let output else {
            throw CLIError(message: "capture requires --output PATH")
        }

        let base = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let destination = URL(
            fileURLWithPath: output,
            relativeTo: base
        ).standardizedFileURL

        return CaptureOptions(
            surfaceID: "display-settings",
            scenarioID: scenarioID,
            variantID: variantID,
            appearance: appearance,
            output: destination,
            recordPresentationState: recordPresentationState
        )
    }

    @MainActor
    private static func recordedPresentationState(
        scenarioID: String
    ) throws -> HrostPresentationState {
        let snapshot = AirBatterySettingsPresentationSnapshot.capture(
            scenarioID: scenarioID
        )
        return HrostPresentationState(
            id: try snapshot.stableID(),
            origin: .fixture,
            schemaIdentifier: AirBatterySettingsPresentationSnapshot.schemaIdentifier,
            schemaVersion: AirBatterySettingsPresentationSnapshot.schemaVersion,
            mediaType: "application/json",
            payload: try snapshot.encoded()
        )
    }

    private static func scenarioTitle(_ id: String) throws -> String {
        switch id {
        case "empty": "Empty"
        case "single-device": "Single Device"
        case "airpods": "AirPods"
        case "charging": "Charging"
        case "many-devices": "Many Devices"
        case "long-names": "Long Names"
        case "no-battery": "No Battery Data"
        default: throw CLIError(message: "unknown AirBattery fixture scenario '\(id)'")
        }
    }

    @MainActor
    private static func applyAppearance(_ appearance: HrostAppearance) {
        let application = NSApplication.shared
        switch appearance {
        case .system:
            application.appearance = nil
        case .light:
            application.appearance = NSAppearance(named: .aqua)
        case .dark:
            application.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private static func configureFixtureDefaults() {
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

        // The settings sidebar displays a badge derived from discovery policy.
        // Clear persisted test-account policy state so reference captures do not
        // depend on previous Screen Sharing sessions or hardware observations.
        defaults.removeObject(forKey: "bleDevicePolicyRules")
        defaults.removeObject(forKey: "bleLogicalDevicePolicyRulesV1")
        defaults.set(false, forKey: "readBLEDevice")
        defaults.set(false, forKey: "ideviceOverBLE")
        defaults.set("review", forKey: "bleDiscoveryMode")
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}

import Darwin
import Foundation
import HrostXCUITest
import XCTest

@MainActor
final class AirBatteryHrostUITests: XCTestCase {
    func testDisplaySettingsCheckpoint() async throws {
        print("AIRBATTERY_HROST_XCUITEST phase=load-environment")
        let environment = try stagedHrostEnvironment()
        let expectedUIDText = try XCTUnwrap(
            environment["HROST_EXPECTED_GUI_UID"],
            "staged Hrost environment is missing HROST_EXPECTED_GUI_UID"
        )
        let expectedUID = try XCTUnwrap(
            uid_t(expectedUIDText),
            "staged HROST_EXPECTED_GUI_UID is not numeric"
        )

        let session = try HrostXCUITestSession.fromEnvironment(environment)
        XCTAssertEqual(
            getuid(),
            expectedUID,
            "XCUITest runner is not executing as the controlled GUI-session user"
        )

        let app = XCUIApplication()
        app.launchEnvironment["AIRBATTERY_HROST_XCUITEST"] = "1"
        app.launchEnvironment["AIRBATTERY_HROST_SCENARIO"] = "airpods"
        app.launchEnvironment["AIRBATTERY_HROST_APPEARANCE"] = "light"

        print("AIRBATTERY_HROST_XCUITEST phase=launch-aut")
        app.launch()
        defer { app.terminate() }

        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 10),
            "AirBattery deterministic settings window did not become visible to XCUITest"
        )
        print("AIRBATTERY_HROST_XCUITEST phase=checkpoint-start")

        // Bundle identifier + window kind are intentionally sufficient for the
        // first real-host vertical slice. Richer XCUI hints remain optional and
        // are not needed to establish the workflow/relay/broker boundary.
        let disposition = try await session.checkpoint(
            surfaceID: "display-settings",
            scenarioID: "airpods",
            appearance: .light,
            bundleIdentifier: "com.josephcourtney.AirBattery",
            element: nil,
            kind: .window
        )
        print(
            "AIRBATTERY_HROST_XCUITEST phase=checkpoint-finished disposition=\(String(describing: disposition))"
        )
        XCTAssertEqual(disposition, .captured)

        try session.finish()
        print("AIRBATTERY_HROST_XCUITEST phase=result-finished")
    }

    private func stagedHrostEnvironment() throws -> [String: String] {
        let configurationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(".hrost-environment", isDirectory: false)
        let contents = try String(contentsOf: configurationURL, encoding: .utf8)
        var environment: [String: String] = [:]
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            guard let separator = rawLine.firstIndex(of: "=") else { continue }
            let key = String(rawLine[..<separator])
            let value = String(rawLine[rawLine.index(after: separator)...])
            environment[key] = value
        }
        return environment
    }
}

@testable import AirBatteryKit

import Foundation
import XCTest

final class BluetoothHIDLogParserTests: XCTestCase {
    func testParsesValidEntriesAndSkipsMalformedLines() {
        let output = """
        {"mac":"AA:BB:CC:DD:EE:FF","name":"Keyboard","type":"Keyboard","time":"2026-09-24T20:00:00.000-04:00","level":72,"status":"+"}
        not-json
        {"mac":"11:22:33:44:55:66","name":"","type":"Mouse","time":"2026-09-24T20:00:01.000-04:00","level":41,"status":"-"}
        """

        let entries = BluetoothHIDLogParser.entries(from: output)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].name, "Keyboard")
        XCTAssertEqual(entries[0].level, 72)
        XCTAssertEqual(entries[0].status, "+")
        XCTAssertEqual(entries[1].mac, "11:22:33:44:55:66")
        XCTAssertEqual(entries[1].type, "Mouse")
    }

    func testLatestEntriesKeepsLastObservationPerIdentity() {
        let output = """
        {"mac":"AA:BB:CC:DD:EE:FF","name":"Keyboard","type":"Keyboard","time":"2026-09-24T20:00:00.000-04:00","level":70,"status":"-"}
        {"mac":"AA:BB:CC:DD:EE:FF","name":"Keyboard","type":"Keyboard","time":"2026-09-24T20:01:00.000-04:00","level":69,"status":"-"}
        {"mac":"11:22:33:44:55:66","name":"Mouse","type":"Mouse","time":"2026-09-24T20:01:00.000-04:00","level":41,"status":"+"}
        """

        let entries = BluetoothHIDLogParser.latestEntries(from: output)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(byName["Keyboard"]?.level, 69)
        XCTAssertEqual(byName["Mouse"]?.level, 41)
    }
}

final class ProcessRunnerTests: XCTestCase {
    func testCapturesOutputAndExitStatus() throws {
        let result = try XCTUnwrap(
            ProcessRunner.run(
                path: "/usr/bin/printf",
                arguments: ["hello"]
            )
        )

        XCTAssertEqual(result.output, "hello")
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.terminationReason, .exit)
    }

    func testChildEnvironmentCanBeSpecifiedWithoutMutatingParent() throws {
        let variable = "AIRBATTERY_PROCESS_RUNNER_TEST"
        let originalValue = ProcessInfo.processInfo.environment[variable]

        var environment = ProcessInfo.processInfo.environment
        environment[variable] = "child-only"
        let result = try XCTUnwrap(
            ProcessRunner.run(
                path: "/usr/bin/env",
                arguments: [],
                environment: environment
            )
        )

        XCTAssertTrue(
            result.output.split(separator: "\n").contains(
                Substring("\(variable)=child-only")
            )
        )
        XCTAssertEqual(
            ProcessInfo.processInfo.environment[variable],
            originalValue
        )
    }

    func testTimeoutTerminatesLongRunningProcess() throws {
        let start = Date()
        let result = try XCTUnwrap(
            ProcessRunner.run(
                path: "/bin/sleep",
                arguments: ["5"],
                timeout: 0.05
            )
        )

        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        XCTAssertNotEqual(result.terminationStatus, 0)
    }

    func testLegacyOutputWrapperReturnsNilForEmptyOutput() {
        XCTAssertNil(process(path: "/usr/bin/true", arguments: []))
    }
}

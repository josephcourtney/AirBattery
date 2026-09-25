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

    func testDeviceConversionNormalizesMissingNameLevelAndCharging() {
        let entry = BluetoothHIDLogEntry(
            mac: "11:22:33:44:55:66",
            name: "",
            type: "Mouse",
            time: "ignored",
            level: 130,
            status: "+"
        )

        let device = entry.device(
            parent: "Mac",
            observedAt: 200,
            eventTime: 150
        )

        XCTAssertEqual(device.deviceID, "11:22:33:44:55:66")
        XCTAssertEqual(device.deviceName, "Mouse (11:22:33:44:55:66)")
        XCTAssertEqual(device.deviceType, "Mouse")
        XCTAssertEqual(device.batteryLevel, 100)
        XCTAssertEqual(device.isCharging, 1)
        XCTAssertEqual(device.parentName, "Mac")
        XCTAssertEqual(device.lastUpdate, 200)
        XCTAssertEqual(device.realUpdate, 150)
    }

    func testDeviceConversionClampsNegativeLevel() {
        let entry = BluetoothHIDLogEntry(
            mac: "AA",
            name: "Keyboard",
            type: "Keyboard",
            time: "ignored",
            level: -10,
            status: "-"
        )

        let device = entry.device(parent: "Mac", observedAt: 1, eventTime: 0)

        XCTAssertEqual(device.deviceName, "Keyboard")
        XCTAssertEqual(device.batteryLevel, 0)
        XCTAssertEqual(device.isCharging, 0)
    }
}

final class BluetoothHIDRunStateTests: XCTestCase {
    func testOverlappingRunsCoalesceIntoOneFollowUp() {
        var state = BluetoothHIDRunState()

        XCTAssertTrue(state.begin())
        XCTAssertTrue(state.isRunning)
        XCTAssertFalse(state.hasQueuedRun)

        XCTAssertFalse(state.begin())
        XCTAssertFalse(state.begin())
        XCTAssertTrue(state.hasQueuedRun)

        XCTAssertTrue(state.finish())
        XCTAssertFalse(state.isRunning)
        XCTAssertFalse(state.hasQueuedRun)
    }

    func testFreshRunCanBeginAfterFinish() {
        var state = BluetoothHIDRunState()

        XCTAssertTrue(state.begin())
        XCTAssertFalse(state.finish())
        XCTAssertTrue(state.begin())
        XCTAssertFalse(state.finish())
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

    func testReportsNonzeroExitStatus() throws {
        let result = try XCTUnwrap(
            ProcessRunner.run(
                path: "/bin/sh",
                arguments: ["-c", "exit 7"]
            )
        )

        XCTAssertEqual(result.terminationStatus, 7)
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

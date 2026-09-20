import Dispatch
import Foundation
import XCTest

final class IDeviceInfoParserTests: XCTestCase {
    func testParsesDeviceMetadata() {
        let output = """
        ActivationState: Activated
        DeviceClass: iPad
        DeviceName: iPad (102)
        ProductType: iPad6,12
        ProductVersion: 16.7.16
        """

        XCTAssertEqual(
            IDeviceInfoParser.metadata(from: output),
            IDeviceMetadata(
                name: "iPad (102)",
                productType: "iPad6,12",
                deviceClass: "iPad"
            )
        )
    }

    func testMetadataRequiresAllFields() {
        XCTAssertNil(
            IDeviceInfoParser.metadata(
                from: "DeviceName: Phone\nProductType: iPhone15,2\n"
            )
        )
    }

    func testParsesBatteryReading() {
        let output = """
        BatteryCurrentCapacity: 87
        BatteryIsCharging: false
        ExternalConnected: true
        """

        XCTAssertEqual(
            IDeviceInfoParser.battery(from: output),
            IDeviceBatteryReading(level: 87, isCharging: false)
        )
    }

    func testBatteryAcceptsCommonBooleanRepresentations() {
        XCTAssertEqual(
            IDeviceInfoParser.battery(
                from: "BatteryCurrentCapacity: 42\nBatteryIsCharging: 1"
            ),
            IDeviceBatteryReading(level: 42, isCharging: true)
        )
        XCTAssertEqual(
            IDeviceInfoParser.battery(
                from: "BatteryCurrentCapacity: 42\nBatteryIsCharging: no"
            ),
            IDeviceBatteryReading(level: 42, isCharging: false)
        )
    }

    func testMalformedBatteryReadingIsRejected() {
        XCTAssertNil(
            IDeviceInfoParser.battery(
                from: "BatteryCurrentCapacity: unknown\nBatteryIsCharging: true"
            )
        )
        XCTAssertNil(
            IDeviceInfoParser.battery(
                from: "BatteryCurrentCapacity: 90\nBatteryIsCharging: perhaps"
            )
        )
    }
}

final class CompanionBatteryResponseTests: XCTestCase {
    func testDecodesEmptyWatchList() throws {
        let json = #"{"parent":"phone","watches":[]}"#
        let response = try JSONDecoder().decode(
            CompanionBatteryResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertTrue(response.watches.isEmpty)
        XCTAssertTrue(response.validWatches.isEmpty)
    }

    func testDecodesWatchBattery() throws {
        let json = """
        {
          "parent": "phone",
          "watches": [
            {
              "id": "watch-1",
              "name": "Apple Watch",
              "productType": "Watch7,4",
              "batteryLevel": 63,
              "isCharging": true
            }
          ]
        }
        """
        let response = try JSONDecoder().decode(
            CompanionBatteryResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(
            response.validWatches,
            [
                CompanionBatteryResponse.Watch(
                    id: "watch-1",
                    name: "Apple Watch",
                    productType: "Watch7,4",
                    batteryLevel: 63,
                    isCharging: true
                )
            ]
        )
    }

    func testFiltersOutOfRangeWatchLevels() throws {
        let json = """
        {
          "watches": [
            {"id":"low","name":"Low","productType":"Watch","batteryLevel":-1,"isCharging":false},
            {"id":"zero","name":"Zero","productType":"Watch","batteryLevel":0,"isCharging":false},
            {"id":"full","name":"Full","productType":"Watch","batteryLevel":100,"isCharging":true},
            {"id":"high","name":"High","productType":"Watch","batteryLevel":101,"isCharging":false}
          ]
        }
        """
        let response = try JSONDecoder().decode(
            CompanionBatteryResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(response.validWatches.map(\.id), ["zero", "full"])
    }

    func testMalformedCompanionJSONFailsDecoding() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                CompanionBatteryResponse.self,
                from: Data(#"{"watches":"not-an-array"}"#.utf8)
            )
        )
    }
}

final class CompanionProbeStateTests: XCTestCase {
    func testOnlyIPhoneIsEligible() {
        let state = CompanionProbeState(interval: 300)

        XCTAssertFalse(
            state.shouldProbe(parentID: "ipad", deviceType: "iPad", now: 1_000)
        )
        XCTAssertFalse(
            state.shouldProbe(parentID: "watch", deviceType: "Watch", now: 1_000)
        )
        XCTAssertTrue(
            state.shouldProbe(parentID: "phone", deviceType: "iphone", now: 1_000)
        )
    }

    func testProbeIsRateLimitedPerParent() {
        let state = CompanionProbeState(interval: 300)

        XCTAssertTrue(
            state.shouldProbe(parentID: "phone-a", deviceType: "iPhone", now: 1_000)
        )
        XCTAssertFalse(
            state.shouldProbe(parentID: "phone-a", deviceType: "iPhone", now: 1_299)
        )
        XCTAssertTrue(
            state.shouldProbe(parentID: "phone-a", deviceType: "iPhone", now: 1_300)
        )
    }

    func testDifferentParentsHaveIndependentRateLimits() {
        let state = CompanionProbeState(interval: 300)

        XCTAssertTrue(
            state.shouldProbe(parentID: "phone-a", deviceType: "iPhone", now: 1_000)
        )
        XCTAssertTrue(
            state.shouldProbe(parentID: "phone-b", deviceType: "iPhone", now: 1_001)
        )
    }

    func testSignalDisableBlocksFurtherProbes() {
        let state = CompanionProbeState(interval: 300)

        XCTAssertTrue(
            state.shouldProbe(parentID: "phone-a", deviceType: "iPhone", now: 1_000)
        )
        state.disableForLaunch()

        XCTAssertTrue(state.isDisabledForLaunch)
        XCTAssertFalse(
            state.shouldProbe(parentID: "phone-b", deviceType: "iPhone", now: 2_000)
        )
    }
}

final class DiscoveryCandidateTests: XCTestCase {
    func testMergesUSBAndNetworkObservations() {
        var candidate = IDeviceDiscoveryCandidate(
            identifier: "device",
            name: nil,
            deviceType: nil,
            model: nil,
            sources: [.network],
            lastSeen: Date(timeIntervalSince1970: 100),
            batteryReadable: false
        )

        candidate.merge(
            source: .usb,
            name: "Phone",
            deviceType: "iPhone",
            model: "iPhone15,2",
            batteryReadable: true,
            lastSeen: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(candidate.sources, [.network, .usb])
        XCTAssertEqual(candidate.name, "Phone")
        XCTAssertEqual(candidate.deviceType, "iPhone")
        XCTAssertEqual(candidate.model, "iPhone15,2")
        XCTAssertTrue(candidate.batteryReadable)
        XCTAssertEqual(candidate.lastSeen, Date(timeIntervalSince1970: 200))
    }

    func testBatteryReadableIsSticky() {
        var candidate = IDeviceDiscoveryCandidate(
            identifier: "device",
            name: "Phone",
            deviceType: "iPhone",
            model: nil,
            sources: [.network],
            lastSeen: .distantPast,
            batteryReadable: true
        )

        candidate.merge(
            source: .network,
            batteryReadable: false,
            lastSeen: .distantFuture
        )

        XCTAssertTrue(candidate.batteryReadable)
    }
}

final class ExclusiveScanGateTests: XCTestCase {
    func testOnlyOneScanMayBeInFlight() {
        let gate = ExclusiveScanGate()

        XCTAssertTrue(gate.tryBegin())
        XCTAssertFalse(gate.tryBegin())

        gate.end()

        XCTAssertTrue(gate.tryBegin())
        gate.end()
    }

    func testConcurrentBeginsHaveSingleWinner() {
        let gate = ExclusiveScanGate()
        let resultLock = NSLock()
        var successes = 0

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            if gate.tryBegin() {
                resultLock.lock()
                successes += 1
                resultLock.unlock()
            }
        }

        XCTAssertEqual(successes, 1)
        gate.end()
    }
}

final class EarbudMergePolicyTests: XCTestCase {
    func testDisabledNeverMerges() {
        XCTAssertNil(
            EarbudMergePolicy.mergedLevel(
                enabled: false,
                threshold: 100,
                leftLevel: 80,
                leftCharging: 0,
                rightLevel: 80,
                rightCharging: 0
            )
        )
    }

    func testMergesWithinThresholdUsingLowerLevel() {
        XCTAssertEqual(
            EarbudMergePolicy.mergedLevel(
                enabled: true,
                threshold: 5,
                leftLevel: 84,
                leftCharging: 0,
                rightLevel: 80,
                rightCharging: 0
            ),
            80
        )
    }

    func testEqualToThresholdStillMerges() {
        XCTAssertEqual(
            EarbudMergePolicy.mergedLevel(
                enabled: true,
                threshold: 5,
                leftLevel: 85,
                leftCharging: 1,
                rightLevel: 80,
                rightCharging: 1
            ),
            80
        )
    }

    func testOverThresholdDoesNotMerge() {
        XCTAssertNil(
            EarbudMergePolicy.mergedLevel(
                enabled: true,
                threshold: 5,
                leftLevel: 86,
                leftCharging: 0,
                rightLevel: 80,
                rightCharging: 0
            )
        )
    }

    func testChargingMismatchDoesNotMerge() {
        XCTAssertNil(
            EarbudMergePolicy.mergedLevel(
                enabled: true,
                threshold: 5,
                leftLevel: 82,
                leftCharging: 1,
                rightLevel: 80,
                rightCharging: 0
            )
        )
    }

    func testMergedChargingMatchesEarbuds() {
        XCTAssertEqual(
            EarbudMergePolicy.mergedCharging(
                enabled: true,
                threshold: 5,
                leftLevel: 82,
                leftCharging: 1,
                rightLevel: 80,
                rightCharging: 1
            ),
            1
        )
    }
}

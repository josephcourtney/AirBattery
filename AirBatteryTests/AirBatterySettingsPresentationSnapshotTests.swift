@testable import AirBatteryKit
import Foundation
import XCTest

final class AirBatterySettingsPresentationSnapshotTests: XCTestCase {
    @MainActor
    func testSnapshotRoundTripRestoresSettingsAndDiscoveryState() throws {
        let original = AirBatterySettingsPresentationSnapshot.capture(
            scenarioID: "original"
        )
        defer { try? original.restore() }

        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let expected = AirBatterySettingsPresentationSnapshot(
            scenarioID: "airpods",
            selectedSection: "display",
            showOn: "both",
            appearance: "true",
            showThisMac: "percent",
            carouselMode: false,
            colorfulBattery: true,
            iosBatteryStyle: true,
            intBattOnStatusBar: false,
            batteryPercent: "inside",
            hideLevel: 70,
            twsMergeEnabled: false,
            twsMerge: 3,
            reverseWidgetList: true,
            widgetInterval: -1,
            deviceName: "Replay Mac",
            showDebug: true,
            readBLEDevice: true,
            ideviceOverBLE: false,
            bleDiscoveryMode: "review",
            discoveryRules: [],
            logicalDiscoveryRules: [],
            discoveryCandidates: [
                .init(
                    identifier: "candidate-1",
                    name: "Replay Headphones",
                    rssi: -55,
                    smoothedRSSI: -54.5,
                    firstSeen: timestamp,
                    lastSeen: timestamp,
                    seenCount: 4,
                    isConnectable: true,
                    advertisesBatteryService: true,
                    hasPassiveBatteryData: false,
                    matchesPairedName: true,
                    lastProbeResult: nil
                ),
            ]
        )

        let encoded = try expected.encoded()
        let decoded = try AirBatterySettingsPresentationSnapshot.decode(encoded)
        XCTAssertEqual(try decoded.stableID(), try expected.stableID())

        try decoded.restore()
        let restored = AirBatterySettingsPresentationSnapshot.capture(
            scenarioID: decoded.scenarioID
        )

        XCTAssertEqual(try restored.encoded(), encoded)
        XCTAssertEqual(BLEDiscoveryPolicyStore.shared.reviewCount, 1)
    }
}

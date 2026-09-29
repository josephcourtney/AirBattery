import AirBatteryKit
import Foundation
import Hrost

private enum AirBatteryHrostReplayError: LocalizedError {
    case unknownScenario(String)

    var errorDescription: String? {
        switch self {
        case let .unknownScenario(id):
            "Recorded AirBattery settings state references unknown scenario '\(id)'."
        }
    }
}

extension AirBatteryHrostManifest {
    var replayAdapter: HrostReplayAdapter<AirBatteryHrostScenario>? {
        HrostReplayAdapter(
            schemaIdentifier: AirBatterySettingsPresentationSnapshot.schemaIdentifier,
            supportedSchemaVersions: [AirBatterySettingsPresentationSnapshot.schemaVersion]
        ) { input in
            let snapshot = try AirBatterySettingsPresentationSnapshot.decode(input.payload)
            guard let scenario = AirBatteryHrostScenario(rawValue: snapshot.scenarioID) else {
                throw AirBatteryHrostReplayError.unknownScenario(snapshot.scenarioID)
            }
            try snapshot.restore()
            return scenario
        }
    }
}

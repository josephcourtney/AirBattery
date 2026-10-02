import Foundation
import Hrost

extension AirBatteryHrostManifest {
    var referenceAcquirer: (any HrostReferenceAcquirer)? {
        let environment = ProcessInfo.processInfo.environment
        guard let providerPath = environment["AIRBATTERY_HROST_REFERENCE_PROVIDER"],
              !providerPath.isEmpty
        else {
            return nil
        }

        var providerEnvironment: [String: String] = [:]
        if let brokerSocket = environment["AIRBATTERY_HROST_BROKER_SOCKET"],
           !brokerSocket.isEmpty
        {
            providerEnvironment["HROST_ACQUISITION_BROKER_SOCKET"] = brokerSocket
        }

        let providerURL = URL(fileURLWithPath: providerPath).standardizedFileURL
        let sessionRoot = environment["AIRBATTERY_HROST_REFERENCE_SESSION_ROOT"]
            .flatMap { path -> URL? in
                guard !path.isEmpty else { return nil }
                return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
            }
        let timeoutSeconds = environment["AIRBATTERY_HROST_REFERENCE_TIMEOUT_SECONDS"]
            .flatMap(Double.init) ?? 45

        return HrostExternalCommandReferenceAcquirer(
            executableURL: providerURL,
            workingDirectory: providerURL.deletingLastPathComponent(),
            environment: providerEnvironment,
            timeoutSeconds: timeoutSeconds,
            sessionRoot: sessionRoot
        )
    }
}

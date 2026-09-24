import AppKit
import SwiftUI

extension DevicesView {
    @ViewBuilder
    func candidateDetails(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            detailRow("Signal", signalLabel(candidate.displayRSSI))
            detailRow("Last seen", relativeAge(candidate.lastSeen.timeIntervalSince1970))
            if suggested {
                detailRow("Why suggested", candidateSuggestionReason(candidate))
            }
            if let result = candidate.lastProbeResult {
                detailRow("Last battery query", result)
            }
        }
    }

    @ViewBuilder
    func candidateTechnicalDetails(_ candidate: BLEDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            detailRow(
                "Signal",
                "\(candidate.displayRSSI) dBm (raw \(candidate.rssi) dBm)"
            )
            detailRow("Seen", "\(candidate.seenCount) times")
            detailRow("Identifier", candidate.identifier)
            if candidate.matchesPairedName {
                detailRow("Pairing", "Name matches a paired device")
            }
            if candidate.hasPassiveBatteryData {
                detailRow("Advertisement", "Battery payload observed during this launch")
            } else if candidate.advertisesBatteryService {
                detailRow("Advertisement", "Battery Service advertised")
            }
            detailRow("Connection", candidate.isConnectable ? "Connectable" : "Not connectable")
        }
    }

    @ViewBuilder
    func iDeviceDetails(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            detailRow(
                "Available through",
                sortedIDeviceSources(candidate.sources).map(\.rawValue).joined(separator: " · ")
            )
            if let model = candidate.model, !model.isEmpty {
                detailRow("Model", model)
            }
            detailRow("Last seen", relativeAge(candidate.lastSeen.timeIntervalSince1970))
            detailRow(
                "Battery",
                candidate.batteryReadable ? "Readable" : "No battery reading yet"
            )
        }
    }

    @ViewBuilder
    func iDeviceTechnicalDetails(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let type = candidate.deviceType, !type.isEmpty {
                detailRow("Type", type)
            }
            detailRow("Identifier", candidate.identifier)
            detailRow(
                "Battery query",
                candidate.batteryReadable ? "Battery data read successfully" : "No battery record yet"
            )
        }
    }

    @ViewBuilder
    func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
                .fontDesign(isIdentifierLabel(label) ? .monospaced : .default)
                .textSelection(.enabled)
            Spacer()
        }
    }

    func isIdentifierLabel(_ label: String) -> Bool {
        label == "Identifier" || label.hasSuffix(" ID") || label.hasSuffix(" UDID")
    }

    func knownDeviceListSummary(_ device: KnownDeviceSnapshot) -> String {
        if let group = airPodsGroup(device),
           let presentation = AirPodsPresentation.logicalPresentations(
               from: group.components,
               mergeEarbuds: false,
               mergeThreshold: 0
           ).first {
            return presentation.components.map { component in
                let prefix: String
                switch component.role {
                case .caseBattery: prefix = "C"
                case .leftEarbud: prefix = "L"
                case .rightEarbud: prefix = "R"
                case .earbuds: prefix = "L/R"
                case .primary: prefix = "B"
                }
                return "\(prefix) \(component.level)%"
            }.joined(separator: " · ")
        }

        if let representative = representativeDevice(device) {
            return representative.hasBattery
                ? "\(representative.batteryLevel)% · " + relativeAge(representative.lastUpdate)
                : relativeAge(representative.lastUpdate)
        }

        return "No battery reading"
    }

    func knownDeviceConnectionSummary(_ device: KnownDeviceSnapshot) -> String {
        let sources = sortedSources(device.sources).map(\.rawValue)
        let sourceText = sources.isEmpty ? "Known device" : sources.joined(separator: " · ")

        guard let representative = representativeDevice(device) else {
            return sourceText + " · no retained battery reading"
        }
        return sourceText + " · " + relativeAge(representative.lastUpdate)
    }

    func knownDeviceStatusColor(_ device: KnownDeviceSnapshot) -> Color {
        guard let representative = representativeDevice(device) else {
            return .secondary.opacity(0.45)
        }
        let age = Date().timeIntervalSince1970 - representative.lastUpdate
        return age < 120 ? .green : .secondary.opacity(0.55)
    }

    func knownDeviceStatusDescription(_ device: KnownDeviceSnapshot) -> String {
        guard let representative = representativeDevice(device) else {
            return "No retained battery reading"
        }
        let age = Date().timeIntervalSince1970 - representative.lastUpdate
        return age < 120
            ? "Recently observed"
            : "Last observed " + relativeAge(representative.lastUpdate)
    }

    func humanReadableType(_ device: KnownDeviceSnapshot) -> String {
        if airPodsGroup(device) != nil { return "AirPods" }
        guard let representative = representativeDevice(device) else { return "Device" }

        let type = representative.deviceType.lowercased()
        if type.contains("iphone") { return "iPhone" }
        if type.contains("ipad") { return "iPad" }
        if type.contains("watch") { return "Apple Watch" }
        if type.contains("keyboard") { return "Keyboard" }
        if type.contains("mouse") || representative.deviceName.localizedCaseInsensitiveContains("MX Ergo") {
            return "Pointing Device"
        }
        if type.contains("mac") || representative.deviceID == "@MacInternalBattery" {
            return "Mac"
        }
        return representative.deviceType
    }

    func displayName(for device: KnownDeviceSnapshot) -> String {
        DeviceDisplayNameStore.displayName(
            forKey: displayNameKey(for: device),
            fallback: device.name
        )
    }

    func displayNameKey(for device: KnownDeviceSnapshot) -> String {
        if let representative = representativeDevice(device) {
            return DeviceDisplayNameStore.key(
                canonicalID: representative.deviceID,
                deviceType: representative.deviceType
            )
        }
        return DeviceDisplayNameStore.key(
            canonicalID: "known:" + device.id,
            deviceType: "logical"
        )
    }

    func syncDisplayNameDraft() {
        guard case .known(let id) = selection,
              let device = inventoryModel.devices.first(where: { $0.id == id })
        else {
            displayNameDraft = ""
            return
        }
        displayNameDraft = DeviceDisplayNameStore.override(
            forKey: displayNameKey(for: device)
        ) ?? ""
    }

    func saveDisplayName(_ value: String, for device: KnownDeviceSnapshot) {
        DeviceDisplayNameStore.setOverride(
            value,
            forKey: displayNameKey(for: device)
        )
    }

    func estimateShortText(_ estimate: BatteryTimeEstimate) -> String {
        let duration = formattedDuration(estimate.duration)
        return estimate.kind == .charging
            ? "\(duration) to full"
            : "\(duration) left"
    }

    func estimateDurationText(_ estimate: BatteryTimeEstimate) -> String {
        "~" + estimateShortText(estimate)
    }

    func estimateEndpointText(_ estimate: BatteryTimeEstimate) -> String {
        let time = estimate.endDate.formatted(
            date: .omitted,
            time: .shortened
        )
        return estimate.kind == .charging
            ? "Full around \(time)"
            : "Empty around \(time)"
    }

    func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    func nearbyIDeviceCandidates(known: [KnownDeviceSnapshot]) -> [IDeviceDiscoveryCandidate] {
        let knownIDs = Set(
            known.flatMap(\.devices).flatMap { device in
                [device.deviceID, device.mobileDeviceID, device.bleDeviceID]
                    .compactMap { $0 }
            }
        )
        let knownNames = Set(known.map { inventoryKey($0.name) })
        return iDeviceBattery.discoveryCandidates
            .filter {
                !knownIDs.contains($0.identifier) &&
                    !($0.name.map { knownNames.contains(inventoryKey($0)) } ?? false)
            }
            .sorted {
                ($0.name ?? $0.identifier).localizedCaseInsensitiveCompare(
                    $1.name ?? $1.identifier
                ) == .orderedAscending
            }
    }

    func nearbyBLECandidates(known: [KnownDeviceSnapshot]) -> [BLEDiscoveryCandidate] {
        let knownNames = Set(known.map { inventoryKey($0.name) })
        return policyStore.nearbyCandidates.filter {
            !knownNames.contains(inventoryKey($0.name))
        }
    }

    func candidateSuggestionReason(_ candidate: BLEDiscoveryCandidate) -> String {
        if candidate.hasPassiveBatteryData { return "Battery data was advertised" }
        if candidate.advertisesBatteryService { return "Battery service was advertised" }
        if candidate.matchesPairedName { return "Matches a paired accessory" }
        if candidate.lastProbeResult != nil { return "Previously queried" }
        return "Stable nearby device"
    }

    func iDevicePrimarySummary(_ candidate: IDeviceDiscoveryCandidate) -> String {
        var parts: [String] = []
        if let type = candidate.deviceType, !type.isEmpty { parts.append(type) }
        if let model = candidate.model, !model.isEmpty { parts.append(model) }
        parts.append(candidate.batteryReadable ? "battery readable" : "no battery record yet")
        parts.append(relativeAge(candidate.lastSeen.timeIntervalSince1970))
        return parts.joined(separator: " · ")
    }

    func candidatePrimarySummary(_ candidate: BLEDiscoveryCandidate) -> String {
        var parts: [String] = []
        if candidate.hasPassiveBatteryData {
            parts.append("Battery advertisement seen")
        } else if candidate.advertisesBatteryService {
            parts.append("Battery service advertised")
        } else if candidate.matchesPairedName {
            parts.append("Name matches paired device")
        }
        parts.append(signalLabel(candidate.displayRSSI) + " signal")
        return parts.joined(separator: " · ")
    }

    func representativeDevice(_ device: KnownDeviceSnapshot) -> Device? {
        device.devices.max(by: { $0.lastUpdate < $1.lastUpdate })
    }

    func airPodsGroup(_ device: KnownDeviceSnapshot) -> AirPodsBatteryGroup? {
        guard let representative = device.devices.first(where: {
            AirPodsPresentation.baseName(for: $0) != nil
        }) else {
            return nil
        }
        return AirPodsPresentation.group(for: representative, in: device.devices)
    }

    func sortedSources(_ sources: Set<DeviceInventorySource>) -> [DeviceInventorySource] {
        sources.sorted { $0.sortOrder < $1.sortOrder }
    }

    func sortedIDeviceSources(_ sources: Set<IDeviceConnectionSource>) -> [IDeviceConnectionSource] {
        sources.sorted { $0.rawValue < $1.rawValue }
    }

    func inventoryKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func relativeAge(_ timestamp: Double) -> String {
        let seconds = max(0, Date().timeIntervalSince1970 - timestamp)
        if seconds < 60 { return "now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(seconds / 3600)
        return "\(hours)h ago"
    }

    func signalLabel(_ rssi: Int) -> String {
        switch rssi {
        case -60...0: return "Strong"
        case -75 ..< -60: return "Good"
        case -90 ..< -75: return "Weak"
        default: return "Very weak"
        }
    }

    func shortIdentifier(_ identifier: String) -> String {
        guard identifier.count > 13 else { return identifier }
        return "\(identifier.prefix(8))…\(identifier.suffix(4))"
    }

    func batterySourceLabel(_ source: DeviceObservationSource) -> String {
        switch source {
        case .ble: return "Bluetooth"
        case .libimobiledevice: return "Network / USB"
        }
    }
}

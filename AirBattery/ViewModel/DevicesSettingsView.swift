import AppKit
import SwiftUI
import WidgetKit

struct DevicesView: View {
    @ObservedObject private var policyStore = BLEDiscoveryPolicyStore.shared
    @ObservedObject private var iDeviceBattery = IDeviceBattery.shared
    @ObservedObject private var monitoring = MonitoringCoordinator.shared
    @StateObject private var inventoryModel = DeviceInventoryModel()
    @State private var expandedKnown: Set<String> = []
    @State private var expandedNearby: Set<String> = []
    @State private var technicalExpandedKnown: Set<String> = []
    @State private var technicalExpandedNearby: Set<String> = []
    @State private var showOtherNearby = false
    @AppStorage("twsMergeEnabled") private var twsMergeEnabled = true
    @AppStorage("twsMerge") private var twsMerge = 5

    var body: some View {
        let known = inventoryModel.devices
        let nearbyApple = nearbyIDeviceCandidates(known: known)
        let nearbyBLE = nearbyBLECandidates(known: known)
        let suggestedIDs = Set(policyStore.suggestedCandidates.map(\.identifier))
        let suggestedBLE = nearbyBLE.filter { suggestedIDs.contains($0.identifier) }
        let otherBLE = nearbyBLE.filter { !suggestedIDs.contains($0.identifier) }

        return ScrollView {
            SForm(noSpacer: true) {
                SGroupBox(label: "Known Devices") {
                    if known.isEmpty {
                        emptyRow("No known devices.")
                    } else {
                        ForEach(known) { device in
                            knownDeviceRow(device)
                            if device.id != known.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
                .disclosureGroupStyle(DeviceDisclosureStyle())

                SGroupBox(label: "Nearby Devices") {
                    HStack {
                        Text("Devices observed through active discovery that do not yet have a known device record.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !nearbyApple.isEmpty || !nearbyBLE.isEmpty {
                            Button("Clear") {
                                iDeviceBattery.clearDiscoveryCandidates()
                                policyStore.clearNearby()
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    if nearbyApple.isEmpty && nearbyBLE.isEmpty {
                        Divider().opacity(0.5)
                        emptyRow("No unknown nearby devices.")
                    } else {
                        ForEach(nearbyApple) { candidate in
                            Divider().opacity(0.5)
                            nearbyIDeviceRow(candidate)
                        }

                        ForEach(suggestedBLE) { candidate in
                            Divider().opacity(0.5)
                            nearbyBLEDeviceRow(candidate, suggested: true)
                        }

                        if !otherBLE.isEmpty {
                            Divider().opacity(0.5)
                            DisclosureGroup(isExpanded: $showOtherNearby) {
                                ForEach(otherBLE.prefix(30)) { candidate in
                                    nearbyBLEDeviceRow(candidate, suggested: false)
                                    if candidate.id != otherBLE.prefix(30).last?.id {
                                        Divider().opacity(0.5)
                                    }
                                }
                                .padding(.top, 5)
                            } label: {
                                HStack {
                                    Text("Other nearby Bluetooth devices")
                                    Text("\(otherBLE.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showOtherNearby.toggle()
                                }
                            }
                        }
                    }
                }
                .disclosureGroupStyle(DeviceDisclosureStyle())

            }
        }
        .onAppear {
            refreshInventory()
        }
        .onReceive(monitoring.$fiveSecondTick) { _ in
            refreshInventory()
        }
        .onChange(of: policyStore.rules) { _, _ in
            refreshInventory()
        }
        .onChange(of: policyStore.logicalRules) { _, _ in
            refreshInventory()
        }
        .onChange(of: iDeviceBattery.discoveryCandidates) { _, _ in
            refreshInventory()
        }
    }

    private func refreshInventory() {
        inventoryModel.refresh(
            policyStore: policyStore,
            iDeviceBattery: iDeviceBattery
        )
    }

    private func nearbyIDeviceCandidates(
        known: [KnownDeviceSnapshot]
    ) -> [IDeviceDiscoveryCandidate] {
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

    private func nearbyBLECandidates(
        known: [KnownDeviceSnapshot]
    ) -> [BLEDiscoveryCandidate] {
        let knownNames = Set(known.map { inventoryKey($0.name) })
        return policyStore.nearbyCandidates.filter {
            !knownNames.contains(inventoryKey($0.name))
        }
    }

    @ViewBuilder
    private func knownDeviceRow(_ device: KnownDeviceSnapshot) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedKnown.contains(device.id) },
                set: { expanded in
                    if expanded { expandedKnown.insert(device.id) }
                    else { expandedKnown.remove(device.id) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 9) {
                if let group = airPodsGroup(device) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Battery components")
                            .font(.caption)
                            .fontWeight(.semibold)
                        airPodsComponentRows(group)
                    }
                } else if let representative = representativeDevice(device) {
                    VStack(alignment: .leading, spacing: 3) {
                        if representative.hasBattery {
                            detailRow(
                                "Battery",
                                "\(representative.batteryLevel)%" +
                                (representative.isCharging != 0 ? " · charging" : "")
                            )
                        }
                        if let model = representative.deviceModel, !model.isEmpty {
                            detailRow("Model", model)
                        }
                        detailRow(
                            "Known sources",
                            sortedSources(device.sources).map(\.rawValue).joined(separator: " · ")
                        )
                        if let source = representative.batterySource {
                            detailRow("Last battery via", batterySourceLabel(source))
                        }
                        detailRow("Last update", relativeAge(representative.lastUpdate))
                        if !representative.parentName.isEmpty {
                            detailRow("Parent", representative.parentName)
                        }
                    }
                } else {
                    Text("Known from a saved Bluetooth policy; no retained battery reading.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                DisclosureGroup(
                    isExpanded: Binding(
                        get: { technicalExpandedKnown.contains(device.id) },
                        set: { expanded in
                            if expanded { technicalExpandedKnown.insert(device.id) }
                            else { technicalExpandedKnown.remove(device.id) }
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 7) {
                        if let representative = representativeDevice(device) {
                            VStack(alignment: .leading, spacing: 2) {
                                detailRow("Type", representative.deviceType)
                                detailRow("Canonical ID", representative.deviceID)
                                if let mobileID = representative.mobileDeviceID, !mobileID.isEmpty {
                                    detailRow("Mobile UDID", mobileID)
                                }
                                if let bleID = representative.bleDeviceID, !bleID.isEmpty {
                                    detailRow("Bluetooth ID", bleID)
                                }
                            }
                        }

                        if !device.iDeviceCandidates.isEmpty {
                            Divider().opacity(0.5)
                            Text("Apple device connections")
                                .font(.caption)
                                .fontWeight(.semibold)
                            ForEach(device.iDeviceCandidates) { candidate in
                                iDeviceTechnicalDetails(candidate)
                            }
                        }

                        if let ble = device.ble {
                            if !ble.identities.isEmpty {
                                Divider().opacity(0.5)
                                Text("Bluetooth identities")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                ForEach(ble.identities) { candidate in
                                    identityDetail(candidate, logicalPolicy: ble.policy)
                                }
                            } else if device.sources.contains(.bluetooth) {
                                Text("Bluetooth device not observed during this launch.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if !ble.exactRules.isEmpty {
                                Text("Identity overrides take precedence over the device battery-access policy.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 5)
                } label: {
                    Label("Technical Details", systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleTechnicalKnown(device.id)
                        }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(device.name)
                        ForEach(sortedSources(device.sources), id: \.self) { source in
                            sourceBadge(source.rawValue)
                        }
                    }
                    Text(knownDeviceSummary(device))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleKnown(device.id)
                }
                if let ble = device.ble {
                    logicalPolicyMenu(name: device.name, currentPolicy: ble.policy, hasOverrides: !ble.exactRules.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func nearbyIDeviceRow(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        let rowID = "idevice:" + candidate.identifier
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedNearby.contains(rowID) },
                set: { expanded in
                    if expanded { expandedNearby.insert(rowID) }
                    else { expandedNearby.remove(rowID) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 7) {
                iDeviceDetails(candidate)

                DisclosureGroup(
                    isExpanded: Binding(
                        get: { technicalExpandedNearby.contains(rowID) },
                        set: { expanded in
                            if expanded { technicalExpandedNearby.insert(rowID) }
                            else { technicalExpandedNearby.remove(rowID) }
                        }
                    )
                ) {
                    iDeviceTechnicalDetails(candidate)
                        .padding(.top, 4)
                } label: {
                    Label("Technical Details", systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleTechnicalNearby(rowID)
                        }
                }
            }
            .padding(.top, 5)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(candidate.name ?? "Apple device")
                        ForEach(sortedIDeviceSources(candidate.sources), id: \.self) { source in
                            sourceBadge(source.rawValue)
                        }
                    }
                    Text(iDevicePrimarySummary(candidate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleNearby(rowID)
                }
            }
        }
    }

    @ViewBuilder
    private func nearbyBLEDeviceRow(
        _ candidate: BLEDiscoveryCandidate,
        suggested: Bool
    ) -> some View {
        let rowID = "ble:" + candidate.identifier
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedNearby.contains(rowID) },
                set: { expanded in
                    if expanded { expandedNearby.insert(rowID) }
                    else { expandedNearby.remove(rowID) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 7) {
                candidateDetails(candidate, suggested: suggested)

                DisclosureGroup(
                    isExpanded: Binding(
                        get: { technicalExpandedNearby.contains(rowID) },
                        set: { expanded in
                            if expanded { technicalExpandedNearby.insert(rowID) }
                            else { technicalExpandedNearby.remove(rowID) }
                        }
                    )
                ) {
                    candidateTechnicalDetails(candidate)
                        .padding(.top, 4)
                } label: {
                    Label("Technical Details", systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleTechnicalNearby(rowID)
                        }
                }
            }
            .padding(.top, 5)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(candidate.name)
                        sourceBadge("Bluetooth")
                        if suggested {
                            sourceBadge("Suggested")
                        }
                    }
                    Text(candidatePrimarySummary(candidate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleNearby(rowID)
                }
                reviewMenu(candidate, suggested: suggested)
            }
        }
    }

    @ViewBuilder
    private func sourceBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundColor(.primary.opacity(0.72))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .accessibilityLabel("Source: \(text)")
    }

    @ViewBuilder
    private func logicalPolicyMenu(
        name: String,
        currentPolicy: BLEDevicePolicy?,
        hasOverrides: Bool
    ) -> some View {
        Menu {
            ForEach(BLEDevicePolicy.allCases, id: \.rawValue) { policy in
                Button(policy.title) {
                    policyStore.setLogicalPolicy(name: name, policy: policy)
                }
            }
            Divider()
            Button("Use discovery default") {
                policyStore.clearLogicalPolicy(name: name)
            }
        } label: {
            Text(
                "Battery access: " +
                (currentPolicy?.title ?? (hasOverrides ? "Per identity" : "Discovery default"))
            )
            .font(.caption)
            .frame(minWidth: 128, alignment: .trailing)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
        .accessibilityLabel(
            "Battery access policy: " +
            (currentPolicy?.title ?? (hasOverrides ? "Per identity" : "Discovery default"))
        )
    }

    @ViewBuilder
    private func reviewMenu(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
        Menu {
            Button("Allow queries") {
                policyStore.setLogicalPolicy(name: candidate.name, policy: .allow)
            }
            Button("Passive only") {
                policyStore.setLogicalPolicy(name: candidate.name, policy: .observe)
            }
            Button("Ignore") {
                policyStore.setLogicalPolicy(name: candidate.name, policy: .ignore)
            }
        } label: {
            Text(suggested ? "Review" : "Battery access")
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
    }

    @ViewBuilder
    private func identityDetail(
        _ candidate: BLEDiscoveryCandidate,
        logicalPolicy: BLEDevicePolicy?
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(shortIdentifier(candidate.identifier))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Menu {
                    ForEach(BLEDevicePolicy.allCases, id: \.rawValue) { policy in
                        Button(policy.title) {
                            policyStore.setPolicy(
                                identifier: candidate.identifier,
                                name: candidate.name,
                                policy: policy
                            )
                        }
                    }
                    if policyStore.exactPolicy(identifier: candidate.identifier) != nil {
                        Divider()
                        Button("Use device policy") {
                            policyStore.clearPolicy(identifier: candidate.identifier)
                        }
                    }
                } label: {
                    if let override = policyStore.exactPolicy(identifier: candidate.identifier) {
                        Text("Identity override: " + override.title)
                            .font(.caption)
                    } else {
                        Text(
                            "Uses device policy: " +
                            (logicalPolicy?.title ?? "Discovery default")
                        )
                        .font(.caption)
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
            }
            candidateTechnicalDetails(candidate)
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func candidateDetails(
        _ candidate: BLEDiscoveryCandidate,
        suggested: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            detailRow("Signal", signalLabel(candidate.displayRSSI))
            detailRow("Last seen", relativeAge(candidate.lastSeen.timeIntervalSince1970))
            if suggested {
                detailRow("Why suggested", candidateSuggestionReason(candidate))
            }
            if let result = candidate.lastProbeResult {
                detailRow("Last battery query", result)
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private func candidateTechnicalDetails(_ candidate: BLEDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
        .font(.caption)
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func iDeviceDetails(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
        .font(.caption)
    }

    @ViewBuilder
    private func iDeviceTechnicalDetails(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let type = candidate.deviceType, !type.isEmpty {
                detailRow("Type", type)
            }
            detailRow("Identifier", candidate.identifier)
            detailRow(
                "Battery query",
                candidate.batteryReadable ? "Battery data read successfully" : "No battery record yet"
            )
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 102, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    @ViewBuilder
    private func emptyRow(_ message: String) -> some View {
        HStack {
            Text(message)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func toggleKnown(_ id: String) {
        if expandedKnown.contains(id) {
            expandedKnown.remove(id)
        } else {
            expandedKnown.insert(id)
        }
    }

    private func toggleNearby(_ id: String) {
        if expandedNearby.contains(id) {
            expandedNearby.remove(id)
        } else {
            expandedNearby.insert(id)
        }
    }

    private func toggleTechnicalKnown(_ id: String) {
        if technicalExpandedKnown.contains(id) {
            technicalExpandedKnown.remove(id)
        } else {
            technicalExpandedKnown.insert(id)
        }
    }

    private func toggleTechnicalNearby(_ id: String) {
        if technicalExpandedNearby.contains(id) {
            technicalExpandedNearby.remove(id)
        } else {
            technicalExpandedNearby.insert(id)
        }
    }

    private func batterySourceLabel(_ source: DeviceObservationSource) -> String {
        switch source {
        case .ble: return "Bluetooth"
        case .libimobiledevice: return "Network / USB"
        }
    }

    private func candidateSuggestionReason(_ candidate: BLEDiscoveryCandidate) -> String {
        if candidate.hasPassiveBatteryData {
            return "Battery data was advertised"
        }
        if candidate.advertisesBatteryService {
            return "Battery service was advertised"
        }
        if candidate.matchesPairedName {
            return "Matches a paired accessory"
        }
        if candidate.lastProbeResult != nil {
            return "Previously queried"
        }
        return "Stable nearby device"
    }

    private func knownDeviceSummary(_ device: KnownDeviceSnapshot) -> String {
        if let group = airPodsGroup(device) {
            return airPodsBatterySummary(group)
        }
        if let newest = representativeDevice(device) {
            if newest.hasBattery {
                return "Battery \(newest.batteryLevel)% · \(relativeAge(newest.lastUpdate))"
            }
            return "Known device · \(relativeAge(newest.lastUpdate))"
        }
        return "Known device · no retained battery reading"
    }

    private func iDevicePrimarySummary(_ candidate: IDeviceDiscoveryCandidate) -> String {
        var parts: [String] = []
        if let type = candidate.deviceType, !type.isEmpty {
            parts.append(type)
        }
        if let model = candidate.model, !model.isEmpty {
            parts.append(model)
        }
        parts.append(candidate.batteryReadable ? "battery readable" : "no battery record yet")
        parts.append(relativeAge(candidate.lastSeen.timeIntervalSince1970))
        return parts.joined(separator: " · ")
    }

    private func representativeDevice(_ device: KnownDeviceSnapshot) -> Device? {
        device.devices.max(by: { $0.lastUpdate < $1.lastUpdate })
    }

    private func airPodsGroup(_ device: KnownDeviceSnapshot) -> AirPodsBatteryGroup? {
        guard let representative = device.devices.first(where: {
            AirBatteryModel.airPodsBaseName(for: $0) != nil
        }) else {
            return nil
        }
        return AirBatteryModel.airPodsGroup(for: representative, in: device.devices)
    }

    private func airPodsBatterySummary(_ group: AirPodsBatteryGroup) -> String {
        var parts = ["\(group.componentCount) components"]
        if let caseDevice = group.caseDevice {
            parts.append("Case \(caseDevice.batteryLevel)%")
        }

        if let merged = group.mergedEarbudLevel(enabled: twsMergeEnabled, threshold: twsMerge) {
            parts.append("Earbuds \(merged)%")
        } else {
            if let left = group.leftEarbud {
                parts.append("L \(left.batteryLevel)%")
            }
            if let right = group.rightEarbud {
                parts.append("R \(right.batteryLevel)%")
            }
            if group.leftEarbud == nil,
               group.rightEarbud == nil,
               let legacy = group.legacyMergedEarbuds {
                parts.append("Earbuds \(legacy.batteryLevel)%")
            }
        }

        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func airPodsComponentRows(_ group: AirPodsBatteryGroup) -> some View {
        if let caseDevice = group.caseDevice {
            batteryComponentRow("Case", device: caseDevice)
        }

        if let merged = group.mergedEarbudLevel(enabled: twsMergeEnabled, threshold: twsMerge) {
            HStack {
                Text("Earbuds")
                    .frame(width: 82, alignment: .leading)
                Text("\(merged)%")
                if group.mergedEarbudCharging(enabled: twsMergeEnabled, threshold: twsMerge) != 0 {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                }
                Text("merged")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .font(.caption)
        } else {
            if let left = group.leftEarbud {
                batteryComponentRow("Left", device: left)
            }
            if let right = group.rightEarbud {
                batteryComponentRow("Right", device: right)
            }
            if group.leftEarbud == nil,
               group.rightEarbud == nil,
               let legacy = group.legacyMergedEarbuds {
                batteryComponentRow("Earbuds", device: legacy)
            }
        }
    }

    @ViewBuilder
    private func batteryComponentRow(_ label: String, device: Device) -> some View {
        HStack {
            Text(label)
                .frame(width: 82, alignment: .leading)
            Text("\(device.batteryLevel)%")
            if device.isCharging != 0 {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
            }
            Text(relativeAge(device.lastUpdate))
                .foregroundColor(.secondary)
            Spacer()
        }
        .font(.caption)
    }

    private func candidatePrimarySummary(_ candidate: BLEDiscoveryCandidate) -> String {
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

    private func sortedSources(
        _ sources: Set<DeviceInventorySource>
    ) -> [DeviceInventorySource] {
        sources.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func sortedIDeviceSources(
        _ sources: Set<IDeviceConnectionSource>
    ) -> [IDeviceConnectionSource] {
        sources.sorted { $0.rawValue < $1.rawValue }
    }

    private func inventoryKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func relativeAge(_ timestamp: Double) -> String {
        let seconds = max(0, Date().timeIntervalSince1970 - timestamp)
        if seconds < 60 { return "now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = Int(seconds / 3600)
        return "\(hours)h ago"
    }

    private func signalLabel(_ rssi: Int) -> String {
        switch rssi {
        case -60...0: return "Strong"
        case -75 ..< -60: return "Good"
        case -90 ..< -75: return "Weak"
        default: return "Very weak"
        }
    }

    private func shortIdentifier(_ identifier: String) -> String {
        guard identifier.count > 13 else { return identifier }
        return "\(identifier.prefix(8))…\(identifier.suffix(4))"
    }
}



private struct DeviceDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                Button {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        configuration.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(
                            .degrees(configuration.isExpanded ? 90 : 0)
                        )
                        .frame(width: 24, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(configuration.isExpanded ? "Collapse" : "Expand")
                .accessibilityLabel(
                    configuration.isExpanded ? "Collapse" : "Expand"
                )

                configuration.label
            }

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 26)
                    .transition(.opacity)
            }
        }
        .animation(
            .easeInOut(duration: 0.14),
            value: configuration.isExpanded
        )
    }
}

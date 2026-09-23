import AppKit
import SwiftUI

private enum DeviceBrowserSelection: Hashable {
    case known(String)
    case iDevice(String)
    case bluetooth(String)
}

struct DevicesView: View {
    @ObservedObject private var policyStore = BLEDiscoveryPolicyStore.shared
    @ObservedObject private var iDeviceBattery = IDeviceBattery.shared
    @ObservedObject private var monitoring = MonitoringCoordinator.shared
    @StateObject private var inventoryModel = DeviceInventoryModel()
    @State private var selection: DeviceBrowserSelection?
    @State private var displayNameDraft = ""
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

        return VStack(alignment: .leading, spacing: 14) {
            SettingsPageHeader(
                title: "Devices",
                subtitle: "Manage known devices and inspect battery, connection, and discovery information."
            )

            deviceBrowser(
                known: known,
                nearbyApple: nearbyApple,
                suggestedBLE: suggestedBLE,
                otherBLE: otherBLE
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(
            maxWidth: 840,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .clipped()
        .onAppear {
            refreshInventory()
            syncDisplayNameDraft()
        }
        .onReceive(monitoring.$fiveSecondTick) { _ in
            refreshInventory()
        }
        .onChange(of: selection) { _, _ in
            syncDisplayNameDraft()
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

        let known = inventoryModel.devices
        let nearbyApple = nearbyIDeviceCandidates(known: known)
        let nearbyBLE = nearbyBLECandidates(known: known)

        let selectionIsValid: Bool
        switch selection {
        case .known(let id):
            selectionIsValid = known.contains { $0.id == id }
        case .iDevice(let id):
            selectionIsValid = nearbyApple.contains { $0.identifier == id }
        case .bluetooth(let id):
            selectionIsValid = nearbyBLE.contains { $0.identifier == id }
        case .none:
            selectionIsValid = false
        }

        guard !selectionIsValid else { return }

        if let first = known.first {
            selection = .known(first.id)
        } else if let first = nearbyApple.first {
            selection = .iDevice(first.identifier)
        } else if let first = nearbyBLE.first {
            selection = .bluetooth(first.identifier)
        } else {
            selection = nil
        }
    }

    @ViewBuilder
    private func deviceBrowser(
        known: [KnownDeviceSnapshot],
        nearbyApple: [IDeviceDiscoveryCandidate],
        suggestedBLE: [BLEDiscoveryCandidate],
        otherBLE: [BLEDiscoveryCandidate]
    ) -> some View {
        HStack(spacing: 0) {
            deviceBrowserSidebar(
                known: known,
                nearbyApple: nearbyApple,
                suggestedBLE: suggestedBLE,
                otherBLE: otherBLE
            )
            .frame(width: 270)

            Divider()

            deviceInspector(
                known: known,
                nearbyApple: nearbyApple,
                nearbyBLE: suggestedBLE + otherBLE,
                suggestedIDs: Set(suggestedBLE.map(\.identifier))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func deviceBrowserSidebar(
        known: [KnownDeviceSnapshot],
        nearbyApple: [IDeviceDiscoveryCandidate],
        suggestedBLE: [BLEDiscoveryCandidate],
        otherBLE: [BLEDiscoveryCandidate]
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                browserSectionHeader("Known Devices", count: known.count)

                if known.isEmpty {
                    Text("No known devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                } else {
                    ForEach(known) { device in
                        knownDeviceListRow(device)
                    }
                }

                Divider()
                    .padding(.vertical, 5)

                HStack(spacing: 6) {
                    Text("Nearby Devices")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(nearbyApple.count + suggestedBLE.count + otherBLE.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if !nearbyApple.isEmpty || !suggestedBLE.isEmpty || !otherBLE.isEmpty {
                        Button("Clear") {
                            iDeviceBattery.clearDiscoveryCandidates()
                            policyStore.clearNearby()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

                ForEach(nearbyApple) { candidate in
                    nearbyIDeviceListRow(candidate)
                }

                ForEach(suggestedBLE) { candidate in
                    nearbyBLEListRow(candidate, suggested: true)
                }

                if !otherBLE.isEmpty {
                    DisclosureGroup(isExpanded: $showOtherNearby) {
                        LazyVStack(spacing: 3) {
                            ForEach(otherBLE.prefix(30)) { candidate in
                                nearbyBLEListRow(candidate, suggested: false)
                            }
                        }
                        .padding(.top, 3)
                    } label: {
                        HStack(spacing: 5) {
                            Text("Other Bluetooth devices")
                                .font(.caption)
                            Text("\(otherBLE.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }

                if nearbyApple.isEmpty && suggestedBLE.isEmpty && otherBLE.isEmpty {
                    Text("No unknown nearby devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
            }
            .padding(6)
        }
        .scrollEdgeEffectHidden(true, for: .top)
    }

    @ViewBuilder
    private func browserSectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func knownDeviceListRow(_ device: KnownDeviceSnapshot) -> some View {
        let selected = selection == .known(device.id)
        Button {
            selection = .known(device.id)
        } label: {
            HStack(spacing: 9) {
                knownDeviceIcon(device, size: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(for: device))
                        .lineLimit(1)
                        .foregroundStyle(selected ? .white : .primary)

                    Text(knownDeviceListSummary(device))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(
                            selected
                                ? Color.white.opacity(0.82)
                                : Color.secondary
                        )
                }

                Spacer(minLength: 4)

                Circle()
                    .fill(knownDeviceStatusColor(device))
                    .frame(width: 7, height: 7)
                    .help(knownDeviceStatusDescription(device))
                    .accessibilityLabel(knownDeviceStatusDescription(device))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func nearbyIDeviceListRow(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        let selected = selection == .iDevice(candidate.identifier)
        Button {
            selection = .iDevice(candidate.identifier)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.system(size: 16))
                    .frame(width: 22)
                    .foregroundStyle(selected ? .white : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name ?? "Apple device")
                        .lineLimit(1)
                        .foregroundStyle(selected ? .white : .primary)
                    Text(iDevicePrimarySummary(candidate))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(selected ? Color.white.opacity(0.82) : .secondary)
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func nearbyBLEListRow(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
        let selected = selection == .bluetooth(candidate.identifier)
        Button {
            selection = .bluetooth(candidate.identifier)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(selected ? .white : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(candidate.name)
                            .lineLimit(1)
                        if suggested {
                            Text("Suggested")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                        }
                    }
                    .foregroundStyle(selected ? .white : .primary)

                    Text(candidatePrimarySummary(candidate))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(selected ? Color.white.opacity(0.82) : .secondary)
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func deviceInspector(
        known: [KnownDeviceSnapshot],
        nearbyApple: [IDeviceDiscoveryCandidate],
        nearbyBLE: [BLEDiscoveryCandidate],
        suggestedIDs: Set<String>
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id("device-inspector-top")

                Group {
                    switch selection {
                    case .known(let id):
                        if let device = known.first(where: { $0.id == id }) {
                            knownDeviceDetail(device)
                        }
                    case .iDevice(let id):
                        if let candidate = nearbyApple.first(where: { $0.identifier == id }) {
                            nearbyIDeviceDetail(candidate)
                        }
                    case .bluetooth(let id):
                        if let candidate = nearbyBLE.first(where: { $0.identifier == id }) {
                            nearbyBLEDetail(
                                candidate,
                                suggested: suggestedIDs.contains(id)
                            )
                        }
                    case .none:
                        ContentUnavailableView(
                            "Select a Device",
                            systemImage: "battery.100",
                            description: Text("Choose a device to inspect its battery and connection information.")
                        )
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollEdgeEffectHidden(true, for: .top)
            .onChange(of: selection) { _, _ in
                DispatchQueue.main.async {
                    proxy.scrollTo("device-inspector-top", anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func knownDeviceDetail(_ device: KnownDeviceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                knownDeviceIcon(device, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName(for: device))
                        .font(.title3.weight(.semibold))
                    Text(knownDeviceConnectionSummary(device))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let group = airPodsGroup(device) {
                batteryComponentCard(group)
            } else if let representative = representativeDevice(device),
                      representative.hasBattery {
                detailedBatteryView(representative)
            }

            detailSection("Device Settings") {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Display Name")
                    Spacer()
                    TextField(device.name, text: $displayNameDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 150, idealWidth: 190, maxWidth: 230)
                        .onChange(of: displayNameDraft) { _, value in
                            saveDisplayName(value, for: device)
                        }
                    if DeviceDisplayNameStore.override(
                        forKey: displayNameKey(for: device)
                    ) != nil {
                        Button("Reset") {
                            DeviceDisplayNameStore.setOverride(
                                nil,
                                forKey: displayNameKey(for: device)
                            )
                            displayNameDraft = ""
                        }
                        .controlSize(.small)
                    }
                }

                if let ble = device.ble {
                    Divider().opacity(0.5)
                    HStack {
                        Text("Battery Access")
                        Spacer()
                        policyValueMenu(
                            name: device.name,
                            currentPolicy: ble.policy,
                            hasOverrides: !ble.exactRules.isEmpty
                        )
                    }

                    if !ble.exactRules.isEmpty {
                        Text("One or more Bluetooth identities override the device-level battery-access policy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            plainDetailSection("Device Information") {
                deviceInformationRows(device)
            }

            advancedTechnicalDetails(device)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func nearbyIDeviceDetail(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "iphone")
                    .font(.system(size: 30))
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name ?? "Apple device")
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 5) {
                        ForEach(sortedIDeviceSources(candidate.sources), id: \.self) { source in
                            sourceBadge(source.rawValue)
                        }
                    }
                }
                Spacer()
            }

            plainDetailSection("Discovery Information") {
                iDeviceDetails(candidate)
            }

            nearbyTechnicalDetails(
                id: "idevice:" + candidate.identifier
            ) {
                iDeviceTechnicalDetails(candidate)
            }
        }
    }

    @ViewBuilder
    private func nearbyBLEDetail(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 26))
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 5) {
                        sourceBadge("Bluetooth")
                        if suggested {
                            sourceBadge("Suggested")
                        }
                    }
                }
                Spacer()
            }

            detailSection("Device Settings") {
                HStack {
                    Text("Battery Access")
                    Spacer()
                    reviewMenu(candidate, suggested: suggested)
                }
            }

            plainDetailSection("Discovery Information") {
                candidateDetails(candidate, suggested: suggested)
            }

            nearbyTechnicalDetails(
                id: "ble:" + candidate.identifier
            ) {
                candidateTechnicalDetails(candidate)
            }
        }
    }

    @ViewBuilder
    private func detailedBatteryView(_ device: Device) -> some View {
        let estimate = BatteryHistoryStore.shared.estimate(for: device)
        HStack(alignment: .center, spacing: 18) {
            BatteryRingSurfaceCell(
                item: device,
                diameter: 86,
                showPercentage: true,
                showLabel: false,
                estimate: estimate
            )

            if let estimate {
                VStack(alignment: .leading, spacing: 3) {
                    Text(estimateDurationText(estimate))
                        .font(.headline)
                    Text(estimateEndpointText(estimate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Estimated from recent battery history")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func batteryComponentCard(_ group: AirPodsBatteryGroup) -> some View {
        let presentation = AirBatteryModel.logicalPresentations(
            from: group.components,
            mergeEarbuds: twsMergeEnabled,
            mergeThreshold: twsMerge
        ).first

        if let presentation {
            VStack(alignment: .leading, spacing: 8) {
                Text("Battery Components")
                    .font(.subheadline.weight(.semibold))

                HStack(alignment: .top, spacing: 18) {
                    ForEach(presentation.components) { component in
                        let estimate = BatteryHistoryStore.shared.estimate(
                            for: component.device
                        )
                        VStack(spacing: 3) {
                            BatteryRingSurfaceCell(
                                item: component.device,
                                diameter: 68,
                                showPercentage: true,
                                showLabel: true,
                                estimate: estimate
                            )
                            if let estimate {
                                Text(estimateShortText(estimate))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.secondary.opacity(0.035))
            )
        }
    }

    @ViewBuilder
    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.045))
            )
        }
    }

    @ViewBuilder
    private func plainDetailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 5) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func advancedTechnicalDetails(_ device: KnownDeviceSnapshot) -> some View {
        let expanded = technicalExpandedKnown.contains(device.id)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if expanded {
                    technicalExpandedKnown.remove(device.id)
                } else {
                    technicalExpandedKnown.insert(device.id)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Advanced Technical Details")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                expanded
                    ? "Collapse Advanced Technical Details"
                    : "Expand Advanced Technical Details"
            )

            if expanded {
                knownDeviceTechnicalDetails(device)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func nearbyTechnicalDetails<Content: View>(
        id: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let expanded = technicalExpandedNearby.contains(id)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if expanded {
                    technicalExpandedNearby.remove(id)
                } else {
                    technicalExpandedNearby.insert(id)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Advanced Technical Details")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                content()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func knownDeviceIcon(_ device: KnownDeviceSnapshot, size: CGFloat) -> some View {
        if let representative = representativeDevice(device) {
            Image(getDeviceIcon(representative))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: size * 0.65))
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func deviceInformationRows(_ device: KnownDeviceSnapshot) -> some View {
        if let representative = representativeDevice(device) {
            detailRow("Detected name", device.name)
            detailRow("Product Type", humanReadableType(device))
            if let model = representative.deviceModel, !model.isEmpty {
                detailRow("Model", model)
            }
            detailRow("Identifier", representative.deviceID)
            detailRow(
                "Connected via",
                sortedSources(device.sources)
                    .map(\.rawValue)
                    .joined(separator: " · ")
            )
            detailRow("Last updated", relativeAge(representative.lastUpdate))
        } else {
            detailRow("Detected name", device.name)
            detailRow(
                "Connected via",
                sortedSources(device.sources)
                    .map(\.rawValue)
                    .joined(separator: " · ")
            )
            detailRow("Battery", "No retained battery reading")
        }
    }

    @ViewBuilder
    private func knownDeviceTechnicalDetails(_ device: KnownDeviceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if let representative = representativeDevice(device) {
                if let mobileID = representative.mobileDeviceID, !mobileID.isEmpty {
                    detailRow("Mobile UDID", mobileID)
                }
                if let bleID = representative.bleDeviceID, !bleID.isEmpty {
                    detailRow("Bluetooth ID", bleID)
                }
                if let source = representative.batterySource {
                    detailRow("Last battery via", batterySourceLabel(source))
                }

                let sampleCount = BatteryHistoryStore.shared
                    .samples(for: representative)
                    .count
                detailRow("ETA history", "\(sampleCount) recent samples")
            }

            if !device.iDeviceCandidates.isEmpty {
                Divider().opacity(0.5)
                Text("Apple device connections")
                    .font(.caption.weight(.semibold))
                ForEach(device.iDeviceCandidates) { candidate in
                    iDeviceTechnicalDetails(candidate)
                }
            }

            if let ble = device.ble {
                if !ble.identities.isEmpty {
                    Divider().opacity(0.5)
                    Text("Bluetooth identities")
                        .font(.caption.weight(.semibold))
                    ForEach(ble.identities) { candidate in
                        identityDetail(candidate, logicalPolicy: ble.policy)
                    }
                } else if device.sources.contains(.bluetooth) {
                    Text("Bluetooth device not observed during this launch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func policyValueMenu(
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
                currentPolicy?.title ??
                    (hasOverrides ? "Per identity" : "Discovery default")
            )
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
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
    private func candidateDetails(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
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
    private func candidateTechnicalDetails(_ candidate: BLEDiscoveryCandidate) -> some View {
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
    private func iDeviceDetails(_ candidate: IDeviceDiscoveryCandidate) -> some View {
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
    private func iDeviceTechnicalDetails(_ candidate: IDeviceDiscoveryCandidate) -> some View {
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
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func knownDeviceListSummary(_ device: KnownDeviceSnapshot) -> String {
        if let group = airPodsGroup(device),
           let presentation = AirBatteryModel.logicalPresentations(
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

    private func knownDeviceConnectionSummary(_ device: KnownDeviceSnapshot) -> String {
        let sources = sortedSources(device.sources).map(\.rawValue)
        let sourceText = sources.isEmpty ? "Known device" : sources.joined(separator: " · ")

        guard let representative = representativeDevice(device) else {
            return sourceText + " · no retained battery reading"
        }
        return sourceText + " · " + relativeAge(representative.lastUpdate)
    }

    private func knownDeviceStatusColor(_ device: KnownDeviceSnapshot) -> Color {
        guard let representative = representativeDevice(device) else {
            return .secondary.opacity(0.45)
        }
        let age = Date().timeIntervalSince1970 - representative.lastUpdate
        return age < 120 ? .green : .secondary.opacity(0.55)
    }

    private func knownDeviceStatusDescription(_ device: KnownDeviceSnapshot) -> String {
        guard let representative = representativeDevice(device) else {
            return "No retained battery reading"
        }
        let age = Date().timeIntervalSince1970 - representative.lastUpdate
        return age < 120
            ? "Recently observed"
            : "Last observed " + relativeAge(representative.lastUpdate)
    }

    private func humanReadableType(_ device: KnownDeviceSnapshot) -> String {
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

    private func displayName(for device: KnownDeviceSnapshot) -> String {
        DeviceDisplayNameStore.displayName(
            forKey: displayNameKey(for: device),
            fallback: device.name
        )
    }

    private func displayNameKey(for device: KnownDeviceSnapshot) -> String {
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

    private func syncDisplayNameDraft() {
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

    private func saveDisplayName(_ value: String, for device: KnownDeviceSnapshot) {
        DeviceDisplayNameStore.setOverride(
            value,
            forKey: displayNameKey(for: device)
        )
    }

    private func estimateShortText(_ estimate: BatteryTimeEstimate) -> String {
        let duration = formattedDuration(estimate.duration)
        return estimate.kind == .charging
            ? "\(duration) to full"
            : "\(duration) left"
    }

    private func estimateDurationText(_ estimate: BatteryTimeEstimate) -> String {
        "~" + estimateShortText(estimate)
    }

    private func estimateEndpointText(_ estimate: BatteryTimeEstimate) -> String {
        let time = estimate.endDate.formatted(
            date: .omitted,
            time: .shortened
        )
        return estimate.kind == .charging
            ? "Full around \(time)"
            : "Empty around \(time)"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    private func nearbyIDeviceCandidates(known: [KnownDeviceSnapshot]) -> [IDeviceDiscoveryCandidate] {
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

    private func nearbyBLECandidates(known: [KnownDeviceSnapshot]) -> [BLEDiscoveryCandidate] {
        let knownNames = Set(known.map { inventoryKey($0.name) })
        return policyStore.nearbyCandidates.filter {
            !knownNames.contains(inventoryKey($0.name))
        }
    }

    private func candidateSuggestionReason(_ candidate: BLEDiscoveryCandidate) -> String {
        if candidate.hasPassiveBatteryData { return "Battery data was advertised" }
        if candidate.advertisesBatteryService { return "Battery service was advertised" }
        if candidate.matchesPairedName { return "Matches a paired accessory" }
        if candidate.lastProbeResult != nil { return "Previously queried" }
        return "Stable nearby device"
    }

    private func iDevicePrimarySummary(_ candidate: IDeviceDiscoveryCandidate) -> String {
        var parts: [String] = []
        if let type = candidate.deviceType, !type.isEmpty { parts.append(type) }
        if let model = candidate.model, !model.isEmpty { parts.append(model) }
        parts.append(candidate.batteryReadable ? "battery readable" : "no battery record yet")
        parts.append(relativeAge(candidate.lastSeen.timeIntervalSince1970))
        return parts.joined(separator: " · ")
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

    private func sortedSources(_ sources: Set<DeviceInventorySource>) -> [DeviceInventorySource] {
        sources.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func sortedIDeviceSources(_ sources: Set<IDeviceConnectionSource>) -> [IDeviceConnectionSource] {
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

    private func batterySourceLabel(_ source: DeviceObservationSource) -> String {
        switch source {
        case .ble: return "Bluetooth"
        case .libimobiledevice: return "Network / USB"
        }
    }
}

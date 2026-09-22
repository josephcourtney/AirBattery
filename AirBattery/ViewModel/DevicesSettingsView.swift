import AppKit
import SwiftUI

struct DevicesView: View {
    @ObservedObject private var policyStore = BLEDiscoveryPolicyStore.shared
    @ObservedObject private var iDeviceBattery = IDeviceBattery.shared
    @ObservedObject private var monitoring = MonitoringCoordinator.shared
    @StateObject private var inventoryModel = DeviceInventoryModel()
    @State private var selectedKnownID: String?
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
                SettingsPageHeader(
                    title: "Devices",
                    subtitle: "Manage known devices and inspect battery, connection, and discovery information."
                )

                knownDevicesBrowser(known)

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

        if selectedKnownID == nil ||
            !inventoryModel.devices.contains(where: { $0.id == selectedKnownID }) {
            selectedKnownID = inventoryModel.devices.first?.id
        }
    }

    @ViewBuilder
    private func knownDevicesBrowser(
        _ known: [KnownDeviceSnapshot]
    ) -> some View {
        if known.isEmpty {
            SGroupBox(label: "Known Devices") {
                emptyRow("No known devices.")
            }
        } else {
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(known) { device in
                            knownDeviceListRow(device)
                        }
                    }
                    .padding(6)
                }
                .frame(width: 236)

                Divider()

                ScrollView {
                    if let selected = known.first(where: {
                        $0.id == selectedKnownID
                    }) {
                        knownDeviceDetail(selected)
                            .padding(16)
                    } else {
                        ContentUnavailableView(
                            "Select a Device",
                            systemImage: "battery.100",
                            description: Text(
                                "Choose a known device to inspect its battery and connection information."
                            )
                        )
                        .padding(24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 360, idealHeight: 430, maxHeight: 520)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.12))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private func knownDeviceListRow(
        _ device: KnownDeviceSnapshot
    ) -> some View {
        let selected = selectedKnownID == device.id
        Button {
            selectedKnownID = device.id
        } label: {
            HStack(spacing: 9) {
                knownDeviceIcon(device, size: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
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
    private func knownDeviceDetail(
        _ device: KnownDeviceSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                knownDeviceIcon(device, size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
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
                HStack {
                    BatteryRingSurfaceCell(
                        item: representative,
                        diameter: 64,
                        showPercentage: true,
                        showLabel: false
                    )
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            if let ble = device.ble {
                detailSection("Device Settings") {
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
                        Text(
                            "One or more Bluetooth identities override the device-level battery-access policy."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            detailSection("Device Information") {
                deviceInformationRows(device)
            }

            DisclosureGroup(
                isExpanded: Binding(
                    get: { technicalExpandedKnown.contains(device.id) },
                    set: { expanded in
                        if expanded {
                            technicalExpandedKnown.insert(device.id)
                        } else {
                            technicalExpandedKnown.remove(device.id)
                        }
                    }
                )
            ) {
                knownDeviceTechnicalDetails(device)
                    .padding(.top, 8)
            } label: {
                Label(
                    "Advanced Technical Details",
                    systemImage: "wrench.and.screwdriver"
                )
                .font(.subheadline.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func knownDeviceIcon(
        _ device: KnownDeviceSnapshot,
        size: CGFloat
    ) -> some View {
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
    private func batteryComponentCard(
        _ group: AirPodsBatteryGroup
    ) -> some View {
        let presentation = AirBatteryModel.logicalPresentations(
            from: group.components,
            mergeEarbuds: twsMergeEnabled,
            mergeThreshold: twsMerge
        ).first

        if let presentation {
            HStack(spacing: 22) {
                ForEach(presentation.components) { component in
                    BatteryRingSurfaceCell(
                        item: component.device,
                        diameter: 58,
                        showPercentage: true,
                        showLabel: true
                    )
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.secondary.opacity(0.05))
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
    private func deviceInformationRows(
        _ device: KnownDeviceSnapshot
    ) -> some View {
        if let representative = representativeDevice(device) {
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
            detailRow(
                "Last updated",
                relativeAge(representative.lastUpdate)
            )
        } else {
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
    private func knownDeviceTechnicalDetails(
        _ device: KnownDeviceSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if let representative = representativeDevice(device) {
                if let mobileID = representative.mobileDeviceID,
                   !mobileID.isEmpty {
                    detailRow("Mobile UDID", mobileID)
                }
                if let bleID = representative.bleDeviceID,
                   !bleID.isEmpty {
                    detailRow("Bluetooth ID", bleID)
                }
                if let source = representative.batterySource {
                    detailRow("Last battery via", batterySourceLabel(source))
                }
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
                    Text(
                        "Bluetooth device not observed during this launch."
                    )
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
                    policyStore.setLogicalPolicy(
                        name: name,
                        policy: policy
                    )
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

    private func knownDeviceListSummary(
        _ device: KnownDeviceSnapshot
    ) -> String {
        if let group = airPodsGroup(device) {
            if let caseDevice = group.caseDevice {
                return "Case \(caseDevice.batteryLevel)%"
            }
            if let first = group.components.first {
                return "Battery \(first.batteryLevel)%"
            }
        }

        if let representative = representativeDevice(device) {
            return representative.hasBattery
                ? "\(representative.batteryLevel)% · " +
                    relativeAge(representative.lastUpdate)
                : relativeAge(representative.lastUpdate)
        }

        return "No battery reading"
    }

    private func knownDeviceConnectionSummary(
        _ device: KnownDeviceSnapshot
    ) -> String {
        let sources = sortedSources(device.sources).map(\.rawValue)
        let sourceText = sources.isEmpty
            ? "Known device"
            : sources.joined(separator: " · ")

        guard let representative = representativeDevice(device) else {
            return sourceText + " · no retained battery reading"
        }
        return sourceText + " · " + relativeAge(representative.lastUpdate)
    }

    private func knownDeviceStatusColor(
        _ device: KnownDeviceSnapshot
    ) -> Color {
        guard let representative = representativeDevice(device) else {
            return .secondary.opacity(0.45)
        }
        let age = Date().timeIntervalSince1970 - representative.lastUpdate
        return age < 120 ? .green : .secondary.opacity(0.55)
    }

    private func humanReadableType(
        _ device: KnownDeviceSnapshot
    ) -> String {
        if airPodsGroup(device) != nil {
            return "AirPods"
        }
        guard let representative = representativeDevice(device) else {
            return "Device"
        }

        let type = representative.deviceType.lowercased()
        if type.contains("iphone") { return "iPhone" }
        if type.contains("ipad") { return "iPad" }
        if type.contains("watch") { return "Apple Watch" }
        if type.contains("keyboard") { return "Keyboard" }
        if type.contains("mouse") || representative.deviceName
            .localizedCaseInsensitiveContains("MX Ergo") {
            return "Pointing Device"
        }
        if type.contains("mac") ||
            representative.deviceID == "@MacInternalBattery" {
            return "Mac"
        }
        return representative.deviceType
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

    private func toggleNearby(_ id: String) {
        if expandedNearby.contains(id) {
            expandedNearby.remove(id)
        } else {
            expandedNearby.insert(id)
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
                    Image(systemName: "chevron.right.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(
                            .degrees(configuration.isExpanded ? 90 : 0)
                        )
                        .frame(width: 28, height: 30)
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
                    .transition(.opacity)
            }
        }
        .animation(
            .easeInOut(duration: 0.14),
            value: configuration.isExpanded
        )
    }
}

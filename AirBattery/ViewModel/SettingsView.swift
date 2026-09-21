//
//  SettingsView.swift
//  AirBattery
//
//  Created by apple on 2023/9/7.
//

import SwiftUI
import WidgetKit
import AppKit

struct SettingsView: View {
    @State private var selectedItem: String? = "General"
    @AppStorage("showDebug") var showDebug: Bool = false
    @ObservedObject private var discoveryPolicy = BLEDiscoveryPolicyStore.shared

    var body: some View {
        NavigationView {
            List(selection: $selectedItem) {
                NavigationLink(destination: GeneralView(), tag: "General", selection: $selectedItem) {
                    Label("General", systemImage: "gearshape")
                }
                NavigationLink(destination: DisplayView(), tag: "Display", selection: $selectedItem) {
                    Label("Display", systemImage: "rectangle.3.group")
                }
                NavigationLink(destination: DevicesView(), tag: "Devices", selection: $selectedItem) {
                    HStack {
                        Label("Devices", systemImage: "rectangle.stack")
                        Spacer()
                        if discoveryPolicy.reviewCount > 0 {
                            Text("\(discoveryPolicy.reviewCount)")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.secondary.opacity(0.18)))
                                .accessibilityLabel("\(discoveryPolicy.reviewCount) devices need review")
                        }
                    }
                }
                NavigationLink(destination: DiscoveryView(), tag: "Discovery", selection: $selectedItem) {
                    Label("Discovery", systemImage: "antenna.radiowaves.left.and.right")
                }
                NavigationLink(destination: NearcastView(), tag: "Nearcast", selection: $selectedItem) {
                    Label("Nearcast", systemImage: "network")
                }
                if showDebug {
                    NavigationLink(destination: DebugView(selectedItem: $selectedItem), tag: "Debug", selection: $selectedItem) {
                        Label("Debug", systemImage: "ladybug")
                    }
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
        }
        .frame(
            minWidth: 760,
            idealWidth: 960,
            maxWidth: .infinity,
            minHeight: 540,
            idealHeight: 720,
            maxHeight: .infinity
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("AirBattery Settings")
    }
}

struct GeneralView: View {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showDebug") var showDebug: Bool = false
    @State private var debugCount: Int = 0
    @State private var cltInstalled: Bool = false
    
    var body: some View {
        SForm {
            SGroupBox(label: "Startup") {
                SToggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if !ensureLoginItem(enabled: newValue) {
                            DispatchQueue.main.async { launchAtLogin.toggle() }
                        }
                    }
            }
            SGroupBox(label: "Tools") {
                SButton("Command Line Tool", buttonTitle: cltInstalled ? "Uninstall" : "Install",
                        tips: "After installation, you can run \"airbattery\" in your terminal to list all devices.") {
                    if cltInstalled {
                        CommandLineTool.uninstall { updateCTL() }
                    } else {
                        CommandLineTool.install { updateCTL() }
                    }
                }.onAppear { cltInstalled = CommandLineTool.isInstalled() }
            }
            SGroupBox(label: "Update") { UpdaterSettingsView(updater: updaterController.updater) }
            VStack(spacing: 8) {
                CheckForUpdatesView(updater: updaterController.updater)
                if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("AirBattery v\(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            debugCount += 1
                            if debugCount > 9 {
                                debugCount = 0
                                showDebug.toggle()
                            }
                        }
                }
            }
        }
    }
    func updateCTL() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cltInstalled = CommandLineTool.isInstalled()
        }
    }
}

struct DiscoveryView: View {
    @AppStorage("ideviceOverBLE") private var ideviceOverBLE = false
    @AppStorage("readBTDevice") private var readBTDevice = true
    @AppStorage("readBLEDevice") private var readBLEDevice = false
    @AppStorage("bleDiscoveryMode") private var bleDiscoveryMode = BLEDiscoveryMode.review.rawValue
    @AppStorage("readPencil") private var readPencil = false
    @AppStorage("readIDevice") private var readIDevice = true
    @AppStorage("readBTHID") private var readBTHID = true
    @AppStorage("updateInterval") private var updateInterval = 1
    @AppStorage("disappearTime") private var disappearTime = 20

    private var discoveryMode: BLEDiscoveryMode {
        BLEDiscoveryMode(rawValue: bleDiscoveryMode) ?? .review
    }

    var body: some View {
        ScrollView {
            SForm(noSpacer: true) {
                SGroupBox(label: "Device Sources") {
                    sourceHeading("Apple mobile devices")
                    SToggle(
                        "Network discovery",
                        isOn: $readIDevice,
                        tips: "Find trusted iPhone, iPad, Apple Watch, Vision Pro, and other Apple devices over the local network."
                    )
                    Divider().opacity(0.5)
                    SToggle(
                        "Bluetooth discovery",
                        isOn: $ideviceOverBLE,
                        tips: "Find supported iPhone and cellular iPad devices over Bluetooth. Active connections follow the policy below."
                    )

                    Divider().padding(.vertical, 3)
                    sourceHeading("Bluetooth accessories")
                    SToggle(
                        "Paired and system-known devices",
                        isOn: $readBTDevice,
                        tips: "Read battery information exposed by macOS and passive Apple/Beats Bluetooth advertisements."
                    )
                    Divider().opacity(0.5)
                    SToggle(
                        "Additional macOS Bluetooth devices",
                        isOn: $readBTHID,
                        tips: "Use macOS Bluetooth system information and logs to find additional third-party devices. Updates commonly occur after reconnect or wake."
                    )
                    Divider().opacity(0.5)
                    SToggle(
                        "Nearby BLE advertisements",
                        isOn: $readBLEDevice,
                        tips: "Observe nearby BLE advertisements. Observation is passive; active battery queries follow the connection policy below."
                    )
                }

                SGroupBox(label: "Active Connections") {
                    SPicker(
                        "New BLE devices",
                        selection: $bleDiscoveryMode,
                        tips: "Controls whether AirBattery may actively connect to a newly observed BLE device. Passive battery advertisements do not require a connection."
                    ) {
                        ForEach(BLEDiscoveryMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .disabled(!readBLEDevice && !ideviceOverBLE)
                    HStack {
                        Text(discoveryMode.detail)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                SGroupBox(label: "Experimental") {
                    HStack(spacing: 6) {
                        Text("Apple Pencil from iPad")
                        Text("Experimental")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                        Spacer()
                        SInfoButton(tips: "Read the battery status of a connected Apple Pencil through your iPad. Initial discovery may take 10 minutes or longer and may increase iPad battery use.")
                        Toggle("", isOn: $readPencil)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                            .frame(width: 32)
                    }
                    .frame(height: 18)
                }

                SGroupBox(label: "Refresh & Retention") {
                    VStack(spacing: 2) {
                        SSteper("Refresh interval (min)", value: $updateInterval, min: 1, max: 99)
                        if updateDelay != updateInterval {
                            HStack {
                                Text("Relaunch AirBattery to apply this change")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    Divider().opacity(0.5)
                    SPicker(
                        "Keep offline devices",
                        selection: $disappearTime,
                        tips: "How long a device remains available after AirBattery stops receiving fresh battery information."
                    ) {
                        Text("Never").tag(Int(UInt32.max))
                        Text("20 minutes").tag(20)
                        Text("40 minutes").tag(40)
                        Text("60 minutes").tag(60)
                    }
                }

                SGroupBox(label: "Filtering") {
                    NameRulesEditor()
                }
            }
        }
    }

    @ViewBuilder
    private func sourceHeading(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

private enum DeviceInventorySource: String, Hashable {
    case builtIn = "Built-in"
    case network = "Network"
    case usb = "USB"
    case bluetooth = "Bluetooth"
    case nearcast = "Nearcast"

    var sortOrder: Int {
        switch self {
        case .builtIn: return 0
        case .network: return 1
        case .usb: return 2
        case .bluetooth: return 3
        case .nearcast: return 4
        }
    }
}

private struct KnownDeviceSnapshot: Identifiable {
    let id: String
    var name: String
    var devices: [Device] = []
    var sources: Set<DeviceInventorySource> = []
    var ble: BLELogicalDeviceSnapshot?
    var iDeviceCandidates: [IDeviceDiscoveryCandidate] = []
    var isBuiltIn = false
}

struct DevicesView: View {
    @ObservedObject private var policyStore = BLEDiscoveryPolicyStore.shared
    @ObservedObject private var iDeviceBattery = IDeviceBattery.shared
    @State private var expandedKnown: Set<String> = []
    @State private var expandedNearby: Set<String> = []
    @State private var showOtherNearby = false
    @State private var refreshDate = Date()
    @AppStorage("twsMergeEnabled") private var twsMergeEnabled = true
    @AppStorage("twsMerge") private var twsMerge = 5

    var body: some View {
        let known = knownDevices
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
                            }
                        }
                    }
                }

            }
        }
        .onReceive(dockTimer) { _ in
            refreshDate = Date()
        }
    }

    private var knownDevices: [KnownDeviceSnapshot] {
        _ = refreshDate
        var inventory: [String: KnownDeviceSnapshot] = [:]

        func merge(
            name: String,
            device: Device? = nil,
            source: DeviceInventorySource? = nil,
            keyOverride: String? = nil,
            builtIn: Bool = false
        ) {
            let key = keyOverride ?? inventoryKey(name)
            var snapshot = inventory[key] ?? KnownDeviceSnapshot(id: key, name: name)
            if let device = device,
               !snapshot.devices.contains(where: {
                   $0.deviceID == device.deviceID &&
                   $0.deviceType == device.deviceType &&
                   $0.deviceName == device.deviceName
               }) {
                snapshot.devices.append(device)
            }
            if let source = source {
                snapshot.sources.insert(source)
            }
            snapshot.isBuiltIn = snapshot.isBuiltIn || builtIn
            inventory[key] = snapshot
        }

        let internalStatus = InternalBattery.status
        if internalStatus.hasBattery {
            let mac = ib2ab(internalStatus)
            merge(
                name: mac.deviceName,
                device: mac,
                source: .builtIn,
                keyOverride: "builtin:" + inventoryKey(mac.deviceName),
                builtIn: true
            )
        }

        for device in AirBatteryModel.Devices {
            let logicalName = AirBatteryModel.airPodsBaseName(for: device) ?? device.deviceName
            merge(name: logicalName, device: device)
        }

        for logical in policyStore.knownLogicalDevices {
            let key = inventoryKey(logical.name)
            var snapshot = inventory[key] ?? KnownDeviceSnapshot(id: key, name: logical.name)
            snapshot.sources.insert(.bluetooth)
            snapshot.ble = logical
            inventory[key] = snapshot
        }

        for url in getFiles(withExtension: "json", in: ncFolder) {
            for device in AirBatteryModel.ncGetAll(url: url) {
                let logicalName = AirBatteryModel.airPodsBaseName(for: device) ?? device.deviceName
                merge(name: logicalName, device: device, source: .nearcast)
            }
        }

        for key in Array(inventory.keys) {
            guard var snapshot = inventory[key] else { continue }

            let idCandidates = iDeviceBattery.discoveryCandidates.filter { candidate in
                snapshot.devices.contains(where: { $0.deviceID == candidate.identifier }) ||
                candidate.name.map { inventoryKey($0) == inventoryKey(snapshot.name) } == true ||
                snapshot.devices.contains(where: { device in
                    !device.parentName.isEmpty &&
                    candidate.name.map {
                        inventoryKey($0) == inventoryKey(device.parentName)
                    } == true
                })
            }
            snapshot.iDeviceCandidates = idCandidates
            for candidate in idCandidates {
                if candidate.sources.contains(.network) { snapshot.sources.insert(.network) }
                if candidate.sources.contains(.usb) { snapshot.sources.insert(.usb) }
            }

            let bleIdentities = policyStore.candidates.filter {
                inventoryKey($0.name) == inventoryKey(snapshot.name)
            }
            if !bleIdentities.isEmpty {
                snapshot.sources.insert(.bluetooth)
                if snapshot.ble == nil {
                    let exactRules = policyStore.rules.filter {
                        inventoryKey($0.name) == inventoryKey(snapshot.name)
                    }
                    snapshot.ble = BLELogicalDeviceSnapshot(
                        key: inventoryKey(snapshot.name),
                        name: snapshot.name,
                        policy: policyStore.logicalPolicy(name: snapshot.name),
                        identities: bleIdentities,
                        exactRules: exactRules
                    )
                }
            }

            if snapshot.sources.isEmpty {
                if snapshot.devices.contains(where: { isAppleMobileDevice($0) }) {
                    snapshot.sources.insert(.network)
                } else if !snapshot.devices.isEmpty {
                    snapshot.sources.insert(.bluetooth)
                }
            }

            inventory[key] = snapshot
        }

        return inventory.values.sorted {
            if $0.isBuiltIn != $1.isBuiltIn { return $0.isBuiltIn }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func nearbyIDeviceCandidates(
        known: [KnownDeviceSnapshot]
    ) -> [IDeviceDiscoveryCandidate] {
        let knownIDs = Set(known.flatMap(\.devices).map(\.deviceID))
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
                            .foregroundColor(.secondary)
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
                        detailRow("Type", representative.deviceType)
                        if let model = representative.deviceModel, !model.isEmpty {
                            detailRow("Model", model)
                        }
                        detailRow("Identifier", representative.deviceID)
                        detailRow("Last update", relativeAge(representative.lastUpdate))
                        if !representative.parentName.isEmpty {
                            detailRow("Parent", representative.parentName)
                        }
                    }
                } else {
                    Text("Known from a saved Bluetooth policy; no retained battery record.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !device.iDeviceCandidates.isEmpty {
                    Divider().opacity(0.5)
                    Text("Apple device discovery")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    ForEach(device.iDeviceCandidates) { candidate in
                        iDeviceDetails(candidate)
                    }
                }

                if let ble = device.ble {
                    if !ble.identities.isEmpty {
                        Divider().opacity(0.5)
                        Text("Bluetooth identities")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        ForEach(ble.identities) { candidate in
                            identityDetail(candidate, logicalPolicy: ble.policy)
                        }
                    } else if device.sources.contains(.bluetooth) {
                        Divider().opacity(0.5)
                        Text("Bluetooth device not observed during this launch.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !ble.exactRules.isEmpty {
                        Text("Identity-specific overrides take precedence over the device rule.")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                Spacer()
                if let ble = device.ble {
                    logicalPolicyMenu(name: device.name, currentPolicy: ble.policy)
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
            iDeviceDetails(candidate)
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
                Spacer()
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
            candidateDetails(candidate)
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
                Spacer()
                reviewMenu(candidate, suggested: suggested)
            }
        }
    }

    @ViewBuilder
    private func sourceBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    @ViewBuilder
    private func logicalPolicyMenu(
        name: String,
        currentPolicy: BLEDevicePolicy?
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
            Text(currentPolicy?.title ?? "Per identity")
                .frame(minWidth: 82, alignment: .trailing)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private func reviewMenu(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
        Menu {
            Button("Allow battery queries") {
                policyStore.setLogicalPolicy(name: candidate.name, policy: .allow)
            }
            Button("Keep passive") {
                policyStore.setLogicalPolicy(name: candidate.name, policy: .observe)
            }
            Button("Ignore") {
                policyStore.setLogicalPolicy(name: candidate.name, policy: .ignore)
            }
        } label: {
            Text(suggested ? "Review" : "Set policy")
                .frame(minWidth: 70, alignment: .trailing)
        }
        .menuStyle(.borderlessButton)
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
                    Text(
                        policyStore.exactPolicy(identifier: candidate.identifier)?.title ??
                        logicalPolicy?.title ??
                        "Default"
                    )
                    .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            candidateDetails(candidate)
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func candidateDetails(_ candidate: BLEDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            detailRow(
                "Signal",
                "\(signalLabel(candidate.displayRSSI)) · \(candidate.displayRSSI) dBm " +
                "(raw \(candidate.rssi) dBm)"
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
            detailRow("Last seen", relativeAge(candidate.lastSeen.timeIntervalSince1970))
            detailRow("Connection", candidate.isConnectable ? "Connectable" : "Not connectable")
            if let result = candidate.lastProbeResult {
                detailRow("Last query", result)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func iDeviceDetails(_ candidate: IDeviceDiscoveryCandidate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            detailRow(
                "Connection",
                sortedIDeviceSources(candidate.sources).map(\.rawValue).joined(separator: " + ")
            )
            if let type = candidate.deviceType, !type.isEmpty {
                detailRow("Type", type)
            }
            if let model = candidate.model, !model.isEmpty {
                detailRow("Model", model)
            }
            detailRow("Identifier", candidate.identifier)
            detailRow("Last seen", relativeAge(candidate.lastSeen.timeIntervalSince1970))
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
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 82, alignment: .leading)
            Text(value)
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
        parts.append("\(signalLabel(candidate.displayRSSI)) (\(candidate.displayRSSI) dBm)")
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

    private func isAppleMobileDevice(_ device: Device) -> Bool {
        ["iPhone", "iPad", "iPod", "Watch", "ApplePencil", "Pencil"]
            .contains(device.deviceType)
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

struct NearcastView: View {
    @AppStorage("nearCast") var nearCast = false
    @AppStorage("ncGroupID") var ncGroupID = ""
    @State var debug: Bool = false
    
    var body: some View {
        SForm {
            SGroupBox(label: "Nearcast") {
                SToggle("Enable Nearcast", isOn: $nearCast)
                    .onChange(of: nearCast) { newValue in
                        if newValue {
                            if ncGroupID != "" && isGroudIDValid(id: ncGroupID) {
                                netcastService.resume()
                            } else {
                                DispatchQueue.main.async { nearCast = false; ncGroupID = "" }
                                _ = createAlert(
                                    title: "Invalid group ID".local,
                                    message: "Please create or enter a valid Group ID before use!",
                                    button1: "OK".local
                                ).runModal()
                            }
                        } else {
                            netcastService.stop()
                        }
                    }
                Divider().opacity(0.5)
                HStack(spacing: 4) {
                    SField("Group ID", text: $ncGroupID).disabled(nearCast)
                    Button(action: {
                        ncGroupID = "nc-" + randomString(length: 20)
                    }, label: {
                        if ncGroupID != "" {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 15, weight: .light))
                        } else {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 15, weight: .light))
                        }
                    })
                    .buttonStyle(.plain)
                    .disabled(nearCast)
                    Button(action: {
                        if ncGroupID != "" && isGroudIDValid(id: ncGroupID) {
                            copyToClipboard(ncGroupID)
                            _ = createAlert(title: "Group ID Copied".local,
                                            message: String(format: "Group ID has been copied to the clipboard.".local, ncGroupID),
                                            button1: "OK".local).runModal()
                        } else {
                            DispatchQueue.main.async { ncGroupID = "" }
                            _ = createAlert(
                                title: "Invalid group ID".local,
                                message: "Please create or enter a valid Group ID before use!",
                                button1: "OK".local
                            ).runModal()
                        }
                    }, label: {
                        Image("list.clipboard.fill.circle")
                            .resizable().scaledToFit()
                            .frame(width: 15, height: 15)
                    }).buttonStyle(.plain)
                }.frame(height: 16)
                Divider().opacity(0.5)
                VStack(spacing: 2) {
                    Text("Nearcast will broadcast your battery data within the local network.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Your data has been encrypted using the group id, don't share it with others.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            SGroupBox(label: "Peer Info") {
                HStack {
                    Text("Local ID")
                    Spacer()
                    Text(netcastService.transceiver.localPeerId ?? "")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct DisplayView: View {
    @AppStorage("showOn") var showOn = "sbar"
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("showThisMac") var showThisMac = "icon"
    @AppStorage("carouselMode") var carouselMode = true
    @AppStorage("colorfulBattery") var colorfulBattery = false
    @AppStorage("iosBatteryStyle") var iosBatteryStyle = false
    @AppStorage("intBattOnStatusBar") var intBattOnStatusBar = true
    @AppStorage("batteryPercent") var batteryPercent = "outside"
    @AppStorage("hideLevel") var hideLevel = 90
    @AppStorage("twsMergeEnabled") private var twsMergeEnabled = true
    @AppStorage("twsMerge") private var twsMerge = 5
    @State private var levelList = [95, 90, 80, 70, 60, 50, 40, 30, 20, 10]
    
    var body: some View {
        SForm {
            SGroupBox(label: "Surfaces") {
                SPicker(
                    "Show AirBattery",
                    selection: $showOn,
                    tips: "Choose where AirBattery itself is presented. Widgets are configured separately."
                ) {
                    Text("Menu Bar").tag("sbar")
                    Text("Dock").tag("dock")
                    Text("Both").tag("both")
                    Text("None").tag("none")
                }
                .onChange(of: showOn) { newValue in
                    switch newValue {
                    case "sbar":
                        statusBarItem.isVisible = true
                        for item in pinnedItems { item.isVisible = true }
                        NSApp.setActivationPolicy(.accessory)
                    case "both":
                        statusBarItem.isVisible = true
                        for item in pinnedItems { item.isVisible = true }
                        NSApp.setActivationPolicy(.regular)
                    case "dock":
                        statusBarItem.isVisible = false
                        for item in pinnedItems { item.isVisible = false }
                        NSApp.setActivationPolicy(.regular)
                    default:
                        statusBarItem.isVisible = false
                        for item in pinnedItems { item.isVisible = false }
                        NSApp.setActivationPolicy(.accessory)
                    }

                    if newValue == "dock" || newValue == "both" {
                        _ = createAlert(
                            title: "AirBattery Tips".local,
                            message: "Displaying AirBattery on the Dock will consume more power, it is better to use Menu Bar mode or Widgets.".local,
                            button1: "OK"
                        ).runModal()
                    }
                }
            }

            SGroupBox(label: "Menu Bar") {
                SToggle("Dynamic Battery Icon", isOn: $intBattOnStatusBar)
                Divider().opacity(0.5)
                SToggle("Colorful Battery Icon", isOn: $colorfulBattery)
                    .disabled(!intBattOnStatusBar)
                Divider().opacity(0.5)
                SPicker("Battery Icon Style", selection: $iosBatteryStyle) {
                    Text("macOS").tag(false)
                    Text("iOS").tag(true)
                }.disabled(!intBattOnStatusBar)
                Divider().opacity(0.5)
                SPicker("Show Percentage", selection: $batteryPercent) {
                    Text("Hidden").tag("hide")
                    Text("Inside").tag("inside")
                    Text("Outside").tag("outside")
                }.disabled(!intBattOnStatusBar)

                Divider().opacity(0.5)
                SPicker("Hide percentage when above", selection: $hideLevel) {
                    Text("Never").tag(100)
                    ForEach(levelList, id: \.self) { number in
                        Text("\(number)%").tag(number)
                    }
                    if !levelList.contains(hideLevel) && hideLevel != 100 {
                        Text("\(hideLevel)%").tag(hideLevel)
                    }
                }.disabled(!intBattOnStatusBar || (batteryPercent == "hide"))
            }
            SGroupBox(label: "Device Rows") {
                SPicker(
                    "Earbud merging",
                    selection: $twsMergeEnabled,
                    tips: "When off, left and right battery levels are always shown separately. When enabled, they are merged only when both charging states match and their battery levels are within the configured threshold."
                ) {
                    Text("Off").tag(false)
                    Text("Within threshold").tag(true)
                }
                if twsMergeEnabled {
                    Divider().opacity(0.5)
                    SSteper(
                        "Merge threshold (%)",
                        value: $twsMerge,
                        min: 0,
                        max: 99,
                        tips: "Merge left and right earbud levels when their difference is at most this percentage."
                    )
                }
            }

            SGroupBox(label: "Dock") {
                    SPicker("Appearance", selection: $appearance) {
                        Text("Automatic").tag("auto")
                        Text("Light").tag("false")
                        Text("Dark").tag("true")
                    }.pickerStyle(.segmented)
                    Divider().opacity(0.5)
                    SPicker("Built-in Battery Style", selection: $showThisMac, tips: "Show or hide this Mac's built-in battery in the Dock icon") {
                        Text("Hidden").tag("hidden")
                        Text("Device Icon").tag("icon")
                        Text("Percent").tag("percent")
                    }
                    Divider().opacity(0.5)
                    SToggle("Carousel Mode", isOn: $carouselMode, tips: "Cycle through all found devices in the Dock icon")
            }
        }
    }
}

struct WidgetView: View {
    //@AppStorage("showMacOnWidget") var showMacOnWidget = true
    @AppStorage("revListOnWidget") var revListOnWidget = false
    @AppStorage("deviceOnWidget") var deviceOnWidget = ""
    @AppStorage("widgetInterval") var widgetInterval = 0
    @AppStorage("deviceName") var deviceName = "Mac"
    
    @State var ib = getMacDeviceType().lowercased().contains("book")
    @State var devices = [String]()

    var body: some View {
        SForm {
            SGroupBox(label: "Widget") {
                SToggle("Reverse Device List", isOn: $revListOnWidget)
                Divider().opacity(0.5)
                SPicker("Refresh Interval", selection: $widgetInterval) {
                    Text("System Default").tag(-1)
                    Text("Same as Discovery").tag(0)
                }
                if #unavailable(macOS 14) {
                    Divider().opacity(0.5)
                    SPicker("Single Device Widget", selection: $deviceOnWidget) {
                        Text("Not Set").tag("")
                        if ib { Text(deviceName).tag(deviceName) }
                        ForEach(devices, id: \.self) { device in
                            Text(device).tag(device)
                        }
                        if !devices.contains(deviceOnWidget) && deviceOnWidget != deviceName && deviceOnWidget != "" {
                            Text(deviceOnWidget).tag(deviceOnWidget)
                        }
                    }.onChange(of: deviceOnWidget) { _ in _ = AirBatteryModel.singleDeviceName() }
                }
                Divider().opacity(0.5)
                SButton("Reload All Widgets", buttonTitle: "Reload") {
                    AirBatteryModel.writeData()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        .onAppear { devices = AirBatteryModel.getAll(noFilter: true).filter({ $0.hasBattery }).map({ $0.deviceName }) }
        .onReceive(dockTimer) { _ in
            if #unavailable(macOS 14) {
                devices = AirBatteryModel.getAll(noFilter: true).filter({ $0.hasBattery }).map({ $0.deviceName })
            }
        }
    }
}

struct NameRulesEditor: View {
    @AppStorage("whitelistMode") private var whitelistMode = false
    @State private var names: [String] = []
    @State private var newName = ""
    @State private var showAddSheet = false
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 9) {
                Picker("Devices matching these names", selection: $whitelistMode) {
                    Text("Ignore").tag(false)
                    Text("Allow only these").tag(true)
                }
                .pickerStyle(.segmented)

                Text(
                    whitelistMode
                        ? "Only devices with one of these names pass the broad name filter."
                        : "Devices with one of these names are excluded from discovery and display."
                )
                .font(.caption)
                .foregroundColor(.secondary)

                if names.isEmpty {
                    Text("No name rules.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(names, id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            Button {
                                names.removeAll(where: { $0 == name })
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove name rule")
                        }
                    }
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add name rule", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .sheet(isPresented: $showAddSheet) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Name Rule")
                            .font(.headline)
                        TextField("Device name", text: $newName)
                            .frame(width: 320)
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                newName = ""
                                showAddSheet = false
                            }
                            Button("Add") {
                                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                if !names.contains(trimmed) { names.append(trimmed) }
                                names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                                newName = ""
                                showAddSheet = false
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding()
                }
            }
            .padding(.top, 7)
        } label: {
            HStack {
                Text("Name rules")
                Spacer()
                Text("\(names.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            names = (ud.object(forKey: "blockedDevices") as? [String]) ?? []
            names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        .onChange(of: names) { value in
            ud.setValue(value, forKey: "blockedDevices")
        }
    }
}

struct DebugView: View {
    @AppStorage("test_debug") var test_debug = false
    @AppStorage("test_hasib") var test_hasib = false
    @AppStorage("test_acpower") var test_ac = false
    @AppStorage("test_full") var test_full = false
    @AppStorage("test_iblevel") var test_iblevel = 100
    @AppStorage("showDebug") var showDebug: Bool = false
    
    @State private var deviceID: String = ""
    @State private var deviceType: String = ""
    @State private var deviceName: String = ""
    @State private var deviceModel: String = ""
    @State private var parentName: String = ""
    @State private var batteryLevel: Int = 0
    @State private var lowPower: Bool = false
    @State private var isCharging: Bool = false
    @State private var fullCharged: Bool = false
    @State private var isPresented: Bool = false
    
    @Binding var selectedItem: String?
    
    var body: some View {
        SForm(noSpacer: true) {
            SGroupBox {
                SToggle("Debug Mode", isOn: $test_debug)
                Divider().opacity(0.5)
                SButton("Data Folder", buttonTitle: "Open") {
                    NSWorkspace.shared.open(ncFolder.deletingLastPathComponent())
                }
            }
            SGroupBox(label: "Built-in Battery") {
                SToggle("Built-in Battery", isOn: $test_hasib)
                Divider().opacity(0.5)
                SToggle("AC Powered", isOn: $test_ac)
                Divider().opacity(0.5)
                SToggle("Paused", isOn: $test_full)
                Divider().opacity(0.5)
                SSteper("Level", value: $test_iblevel, min: 1)
            }
            SGroupBox(label: "Remote Battery") {
                HStack {
                    Text("Create Item")
                    Spacer()
                    Button(action: {
                        isPresented = true
                    }, label: {
                        Image(systemName: "plus.circle.fill")
                    })
                    .buttonStyle(.plain)
                    .sheet(isPresented: $isPresented) {
                        VStack {
                            SGroupBox(label: "Remote Battery") {
                                SField("Device ID", text: $deviceID)
                                Divider().opacity(0.5)
                                SField("Device Name", text: $deviceName)
                                Divider().opacity(0.5)
                                SField("Device Type", text: $deviceType)
                                Divider().opacity(0.5)
                                SField("Device Model", text: $deviceModel)
                                Divider().opacity(0.5)
                                HStack {
                                    SField("Parent Name", text: $parentName)
                                    Button(action: {
                                        parentName = getMacDeviceName()
                                    }, label: {
                                        let ib = ib2ab(InternalBattery.status)
                                        Image(getDeviceIcon(ib))
                                            .resizable().scaledToFit()
                                            .frame(width: 16, height: 16)
                                    }).buttonStyle(.plain)
                                }
                                Divider().opacity(0.5)
                                SSteper("Level", value: $batteryLevel)
                                Divider().opacity(0.5)
                                SToggle("Charging", isOn: $isCharging)
                                Divider().opacity(0.5)
                                SToggle("Paused", isOn: $fullCharged)
                                Divider().opacity(0.5)
                                SToggle("Low Power", isOn: $lowPower)
                            }
                            HStack {
                                Spacer()
                                Button(action: {
                                    isPresented = false
                                }, label: {
                                    Text("Cancle").frame(width: 50)
                                })
                                Button(action: {
                                    let device = Device(deviceID: deviceID, deviceType: deviceType, deviceName: deviceName, batteryLevel: batteryLevel, isCharging: isCharging ? 1 : (fullCharged ? 5 : 0), lowPower: lowPower, parentName: parentName,lastUpdate: Date().timeIntervalSince1970)
                                    AirBatteryModel.updateDevice(device)
                                    isPresented = false
                                }, label: {
                                    Text("Add").frame(width: 50)
                                }).keyboardShortcut(.defaultAction)
                            }
                        }
                        .padding()
                        .onAppear {
                            deviceID = randomString(length: 10)
                            deviceType = "virtual"
                            deviceName = "Virtual Device"
                            deviceModel = ""
                            parentName = ""
                            batteryLevel = 100
                            lowPower = false
                            isCharging = false
                            fullCharged = false
                        }
                    }
                }
            }
            Button("Hide Debug Menu", action: {
                test_debug = false
                showDebug = false
                selectedItem = "General"
            })
            .padding(.top, -6)
        }
    }
}

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
    @State private var selectedItem = "General"
    @AppStorage("showDebug") var showDebug: Bool = false
    @ObservedObject private var discoveryPolicy = BLEDiscoveryPolicyStore.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 190)

            Divider()

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .onChange(of: showDebug) { enabled in
            if !enabled && selectedItem == "Debug" {
                selectedItem = "General"
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 4) {
            settingsSidebarButton(
                "General",
                systemImage: "gearshape",
                tag: "General"
            )
            settingsSidebarButton(
                "Display",
                systemImage: "rectangle.3.group",
                tag: "Display"
            )
            settingsSidebarButton(
                "Devices",
                systemImage: "rectangle.stack",
                tag: "Devices",
                badge: discoveryPolicy.reviewCount
            )
            settingsSidebarButton(
                "Discovery",
                systemImage: "antenna.radiowaves.left.and.right",
                tag: "Discovery"
            )
            settingsSidebarButton(
                "Nearcast",
                systemImage: "network",
                tag: "Nearcast"
            )
            if showDebug {
                settingsSidebarButton(
                    "Debug",
                    systemImage: "ladybug",
                    tag: "Debug"
                )
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case "Display":
            DisplayView()
        case "Devices":
            DevicesView()
        case "Discovery":
            DiscoveryView()
        case "Nearcast":
            NearcastView()
        case "Debug":
            if showDebug {
                DebugView(selectedItem: debugSelectionBinding)
            } else {
                GeneralView()
            }
        default:
            GeneralView()
        }
    }

    @ViewBuilder
    private func settingsSidebarButton(
        _ title: String,
        systemImage: String,
        tag: String,
        badge: Int = 0
    ) -> some View {
        Button {
            selectedItem = tag
        } label: {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Color.secondary.opacity(0.18))
                        )
                        .accessibilityLabel("\(badge) devices need review")
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    selectedItem == tag
                        ? Color.accentColor.opacity(0.22)
                        : Color.clear
                )
        )
        .foregroundColor(selectedItem == tag ? .primary : .primary)
        .accessibilityAddTraits(
            selectedItem == tag ? .isSelected : []
        )
    }

    private var debugSelectionBinding: Binding<String?> {
        Binding(
            get: { selectedItem },
            set: { newValue in
                selectedItem = newValue ?? "General"
            }
        )
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
                SGroupBox(label: "Apple Devices") {
                    sourceIntro(
                        "Network & USB",
                        detail: "Reads trusted iPhone and iPad battery information through Apple’s device connection services. This path is also required to read a paired Apple Watch through an iPhone."
                    )
                    SToggle(
                        "Use Network & USB",
                        isOn: $readIDevice,
                        tips: "Discover trusted Apple mobile devices through libimobiledevice over Wi-Fi or USB. Apple Watch companion data requires a live iPhone connection through this source."
                    )

                    Divider().opacity(0.5)

                    sourceIntro(
                        "Bluetooth",
                        detail: "Finds supported nearby iPhone and cellular iPad devices. Bluetooth can provide the mobile device battery, but it cannot retrieve a paired Apple Watch."
                    )
                    SToggle(
                        "Use Bluetooth",
                        isOn: $ideviceOverBLE,
                        tips: "Discover supported iPhone and cellular iPad devices over Bluetooth. Any active battery query follows the policy in Battery Queries below."
                    )
                }

                SGroupBox(label: "Bluetooth Accessories") {
                    sourceIntro(
                        "Paired accessories",
                        detail: "Reads battery information already exposed by macOS and passive Apple/Beats battery broadcasts."
                    )
                    SToggle(
                        "Paired accessories",
                        isOn: $readBTDevice,
                        tips: "Read battery information exposed by macOS and passive Apple/Beats Bluetooth advertisements."
                    )

                    Divider().opacity(0.5)

                    sourceIntro(
                        "Extended macOS discovery",
                        detail: "Looks for additional accessories reported by macOS, especially after connect, reconnect, or wake."
                    )
                    SToggle(
                        "Extended macOS discovery",
                        isOn: $readBTHID,
                        tips: "Use macOS Bluetooth system information and logs to find additional third-party devices. Updates commonly occur after reconnect or wake."
                    )

                    Divider().opacity(0.5)

                    sourceIntro(
                        "Nearby BLE devices",
                        detail: "Passively observes nearby Bluetooth Low Energy devices that may provide battery information."
                    )
                    SToggle(
                        "Nearby BLE devices",
                        isOn: $readBLEDevice,
                        tips: "Observe nearby BLE advertisements. AirBattery connects only when the Battery Queries policy permits it."
                    )
                }

                SGroupBox(label: "Battery Queries") {
                    SPicker(
                        "New BLE devices",
                        selection: $bleDiscoveryMode,
                        tips: "Controls whether AirBattery may connect to a newly observed BLE device when it needs to read battery information."
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
                            .fixedSize(horizontal: false, vertical: true)
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
                        SInfoButton(
                            tips: "Read the battery status of a connected Apple Pencil through your iPad. Initial discovery may take 10 minutes or longer and may increase iPad battery use."
                        )
                        Toggle("", isOn: $readPencil)
                            .toggleStyle(.switch)
                            .scaleEffect(0.7)
                            .frame(width: 32)
                            .accessibilityLabel("Apple Pencil from iPad")
                    }
                    .frame(minHeight: 28)
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
    private func sourceIntro(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(detail)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @State private var technicalExpandedKnown: Set<String> = []
    @State private var technicalExpandedNearby: Set<String> = []
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
                snapshot.devices.contains(where: { $0.matchesIdentifier(candidate.identifier) }) ||
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
                if snapshot.devices.contains(where: { $0.batterySource == .ble }) {
                    snapshot.sources.insert(.bluetooth)
                } else if snapshot.devices.contains(where: { $0.batterySource == .libimobiledevice }) {
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
                Spacer()
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
        .menuStyle(.borderlessButton)
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
                .frame(minWidth: 82, alignment: .trailing)
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
                .menuStyle(.borderlessButton)
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

struct NearcastView: View {
    @AppStorage("nearCast") var nearCast = false
    @AppStorage("nearcastGroupID") var nearcastGroupID = ""
    @AppStorage("nearcastSharingKey") var nearcastSharingKey = ""

    var body: some View {
        SForm {
            SGroupBox(label: "Nearcast") {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Share AirBattery device information with other Macs on your local network.")
                        .font(.footnote)
                    Text("Only Macs using the same Group ID and Sharing Key can read the shared battery information.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().opacity(0.5)

                SToggle("Enable Nearcast", isOn: $nearCast)
                    .onChange(of: nearCast) { enabled in
                        if enabled {
                            guard isNearcastCredentialValid(
                                groupID: nearcastGroupID,
                                sharingKey: nearcastSharingKey
                            ) else {
                                DispatchQueue.main.async { nearCast = false }
                                _ = createAlert(
                                    title: "Nearcast setup incomplete".local,
                                    message: "Generate or enter a valid Group ID and Sharing Key before enabling Nearcast.",
                                    button1: "OK".local
                                ).runModal()
                                return
                            }
                            netcastService.resume()
                        } else {
                            netcastService.stop()
                        }
                    }

                Divider().opacity(0.5)

                credentialRow(
                    label: "Group ID",
                    value: $nearcastGroupID,
                    secure: false,
                    copyLabel: "Copy Group ID"
                )

                Divider().opacity(0.5)

                credentialRow(
                    label: "Sharing Key",
                    value: $nearcastSharingKey,
                    secure: true,
                    copyLabel: "Copy Sharing Key"
                )

                Divider().opacity(0.5)

                HStack(spacing: 8) {
                    Button("Generate New") {
                        let credentials = generateNearcastCredentials()
                        nearcastGroupID = credentials.groupID
                        nearcastSharingKey = credentials.sharingKey
                        ud.set("", forKey: "ncGroupID")
                    }
                    .disabled(nearCast)
                    .help("Generate a new Nearcast group and a new private sharing key.")

                    Button("Copy Setup") {
                        guard let code = nearcastSetupCode(
                            groupID: nearcastGroupID,
                            sharingKey: nearcastSharingKey
                        ) else {
                            showInvalidCredentials()
                            return
                        }
                        copyToClipboard(code)
                    }
                    .disabled(!credentialsValid)
                    .help("Copy the Group ID and Sharing Key together as a setup code.")

                    Button("Paste Setup") {
                        guard let text = pasteFromClipboard(),
                              let credentials = parseNearcastSetupCode(text)
                        else {
                            _ = createAlert(
                                title: "Invalid Nearcast setup".local,
                                message: "The clipboard does not contain a valid AirBattery Nearcast setup code.",
                                button1: "OK".local
                            ).runModal()
                            return
                        }
                        nearcastGroupID = credentials.groupID
                        nearcastSharingKey = credentials.sharingKey
                    }
                    .disabled(nearCast)
                    .help("Import a Nearcast setup code copied from another Mac.")

                    Spacer()
                }

                Text("The Group ID identifies the Nearcast group and is not secret. Keep the Sharing Key private; anyone with both values can join the group and decrypt its shared battery information.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SGroupBox(label: "Connection") {
                HStack {
                    Text("Local peer")
                    Spacer()
                    Text(netcastService.transceiver.localPeerId ?? "Not active")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var credentialsValid: Bool {
        isNearcastCredentialValid(
            groupID: nearcastGroupID,
            sharingKey: nearcastSharingKey
        )
    }

    @ViewBuilder
    private func credentialRow(
        label: String,
        value: Binding<String>,
        secure: Bool,
        copyLabel: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer()
            Group {
                if secure {
                    SecureField("", text: value)
                } else {
                    TextField("", text: value)
                }
            }
            .textFieldStyle(.roundedBorder)
            .frame(width: 330)
            .disabled(nearCast)

            Button {
                guard !value.wrappedValue.isEmpty else { return }
                copyToClipboard(value.wrappedValue)
            } label: {
                Text(copyLabel)
            }
            .disabled(value.wrappedValue.isEmpty)
            .help(copyLabel)
            .accessibilityLabel(copyLabel)
        }
        .frame(minHeight: 28)
    }

    private func showInvalidCredentials() {
        _ = createAlert(
            title: "Invalid Nearcast setup".local,
            message: "Generate or enter a valid Group ID and Sharing Key first.",
            button1: "OK".local
        ).runModal()
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
    @AppStorage("revListOnWidget") var revListOnWidget = false
    @AppStorage("widgetInterval") var widgetInterval = 0
    @AppStorage("deviceName") var deviceName = "Mac"

    @State private var levelList = [95, 90, 80, 70, 60, 50, 40, 30, 20, 10]

    var body: some View {
        ScrollView {
            SForm(noSpacer: true) {
                SGroupBox(label: "Surfaces") {
                    SPicker(
                        "Show AirBattery",
                        selection: $showOn,
                        tips: "Choose whether AirBattery itself appears in the menu bar, Dock, both, or neither. Widgets are available independently."
                    ) {
                        Text("Menu Bar").tag("sbar")
                        Text("Dock").tag("dock")
                        Text("Both").tag("both")
                        Text("None").tag("none")
                    }
                    .onChange(of: showOn) { newValue in
                        applySurfaceSelection(newValue)
                    }

                    Divider().opacity(0.5)

                    SPicker("Appearance", selection: $appearance) {
                        Text("Automatic").tag("auto")
                        Text("Light").tag("false")
                        Text("Dark").tag("true")
                    }
                    .pickerStyle(.segmented)
                }

                SGroupBox(label: "Menu Bar") {
                    SToggle(
                        "Show this Mac’s battery",
                        isOn: $intBattOnStatusBar,
                        tips: "When enabled, the menu-bar item displays this Mac’s battery. When disabled, it uses the AirBattery status icon instead."
                    )
                    Divider().opacity(0.5)
                    SToggle("Use battery colors", isOn: $colorfulBattery)
                        .disabled(!intBattOnStatusBar)
                    Divider().opacity(0.5)
                    SPicker("Battery style", selection: $iosBatteryStyle) {
                        Text("macOS").tag(false)
                        Text("iOS").tag(true)
                    }
                    .disabled(!intBattOnStatusBar)
                    Divider().opacity(0.5)
                    SPicker("Percentage", selection: $batteryPercent) {
                        Text("Hidden").tag("hide")
                        Text("Inside").tag("inside")
                        Text("Outside").tag("outside")
                    }
                    .disabled(!intBattOnStatusBar)
                    Divider().opacity(0.5)
                    SPicker("Hide percentage above", selection: $hideLevel) {
                        Text("Never").tag(100)
                        ForEach(levelList, id: \.self) { number in
                            Text("\(number)%").tag(number)
                        }
                        if !levelList.contains(hideLevel) && hideLevel != 100 {
                            Text("\(hideLevel)%").tag(hideLevel)
                        }
                    }
                    .disabled(!intBattOnStatusBar || batteryPercent == "hide")

                    Text("Yellow continues to mean Low Power Mode (or a genuinely low battery), matching macOS battery semantics.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SGroupBox(label: "Device Rows") {
                    SPicker(
                        "Earbud merging",
                        selection: $twsMergeEnabled,
                        tips: "When off, left and right battery levels are always shown separately. When enabled, they merge only when their charging states match and their levels are within the configured threshold."
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
                    SPicker(
                        "Built-in battery",
                        selection: $showThisMac,
                        tips: "Choose how this Mac’s built-in battery appears in the Dock icon."
                    ) {
                        Text("Hidden").tag("hidden")
                        Text("Device Icon").tag("icon")
                        Text("Percent").tag("percent")
                    }
                    Divider().opacity(0.5)
                    SToggle(
                        "Carousel Mode",
                        isOn: $carouselMode,
                        tips: "Cycle through logical devices when more devices are available than fit in the Dock tile."
                    )
                }

                SGroupBox(label: "Widgets") {
                    SToggle("Reverse device list", isOn: $revListOnWidget)
                    Divider().opacity(0.5)
                    SPicker("Refresh interval", selection: $widgetInterval) {
                        Text("System Default").tag(-1)
                        Text("Same as Discovery").tag(0)
                    }
                    Divider().opacity(0.5)
                    SButton("Reload all widgets", buttonTitle: "Reload") {
                        AirBatteryModel.writeData()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }

                SGroupBox(label: "Preview") {
                    DisplaySurfacePreview(
                        mergeEarbuds: twsMergeEnabled,
                        mergeThreshold: twsMerge,
                        reverseWidgetOrder: revListOnWidget,
                        showMacInDock: showThisMac != "hidden",
                        showMacAsPercent: showThisMac == "percent",
                        menuBarShowsMac: intBattOnStatusBar,
                        colorfulBattery: colorfulBattery,
                        iosBatteryStyle: iosBatteryStyle,
                        batteryPercent: batteryPercent,
                        hideLevel: hideLevel,
                        appearance: appearance
                    )
                }
            }
        }
        .onAppear {
        }
        .onReceive(dockTimer) { _ in
        }
    }

    private func applySurfaceSelection(_ newValue: String) {
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
                message: "Displaying AirBattery on the Dock will consume more power; Menu Bar mode or Widgets generally use less.".local,
                button1: "OK"
            ).runModal()
        }
    }

}

private struct DisplaySurfacePreview: View {
    let mergeEarbuds: Bool
    let mergeThreshold: Int
    let reverseWidgetOrder: Bool
    let showMacInDock: Bool
    let showMacAsPercent: Bool
    let menuBarShowsMac: Bool
    let colorfulBattery: Bool
    let iosBatteryStyle: Bool
    let batteryPercent: String
    let hideLevel: Int
    let appearance: String

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var widgetPreviewPercentages = true
    @State private var widgetPreviewLabels = true

    private var previewColorScheme: ColorScheme {
        switch appearance {
        case "true":
            return .dark
        case "false":
            return .light
        default:
            return systemColorScheme
        }
    }

    private var presentations: [LogicalDevicePresentation] {
        AirBatteryModel.logicalPresentations(
            from: sampleDevices,
            mergeEarbuds: mergeEarbuds,
            mergeThreshold: mergeThreshold
        )
    }

    private var widgetStoredSampleDevices: [Device] {
        AirBatteryModel.widgetStoredDevices(
            from: sampleDevices.filter {
                $0.deviceID != "@MacInternalBattery"
            },
            internalBattery: sampleDevices.first {
                $0.deviceID == "@MacInternalBattery"
            },
            reverse: reverseWidgetOrder
        )
    }

    private var dockPresentations: [LogicalDevicePresentation] {
        Array(
            presentations
                .filter {
                    showMacInDock ||
                        $0.representative.deviceID != "@MacInternalBattery"
                }
                .prefix(4)
        )
    }

    private var widgetRingDevices: [Device] {
        AirBatteryModel.widgetPresentationOrder(
            from: widgetStoredSampleDevices
        )
    }

    private let familyColumns = [
        GridItem(
            .adaptive(minimum: 340, maximum: 360),
            spacing: 16,
            alignment: .top
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            previewSection("Menu Bar") {
                HStack {
                    StatusBarBatteryContent(
                        item: sampleInternalBattery,
                        showMacBattery: menuBarShowsMac,
                        colorfulBattery: colorfulBattery,
                        iosBatteryStyle: iosBatteryStyle,
                        batteryPercent: batteryPercent,
                        hideLevel: hideLevel
                    )
                    Spacer()
                }
                .frame(height: 28)
            }

            Divider().opacity(0.35)

            previewSection("Popover") {
                VStack(spacing: 0) {
                    PopoverToolbarSurfaceContent(
                        fromDock: false,
                        nearcastEnabled: false,
                        onHide: {},
                        onAbout: {},
                        onSettings: {},
                        onQuit: {},
                        onRefreshNearcast: {}
                    )

                    VStack(spacing: 0) {
                        ForEach(presentations.indices, id: \.self) { index in
                            MenuDeviceRowContent(
                                presentation: presentations[index]
                            )
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)

                            if index != presentations.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: 352)
                .liquidGlassEffect(
                    cornerRadius: 10,
                    interactive: false,
                    tint: .primary.opacity(0.04)
                )
            }

            Divider().opacity(0.35)

            previewSection("Dock") {
                DockTileSurfaceContent(
                    presentations: dockPresentations,
                    darkMode: previewColorScheme == .dark,
                    showMacAsPercent: showMacAsPercent
                )
            }

            Divider().opacity(0.35)

            VStack(alignment: .leading, spacing: 14) {
                Text("Widgets")
                    .font(.headline)

                Text(
                    "Battery Overview replaces the historical Battery List " +
                    "and Battery Rings variants for new widgets. Each placed " +
                    "widget can independently show or hide percentages and labels."
                )
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 18) {
                    Toggle(
                        "Percentages",
                        isOn: $widgetPreviewPercentages
                    )
                    .toggleStyle(.switch)
                    .fixedSize()

                    Toggle(
                        "Labels",
                        isOn: $widgetPreviewLabels
                    )
                    .toggleStyle(.switch)
                    .fixedSize()

                    Spacer()
                }

                LazyVGrid(
                    columns: familyColumns,
                    alignment: .leading,
                    spacing: 24
                ) {
                    widgetFamilyPreview(
                        "Battery Overview — Small",
                        family: .small
                    ) {
                        WidgetOverviewRingsSurfaceContent(
                            devices: widgetRingDevices,
                            family: .small,
                            showPercentages: widgetPreviewPercentages,
                            showLabels: widgetPreviewLabels
                        )
                    }

                    widgetFamilyPreview(
                        "Battery Overview — Medium",
                        family: .medium
                    ) {
                        WidgetOverviewRingsSurfaceContent(
                            devices: widgetRingDevices,
                            family: .medium,
                            showPercentages: widgetPreviewPercentages,
                            showLabels: widgetPreviewLabels
                        )
                    }

                    widgetFamilyPreview(
                        "Battery Overview — Large",
                        family: .large
                    ) {
                        WidgetOverviewRingsSurfaceContent(
                            devices: widgetRingDevices,
                            family: .large,
                            showPercentages: widgetPreviewPercentages,
                            showLabels: widgetPreviewLabels
                        )
                    }

                    widgetFamilyPreview(
                        "Single Battery — Small",
                        family: .small
                    ) {
                        WidgetSingleBatterySurfaceContent(
                            item: widgetRingDevices.first {
                                $0.deviceType == "iPhone"
                            },
                            deviceName: "Joseph’s iPhone",
                            warningText: "Right click to configure"
                        )
                    }
                }

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, previewColorScheme)
    }

    @ViewBuilder
    private func previewSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func widgetFamilyPreview<Content: View>(
        _ title: String,
        family: WidgetPreviewFamily,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                        .stroke(
                            Color.secondary.opacity(0.22),
                            lineWidth: 1
                        )
                    )

                content()
                    .padding(family.hostPadding)
            }
            .frame(
                width: family.size.width,
                height: family.size.height,
                alignment: .center
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sampleInternalBattery: iBattery {
        iBattery(
            hasBattery: true,
            isCharging: false,
            isCharged: false,
            acPowered: false,
            timeLeft: "02:14",
            batteryLevel: 69,
            lowPower: true
        )
    }

    private var sampleDevices: [Device] {
        let now = Date().timeIntervalSince1970
        return [
            Device(
                deviceID: "@MacInternalBattery",
                deviceType: "macbookpro",
                deviceName: "LT-0801530",
                batteryLevel: 69,
                isCharging: 0,
                lowPower: true,
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-iphone",
                deviceType: "iPhone",
                deviceName: "Joseph’s iPhone",
                deviceModel: "iPhone14,7",
                batteryLevel: 86,
                isCharging: 0,
                lastUpdate: now,
                batterySource: .ble
            ),
            Device(
                deviceID: "preview-watch",
                deviceType: "Watch",
                deviceName: "Joseph’s Apple Watch",
                batteryLevel: 54,
                isCharging: 1,
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-airpods-case",
                deviceType: "ap_case",
                deviceName: "Joseph’s AirPods (Case)",
                batteryLevel: 100,
                isCharging: 0,
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-airpods-left",
                deviceType: "ap_pod_left",
                deviceName: "Joseph’s AirPods Left",
                batteryLevel: 96,
                isCharging: 1,
                parentName: "Joseph’s AirPods",
                lastUpdate: now
            ),
            Device(
                deviceID: "preview-airpods-right",
                deviceType: "ap_pod_right",
                deviceName: "Joseph’s AirPods Right",
                batteryLevel: 98,
                isCharging: 1,
                parentName: "Joseph’s AirPods",
                lastUpdate: now
            )
        ]
    }
}

private enum WidgetPreviewFamily {
    case small
    case medium
    case large

    var size: CGSize {
        switch self {
        case .small:
            return CGSize(width: 172, height: 172)
        case .medium:
            return CGSize(width: 352, height: 172)
        case .large:
            return CGSize(width: 352, height: 368)
        }
    }

    var hostPadding: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 8
        case .large:
            return 10
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
                .fixedSize(horizontal: false, vertical: true)

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
                                    .frame(width: 28, height: 28)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .help("Remove name rule")
                            .accessibilityLabel("Remove name rule \(name)")
                        }
                    }
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add name rule", systemImage: "plus")
                        .frame(minHeight: 28)
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
                                let trimmed = newName.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                guard !trimmed.isEmpty else { return }
                                if !names.contains(trimmed) {
                                    names.append(trimmed)
                                }
                                names.sort {
                                    $0.localizedCaseInsensitiveCompare($1) ==
                                        .orderedAscending
                                }
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
            .frame(minHeight: 28)
        }
        .onAppear {
            names = (ud.object(forKey: "blockedDevices") as? [String]) ?? []
            names.sort {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
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

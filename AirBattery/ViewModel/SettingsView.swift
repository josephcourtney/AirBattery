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
                    Label("General", image: "gear")
                }
                NavigationLink(destination: DisplayView(), tag: "Display", selection: $selectedItem) {
                    Label("Menu & Dock", image: "dock")
                }
                NavigationLink(destination: DiscoveryView(), tag: "Discovery", selection: $selectedItem) {
                    Label("Discovery", image: "nearbility")
                }
                NavigationLink(destination: DevicesView(), tag: "Devices", selection: $selectedItem) {
                    HStack {
                        Label("Devices", image: "nearbility")
                        Spacer()
                        if discoveryPolicy.reviewCount > 0 {
                            Text("\(discoveryPolicy.reviewCount)")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.secondary.opacity(0.18)))
                        }
                    }
                }
                NavigationLink(destination: NearcastView(), tag: "Nearcast", selection: $selectedItem) {
                    Label("Nearcast", image: "nearcast")
                }
                NavigationLink(destination: WidgetView(), tag: "Widget", selection: $selectedItem) {
                    Label("Widgets", image: "widget")
                }
                if showDebug {
                    NavigationLink(destination: DebugView(selectedItem: $selectedItem), tag: "Debug", selection: $selectedItem) {
                        Label("Debug", image: "debug")
                    }
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
        }
        .frame(width: 720, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("AirBattery Settings")
    }
}

struct GeneralView: View {
    @AppStorage("showOn") var showOn = "sbar"
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
                Divider().opacity(0.5)
                SPicker("Show AirBattery", selection: $showOn) {
                    Text("Dock").tag("dock")
                    Text("Menu Bar").tag("sbar")
                    Text("Both").tag("both")
                    Text("None").tag("none")
                }.onChange(of: showOn) { newValue in
                    switch newValue {
                    case "sbar":
                        statusBarItem.isVisible = true
                        for i in pinnedItems { i.isVisible = true }
                        NSApp.setActivationPolicy(.accessory)
                    case "both":
                        statusBarItem.isVisible = true
                        for i in pinnedItems { i.isVisible = true }
                        NSApp.setActivationPolicy(.regular)
                    case "dock":
                        statusBarItem.isVisible = false
                        for i in pinnedItems { i.isVisible = false }
                        NSApp.setActivationPolicy(.regular)
                    default:
                        statusBarItem.isVisible = false
                        for i in pinnedItems { i.isVisible = false }
                        NSApp.setActivationPolicy(.accessory)
                    }
                    if newValue == "dock" || newValue == "both" {
                        _ = createAlert(title: "AirBattery Tips".local, message: "Displaying AirBattery on the Dock will consume more power, it is better to use Menu Bar mode or Widgets.".local, button1: "OK").runModal()
                    }
                }
            }
            SGroupBox {
                SButton("Command Line Tool", buttonTitle: cltInstalled ? "Uninstall" : "Install",
                        tips: "After installation, you can run \"airbattery\" in yor terminal to list all devices.") {
                    if cltInstalled {
                        CommandLineTool.uninstall { updateCTL() }
                    } else {
                        CommandLineTool.install { updateCTL() }
                    }
                }.onAppear { cltInstalled = CommandLineTool.isInstalled() }
            }.padding(.top, -20)
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
    @AppStorage("twsMerge") private var twsMerge = 5

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

                SGroupBox(label: "Refresh & Grouping") {
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
                    SSteper(
                        "Earbud merging threshold",
                        value: $twsMerge,
                        min: 1,
                        max: 99,
                        tips: "When left and right earbud percentages differ by less than this amount, AirBattery may report a combined earbud measurement. The UI still keeps the measurements logically grouped."
                    )
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

struct DevicesView: View {
    @ObservedObject private var policyStore = BLEDiscoveryPolicyStore.shared
    @State private var expandedKnown: Set<String> = []
    @State private var expandedNearby: Set<String> = []
    @State private var showOtherNearby = false

    var body: some View {
        ScrollView {
            SForm(noSpacer: true) {
                SGroupBox(label: "My Devices") {
                    if policyStore.knownLogicalDevices.isEmpty {
                        emptyRow("No device-specific connection rules.")
                    } else {
                        ForEach(policyStore.knownLogicalDevices) { device in
                            knownDeviceRow(device)
                            if device.id != policyStore.knownLogicalDevices.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }

                if !policyStore.suggestedCandidates.isEmpty {
                    SGroupBox(label: "Suggested") {
                        ForEach(policyStore.suggestedCandidates) { candidate in
                            nearbyDeviceRow(candidate, suggested: true)
                            if candidate.id != policyStore.suggestedCandidates.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }

                SGroupBox(label: "Nearby Devices") {
                    DisclosureGroup(isExpanded: $showOtherNearby) {
                        if policyStore.otherNearbyCandidates.isEmpty {
                            emptyRow("No other nearby BLE devices.")
                        } else {
                            ForEach(policyStore.otherNearbyCandidates.prefix(30)) { candidate in
                                nearbyDeviceRow(candidate, suggested: false)
                                if candidate.id != policyStore.otherNearbyCandidates.prefix(30).last?.id {
                                    Divider().opacity(0.5)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Other nearby devices")
                            Text("\(policyStore.otherNearbyCandidates.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if !policyStore.nearbyCandidates.isEmpty {
                                Button("Clear") { policyStore.clearNearby() }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                SGroupBox(label: "Advanced") {
                    NameRulesEditor()
                }
            }
        }
    }

    @ViewBuilder
    private func knownDeviceRow(_ device: BLELogicalDeviceSnapshot) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedKnown.contains(device.id) },
                set: { expanded in
                    if expanded { expandedKnown.insert(device.id) }
                    else { expandedKnown.remove(device.id) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 7) {
                if device.identities.isEmpty {
                    Text("Not observed during this launch.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(device.identities) { candidate in
                        identityDetail(candidate, logicalPolicy: device.policy)
                    }
                }
                if !device.exactRules.isEmpty {
                    Text("Identity-specific overrides take precedence over the device rule.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                    Text(logicalDeviceSummary(device))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                logicalPolicyMenu(device)
            }
        }
    }

    @ViewBuilder
    private func nearbyDeviceRow(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedNearby.contains(candidate.id) },
                set: { expanded in
                    if expanded { expandedNearby.insert(candidate.id) }
                    else { expandedNearby.remove(candidate.id) }
                }
            )
        ) {
            candidateDetails(candidate)
                .padding(.top, 5)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
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
    private func logicalPolicyMenu(_ device: BLELogicalDeviceSnapshot) -> some View {
        Menu {
            ForEach(BLEDevicePolicy.allCases, id: \.rawValue) { policy in
                Button(policy.title) {
                    policyStore.setLogicalPolicy(name: device.name, policy: policy)
                }
            }
            Divider()
            Button("Use discovery default") {
                policyStore.clearLogicalPolicy(name: device.name)
            }
        } label: {
            Text(device.policy?.title ?? "Per identity")
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
    private func identityDetail(_ candidate: BLEDiscoveryCandidate, logicalPolicy: BLEDevicePolicy?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(shortIdentifier(candidate.identifier))
                    .font(.caption)
                    .monospaced()
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
            detailRow("Signal", "\(signalLabel(candidate.displayRSSI)) · \(candidate.displayRSSI) dBm (raw \(candidate.rssi) dBm)")
            detailRow("Seen", "\(candidate.seenCount) times")
            detailRow("Identifier", candidate.identifier)
            if candidate.matchesPairedName {
                detailRow("Pairing", "Name matches a paired device")
            }
            if candidate.hasPassiveBatteryData {
                detailRow("Battery source", "Passive Apple/Beats advertisement")
            } else if candidate.advertisesBatteryService {
                detailRow("Battery source", "Battery Service advertised")
            }
            detailRow("Connection", candidate.isConnectable ? "Connectable" : "Not connectable")
            if let result = candidate.lastProbeResult {
                detailRow("Last query", result)
            }
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

    private func logicalDeviceSummary(_ device: BLELogicalDeviceSnapshot) -> String {
        guard !device.identities.isEmpty else { return "Not observed this launch" }
        let strongest = device.identities.map(\.displayRSSI).max() ?? -100
        var parts: [String] = []
        if device.identities.contains(where: \.hasPassiveBatteryData) {
            parts.append("Passive battery data")
        } else if device.identities.contains(where: \.advertisesBatteryService) {
            parts.append("Battery service advertised")
        }
        parts.append("\(signalLabel(strongest)) (\(strongest) dBm)")
        if device.identities.count > 1 {
            parts.append("\(device.identities.count) identities")
        }
        return parts.joined(separator: " · ")
    }

    private func candidatePrimarySummary(_ candidate: BLEDiscoveryCandidate) -> String {
        var parts: [String] = []
        if candidate.hasPassiveBatteryData {
            parts.append("Passive battery data")
        } else if candidate.advertisesBatteryService {
            parts.append("Battery service advertised")
        } else if candidate.matchesPairedName {
            parts.append("Name matches paired device")
        }
        parts.append("\(signalLabel(candidate.displayRSSI)) (\(candidate.displayRSSI) dBm)")
        return parts.joined(separator: " · ")
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
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("showThisMac") var showThisMac = "icon"
    @AppStorage("carouselMode") var carouselMode = true
    @AppStorage("colorfulBattery") var colorfulBattery = false
    @AppStorage("iosBatteryStyle") var iosBatteryStyle = false
    @AppStorage("intBattOnStatusBar") var intBattOnStatusBar = true
    @AppStorage("batteryPercent") var batteryPercent = "outside"
    @AppStorage("hideLevel") var hideLevel = 90
    @AppStorage("disappearTime") var disappearTime = 20
    @State private var levelList = [95, 90, 80, 70, 60, 50, 40, 30, 20, 10]
    
    var body: some View {
        SForm {
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
                SPicker("Remove Offline Device", selection: $disappearTime) {
                    Text("Never").tag(UInt32.max)
                    Text("after 20min").tag(20)
                    Text("after 40min").tag(40)
                    Text("after 60min").tag(60)
                }
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

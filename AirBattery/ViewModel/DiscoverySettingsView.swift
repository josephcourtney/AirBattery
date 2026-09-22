import AppKit
import SwiftUI
import WidgetKit

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
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel("Apple Pencil from iPad")
                    }
                    .frame(minHeight: 28)
                }

                SGroupBox(label: "Refresh & Retention") {
                    SSteper(
                        "Refresh interval (min)",
                        value: $updateInterval,
                        min: 1,
                        max: 99
                    )
                    .onChange(of: updateInterval) { _, _ in
                        MonitoringCoordinator.shared.updateIntervalDidChange()
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
            names = (UserDefaults.standard.object(forKey: "blockedDevices") as? [String]) ?? []
            names.sort {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }
        .onChange(of: names) { _, value in
            UserDefaults.standard.setValue(value, forKey: "blockedDevices")
        }
    }
}


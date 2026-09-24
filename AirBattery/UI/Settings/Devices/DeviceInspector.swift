import AppKit
import SwiftUI

extension DevicesView {
    @ViewBuilder
    func deviceInspector(
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
    func knownDeviceDetail(_ device: KnownDeviceSnapshot) -> some View {
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
                inspectorSettingRow("Display Name") {
                    HStack(spacing: 6) {
                        TextField(device.name, text: $displayNameDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 130, idealWidth: 175, maxWidth: 205)
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
                }

                if let ble = device.ble {
                    Divider().opacity(0.5)
                    inspectorSettingRow("Battery Access") {
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
    func nearbyIDeviceDetail(_ candidate: IDeviceDiscoveryCandidate) -> some View {
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
    func nearbyBLEDetail(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
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
                inspectorSettingRow("Battery Access") {
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
}

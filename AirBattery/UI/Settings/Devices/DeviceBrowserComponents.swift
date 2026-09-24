import AppKit
import SwiftUI

extension DevicesView {
    @ViewBuilder
    func deviceBrowser(
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
    func deviceBrowserSidebar(
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
    func browserSectionHeader(_ title: String, count: Int) -> some View {
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
    func knownDeviceListRow(_ device: KnownDeviceSnapshot) -> some View {
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
    func nearbyIDeviceListRow(_ candidate: IDeviceDiscoveryCandidate) -> some View {
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
    func nearbyBLEListRow(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
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
}

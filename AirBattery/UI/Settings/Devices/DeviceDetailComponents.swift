import AppKit
import SwiftUI

extension DevicesView {
    @ViewBuilder
    func detailedBatteryView(_ device: Device) -> some View {
        let estimate = AppEnvironment.shared.history.estimate(for: device)
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
    func batteryComponentCard(_ group: AirPodsBatteryGroup) -> some View {
        let presentation = AirPodsPresentation.logicalPresentations(
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
                        let estimate = AppEnvironment.shared.history.estimate(
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
    func detailSection<Content: View>(
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
    func inspectorSettingRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 110, alignment: .leading)
            Spacer(minLength: 4)
            content()
        }
        .frame(maxWidth: .infinity, minHeight: 28)
    }

    @ViewBuilder
    func plainDetailSection<Content: View>(
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
    func advancedTechnicalDetails(_ device: KnownDeviceSnapshot) -> some View {
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
    func nearbyTechnicalDetails<Content: View>(
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
    func knownDeviceIcon(_ device: KnownDeviceSnapshot, size: CGFloat) -> some View {
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
    func deviceInformationRows(_ device: KnownDeviceSnapshot) -> some View {
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
    func knownDeviceTechnicalDetails(_ device: KnownDeviceSnapshot) -> some View {
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

                let sampleCount = AppEnvironment.shared.history
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
    func policyValueMenu(
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
            .lineLimit(1)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
    }

    @ViewBuilder
    func reviewMenu(_ candidate: BLEDiscoveryCandidate, suggested: Bool) -> some View {
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
                .lineLimit(1)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
    }

    @ViewBuilder
    func sourceBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundColor(.primary.opacity(0.72))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .accessibilityLabel("Source: \(text)")
    }

    @ViewBuilder
    func identityDetail(
        _ candidate: BLEDiscoveryCandidate,
        logicalPolicy: BLEDevicePolicy?
    ) -> some View {
        let exactPolicy = policyStore.exactPolicy(identifier: candidate.identifier)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(shortIdentifier(candidate.identifier))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(exactPolicy == nil ? "Device policy" : "Identity override")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
                        if exactPolicy != nil {
                            Divider()
                            Button("Use device policy") {
                                policyStore.clearPolicy(identifier: candidate.identifier)
                            }
                        }
                    } label: {
                        Text(exactPolicy?.title ?? logicalPolicy?.title ?? "Discovery default")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
                }
            }
            candidateTechnicalDetails(candidate)
        }
        .padding(.leading, 4)
    }
}

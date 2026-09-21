import AppKit
import SwiftUI
import WidgetKit

struct NearcastView: View {
    @AppStorage("nearCast") var nearCast = false
    @AppStorage("nearcastGroupID") var nearcastGroupID = ""
    @AppStorage("nearcastSharingKey") var nearcastSharingKey = ""

    var body: some View {
        ScrollView {
            SForm(noSpacer: true) {
                SGroupBox(label: "Nearcast") {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            "Share AirBattery device information with other Macs " +
                                "on your local network."
                        )
                        .font(.footnote)

                        Text(
                            "Only Macs using the same Group ID and Sharing Key " +
                                "can read the shared battery information."
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider().opacity(0.5)

                    SToggle("Enable Nearcast", isOn: $nearCast)
                        .onChange(of: nearCast) { _, enabled in
                            if enabled {
                                guard isNearcastCredentialValid(
                                    groupID: nearcastGroupID,
                                    sharingKey: nearcastSharingKey
                                ) else {
                                    DispatchQueue.main.async {
                                        nearCast = false
                                    }
                                    _ = createAlert(
                                        title:
                                            "Nearcast setup incomplete".local,
                                        message:
                                            "Generate or enter a valid Group ID " +
                                            "and Sharing Key before enabling Nearcast.",
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
                        .help(
                            "Generate a new Nearcast group and a new private " +
                                "sharing key."
                        )

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
                        .help(
                            "Copy the Group ID and Sharing Key together as a " +
                                "setup code."
                        )

                        Button("Paste Setup") {
                            guard let text = pasteFromClipboard(),
                                  let credentials =
                                      parseNearcastSetupCode(text)
                            else {
                                _ = createAlert(
                                    title:
                                        "Invalid Nearcast setup".local,
                                    message:
                                        "The clipboard does not contain a valid " +
                                        "AirBattery Nearcast setup code.",
                                    button1: "OK".local
                                ).runModal()
                                return
                            }
                            nearcastGroupID = credentials.groupID
                            nearcastSharingKey = credentials.sharingKey
                        }
                        .disabled(nearCast)
                        .help(
                            "Import a Nearcast setup code copied from another Mac."
                        )

                        Spacer()
                    }

                    Text(
                        "The Group ID identifies the Nearcast group and is not " +
                            "secret. Keep the Sharing Key private; anyone with " +
                            "both values can join the group and decrypt its " +
                            "shared battery information."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                SGroupBox(label: "Connection") {
                    HStack {
                        Text("Local peer")
                        Spacer()
                        Text(
                            netcastService.transceiver.localPeerId ??
                                "Not active"
                        )
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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


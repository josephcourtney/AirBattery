import AppKit
import SwiftUI

enum DeviceBrowserSelection: Hashable {
    case known(String)
    case iDevice(String)
    case bluetooth(String)
}

struct DevicesView: View {
    @ObservedObject var policyStore = AppEnvironment.shared.blePolicy
    @ObservedObject var iDeviceBattery = AppEnvironment.shared.iDevices
    @ObservedObject var monitoring = AppEnvironment.shared.monitoring
    @StateObject var inventoryModel = DeviceInventoryModel()
    @State var selection: DeviceBrowserSelection?
    @State var displayNameDraft = ""
    @State var technicalExpandedKnown: Set<String> = []
    @State var technicalExpandedNearby: Set<String> = []
    @State var showOtherNearby = false
    @AppStorage("twsMergeEnabled") var twsMergeEnabled = true
    @AppStorage("twsMerge") var twsMerge = 5

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

    func refreshInventory() {
        inventoryModel.refresh(using: AppEnvironment.shared.inventory)

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
}

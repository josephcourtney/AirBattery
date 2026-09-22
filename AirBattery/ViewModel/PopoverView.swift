import AppKit
import SwiftUI

struct popover: View {
    var fromDock: Bool = false
    var allDevice: [Device]

    @AppStorage("nearCast") var nearCast = false
    @AppStorage("twsMergeEnabled") private var twsMergeEnabled = true
    @AppStorage("twsMerge") private var twsMerge = 5
    
    @ObservedObject private var monitoring = MonitoringCoordinator.shared

    @State private var allDevices = [Device]()
    @State private var hiddenDevices = AirBatteryModel.getBlackList()
    @State private var overStack = -1
    @State private var overStack2 = -1
    @State private var overStackNC = -1
    @State private var hidden = [Int]()
    @State private var hidden2 = [Int]()
    @State private var alertList = UserDefaults.standard.get(objectType: [btAlert].self, forKey: "alertList") ?? []
    @State private var pinnedList = AppPreferences.pinnedNames
    @State private var expandedAirPods = Set<String>()
    @State private var allNearcast = getFiles(withExtension: "json", in: ncFolder)

    private func hasFollowingVisibleRow(after index: Int) -> Bool {
        guard index + 1 < allDevices.count else { return false }
        return allDevices[(index + 1)...].contains {
            !AirBatteryModel.isAirPodsSecondaryRow($0, in: allDevices)
        }
    }

    private func configureBatteryAlert(for device: Device) {
        DeviceActions.configureBatteryAlert(for: device) {
            alertList = $0
        }
    }

    private func togglePin(for device: Device) {
        pinnedList = DeviceActions.togglePin(for: device)
    }

    private func hideAirPodsGroup(_ group: AirPodsBatteryGroup) {
        var blackList = AppPreferences.hiddenDeviceNames
        let devices = group.components
        for device in devices where !blackList.contains(device.deviceName) {
            blackList.append(device.deviceName)
        }
        AppPreferences.hiddenDeviceNames = blackList
        hiddenDevices = AirBatteryModel.getBlackList()
        allDevices.removeAll { device in
            devices.contains(where: { $0.deviceName == device.deviceName })
        }
    }

    private func airPodsPartLabel(_ device: Device) -> String {
        switch device.deviceType {
        case "ap_case": return "Case"
        case "ap_pod_left": return "Left"
        case "ap_pod_right": return "Right"
        case "ap_pod_all": return "Earbuds"
        default: return device.deviceName
        }
    }

    private func airPodsPresentation(
        _ group: AirPodsBatteryGroup
    ) -> LogicalDevicePresentation? {
        AirBatteryModel.logicalPresentations(
            from: group.components,
            mergeEarbuds: twsMergeEnabled,
            mergeThreshold: twsMerge
        ).first
    }

    @ViewBuilder
    private func airPodsMenuRow(
        _ group: AirPodsBatteryGroup,
        index: Int
    ) -> some View {
        if let presentation = airPodsPresentation(group) {
            let isExpanded = expandedAirPods.contains(presentation.id)

            PopoverCompoundDeviceSurfaceContent(
                presentation: presentation,
                compactName: fromDock,
                isExpanded: isExpanded,
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isExpanded {
                            expandedAirPods.remove(presentation.id)
                        } else {
                            expandedAirPods.insert(presentation.id)
                        }
                    }
                }
            )
            .background(
                overStack == index
                    ? Color.blackWhite.opacity(0.10)
                    : .clear
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .onHover { hovering in
                overStack2 = -1
                overStackNC = -1
                if hovering {
                    overStack = index
                }
            }
            .contextMenu {
                let components = group.components
                if !components.isEmpty {
                    Menu("Battery Alerts") {
                        ForEach(components, id: \.deviceID) { component in
                            Button(
                                alertList.contains(
                                    where: { $0.name == component.deviceName }
                                )
                                    ? "Edit \(airPodsPartLabel(component))"
                                    : "Add \(airPodsPartLabel(component))"
                            ) {
                                configureBatteryAlert(for: component)
                            }
                        }
                    }

                    Menu("Menu Bar Pins") {
                        ForEach(components, id: \.deviceID) { component in
                            Button(
                                pinnedList.contains(component.deviceName)
                                    ? "Unpin \(airPodsPartLabel(component))"
                                    : "Pin \(airPodsPartLabel(component))"
                            ) {
                                togglePin(for: component)
                            }
                        }
                    }
                    Divider()
                }

                Button("Copy Device Name") {
                    copyToClipboard(group.name)
                }
                Button("Hide AirPods Group") {
                    hideAirPodsGroup(group)
                }
            }
        }
    }

    private func menuPresentation(
        for device: Device
    ) -> LogicalDevicePresentation {
        LogicalDevicePresentation(
            id: "device:" + device.deviceID + ":" + device.deviceName,
            displayName: device.deviceName,
            compactName: DevicePresentationNaming.compactName(
                deviceType: device.deviceType,
                displayName: device.deviceName
            ),
            representative: device,
            components: [
                BatteryComponentPresentation(
                    role: .primary,
                    device: device
                )
            ],
            newestUpdate: device.lastUpdate
        )
    }

    private func genericInfoText(for device: Device) -> String {
        if device.deviceID == "@MacInternalBattery" {
            let prefix = device.isCharging != 0
                ? "Until Full:"
                : "Until Empty:"
            return "\(prefix) \(InternalBattery.status.timeLeft)"
        }

        let update =
            device.realUpdate != 0
                ? device.realUpdate
                : device.lastUpdate
        let minutes = Int(
            (Date().timeIntervalSince1970 - update) / 60
        )
        return "\(minutes) " + "mins ago".local
    }

    @ViewBuilder
    private func genericHoverControls(
        for device: Device,
        index: Int
    ) -> some View {
        DeviceRowHoverControls(
            infoText: genericInfoText(for: device),
            device: device,
            alerted: alertList.contains {
                $0.name == device.deviceName
            },
            pinned: pinnedList.contains(device.deviceName),
            canPin: device.deviceID != "@MacInternalBattery",
            canHide: device.deviceID != "@MacInternalBattery",
            onAlert: {
                configureBatteryAlert(for: device)
            },
            onPin: {
                togglePin(for: device)
            },
            onCopy: {
                copyToClipboard(device.deviceName)
                _ = createAlert(
                    title: "Device Name Copied".local,
                    message: String(
                        format:
                            "Device name \"%@\" has been copied to the clipboard.".local,
                        device.deviceName
                    ),
                    button1: "OK".local
                ).runModal()
            },
            onHide: {
                hidden.append(index)
                var blackList = AppPreferences.hiddenDeviceNames
                if !blackList.contains(device.deviceName) {
                    blackList.append(device.deviceName)
                }
                AppPreferences.hiddenDeviceNames = blackList
                if pinnedList.contains(device.deviceName) {
                    refeshPinnedBar()
                }
            }
        )
    }

    var body: some View {
        ZStack{
            if fromDock { Color.clear.background(BlurView(material: .menu)) }
            VStack(spacing: 0){
                PopoverToolbarSurfaceContent(
                    fromDock: fromDock,
                    nearcastEnabled: nearCast,
                    onHide: {
                        DockPopoverController.shared.hide()
                    },
                    onAbout: {
                        DockPopoverController.shared.hide()
                        StatusBarController.shared.cancelMenuTracking()
                        openAboutPanel()
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.2
                        ) {
                            NSApp.activate()
                        }
                    },
                    onSettings: {
                        DockPopoverController.shared.hide()
                        StatusBarController.shared.cancelMenuTracking()
                        openSettingPanel()
                    },
                    onQuit: {
                        let response = createAlert(
                            level: .warning,
                            title: "Quit AirBattery?",
                            message:
                                "AirBattery will stop monitoring device batteries until you launch it again.",
                            button1: "Quit",
                            button2: "Cancel"
                        ).runModal()
                        if response == .alertFirstButtonReturn {
                            NSApp.terminate(nil)
                        }
                    },
                    onRefreshNearcast: {
                        netcastService.refeshAll()
                        if fromDock {
                            DockPopoverController.shared.hide()
                        } else {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 0.5
                            ) {
                                allDevices = AirBatteryModel.getAll()
                                let ibStatus = InternalBattery.status
                                if ibStatus.hasBattery {
                                    allDevices.insert(
                                        ib2ab(ibStatus),
                                        at: 0
                                    )
                                }
                                allNearcast = getFiles(
                                    withExtension: "json",
                                    in: ncFolder
                                )
                            }
                        }
                    }
                )
                .onHover { _ in
                    (overStack, overStack2) = (-1, -1)
                }

                VStack(alignment:.leading,spacing: 0) {
                    if allDevices.count < 1 && hiddenDevices.count < 1{
                        HStack{
                            /*Image(systemName: "exclamationmark.circle")
                             .resizable()
                             .aspectRatio(contentMode: .fit)
                             .foregroundColor(.blackWhite)
                             .frame(width: 20, height: 20, alignment: .center)
                             Text("No Device Found!")
                             .font(.system(size: 12))
                             .foregroundColor(.blackWhite)
                             .frame(height: 24, alignment: .center)
                             .padding(.horizontal, 8)*/
                            let ib = ib2ab(InternalBattery.status)
                            Image(getDeviceIcon(ib))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.blackWhite)
                                .frame(width: 22, height: 22, alignment: .center)
                            Text("\(ib.deviceName)")
                                .font(.system(size: 12))
                                .foregroundColor(.blackWhite)
                                .frame(height: 24, alignment: .center)
                                .padding(.horizontal, 7)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 11)
                        .onHover{ hovering in
                            overStack2 = -1
                            overStackNC = -1
                            if hovering { overStack = 0 }
                        }
                        .background(overStack == 0 ? Color.blackWhite.opacity(0.15) : .clear)
                        if hiddenDevices.count > 0 { Divider() }
                    }
                    ForEach(allDevices.indices, id: \.self) { index in
                        if AirBatteryModel.isAirPodsSecondaryRow(allDevices[index], in: allDevices) {
                            EmptyView()
                        } else if let group = AirBatteryModel.airPodsGroup(
                            for: allDevices[index],
                            in: allDevices
                        ) {
                            VStack(spacing: 0) {
                                airPodsMenuRow(group, index: index)
                                if hasFollowingVisibleRow(after: index) {
                                    Divider()
                                }
                            }
                        } else {
                            VStack(spacing: 0){
                            if hidden.contains(index) {
                                HStack{
                                    Image("blank")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 24, alignment: .center)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                    Spacer()
                                }
                            } else {
                                let device = allDevices[index]
                                let presentation = menuPresentation(for: device)
                                MenuDeviceRowContent(
                                    presentation: presentation,
                                    compactName: fromDock,
                                    alerted: alertList.contains(
                                        where: { $0.name == device.deviceName }
                                    ),
                                    pinned: pinnedList.contains(device.deviceName),
                                    showBatteryTrailing: overStack != index
                                )
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .overlay(alignment: .trailing) {
                                    if overStack == index && device.hasBattery {
                                        genericHoverControls(
                                            for: device,
                                            index: index
                                        )
                                        .padding(.trailing, 10)
                                    }
                                }
                                .background(
                                    overStack == index
                                        ? Color.blackWhite.opacity(0.15)
                                        : .clear
                                )
                                .clipShape(
                                    RoundedCornersShape(
                                        radius: 2.9,
                                        corners:
                                            index == allDevices.count -
                                                (hiddenDevices.count > 0 ? 0 : 1)
                                                ? [.bottomLeft, .bottomRight]
                                                : (index == 0
                                                    ? [.topLeft, .topRight]
                                                    : [])
                                    )
                                )
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    overStack2 = -1
                                    overStackNC = -1
                                    if hovering {
                                        overStack = index
                                    }
                                }
                            }
                            if hasFollowingVisibleRow(after: index) { Divider() }
                        }
                        }
                    }
                    if hiddenDevices.count > 0 {
                        if allDevices.count > 0 { Divider() }
                        HStack(spacing: 5){
                            Image("sunglasses.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.blackWhite)
                                .frame(width: 22, height: 22, alignment: .center)
                                .padding(.vertical, 6)
                            Text("Hidden Device:")
                                .font(.system(size: 12))
                                .foregroundColor(.blackWhite)
                                .frame(height: 24, alignment: .center)
                                .padding(.horizontal, 10)
                            Spacer()
                            ForEach(hiddenDevices.indices, id: \.self) { index in
                                if !hidden2.contains(index){
                                    Button(action: {
                                        hidden2.append(index)
                                        var blackList = AppPreferences.hiddenDeviceNames
                                        blackList.removeAll { $0 == hiddenDevices[index].deviceName }
                                        AppPreferences.hiddenDeviceNames = blackList
                                        let pinnedList = AppPreferences.pinnedNames
                                        if pinnedList.contains(hiddenDevices[index].deviceName){
                                            refeshPinnedBar()
                                        }
                                    }, label: {
                                        Image(getDeviceIcon(hiddenDevices[index]))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 20, height: 20, alignment: .center)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 4)
                                            .background(overStack2 == index ? Color.blackWhite.opacity(0.15) : .clear).cornerRadius(2.5)
                                            .onHover{ hovering in
                                                overStack = -1
                                                overStackNC = -1
                                                if overStack2 != index { overStack2 = index }
                                            }
                                    })
                                    .buttonStyle(.plain)
                                    .focusable(false)
                                    .help(hiddenDevices[index].deviceName)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                        .padding(.horizontal, 10)
                        .onHover{ hovering in overStack = -1 }
                    }
                }
                .padding(.horizontal, 6)
                .popoverDevicePanelSurface()
                .offset(y: 2.5)
                if nearCast {
                    ForEach(allNearcast.indices, id: \.self) { index in
                        let devices = AirBatteryModel.ncGetAll(url: allNearcast[index])
                        if devices.count != 0 {
                            NearcastDeviceSection(devices: devices, mainIndex: index, overStackNC: $overStackNC)
                                .onHover{ hovering in
                                    overStack = -1
                                    overStack2 = -1
                                }
                        }
                    }
                }
            }
        }
        .frame(width: 352)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(PopoverHostSurfaceModifier(fromDock: fromDock))
        .onAppear { allDevices = allDevice }
        .onReceive(monitoring.$secondTick) { _ in
            if !fromDock && StatusBarController.shared.isMenuOpen {
                allDevices = AirBatteryModel.getAll()
                hiddenDevices = AirBatteryModel.getBlackList()
                hidden = [Int]()
                hidden2 = [Int]()
                let ibStatus = InternalBattery.status
                if ibStatus.hasBattery { allDevices.insert(ib2ab(ibStatus), at: 0) }
                if nearCast { allNearcast = getFiles(withExtension: "json", in: ncFolder) }
            }
        }
    }
}

struct NearcastDeviceSection: View {
    let devices: [Device]
    let mainIndex: Int
    @Binding var overStackNC: Int

    @State private var overStack = -1
    @State private var alertList =
        UserDefaults.standard.get(objectType: [btAlert].self, forKey: "alertList") ?? []
    @State private var pinnedList = AppPreferences.pinnedNames

    var body: some View {
        Spacer().frame(height: 8)

        VStack(spacing: 0) {
            ForEach(devices.indices, id: \.self) { index in
                let device = devices[index]
                let hovered =
                    overStackNC == mainIndex && overStack == index

                MenuDeviceRowContent(
                    presentation: presentation(for: device),
                    alerted: alertList.contains {
                        $0.name == device.deviceName
                    },
                    pinned: pinnedList.contains(device.deviceName),
                    showBatteryTrailing: !hovered
                )
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .overlay(alignment: .trailing) {
                    if hovered {
                        DeviceRowHoverControls(
                            infoText: ageText(for: device),
                            infoColor: .primary,
                            device: device,
                            alerted: alertList.contains {
                                $0.name == device.deviceName
                            },
                            pinned: pinnedList.contains(
                                device.deviceName
                            ),
                            onAlert: {
                                configureBatteryAlert(for: device)
                            },
                            onPin: {
                                pinnedList =
                                    DeviceActions.togglePin(for: device)
                            },
                            onCopy: {
                                copyToClipboard(device.deviceName)
                                _ = createAlert(
                                    title: "Device Name Copied".local,
                                    message: String(
                                        format:
                                            "Device name \"%@\" has been copied to the clipboard.".local,
                                        device.deviceName
                                    ),
                                    button1: "OK".local
                                ).runModal()
                            }
                        )
                        .padding(.trailing, 10)
                    }
                }
                .background(
                    hovered
                        ? Color.blackWhite.opacity(0.15)
                        : .clear
                )
                .clipShape(
                    RoundedCornersShape(
                        radius: 2.9,
                        corners:
                            index == devices.count - 1
                                ? [.bottomLeft, .bottomRight]
                                : (index == 0
                                    ? [.topLeft, .topRight]
                                    : [])
                    )
                )
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        overStack = index
                    }
                }

                if index != devices.count - 1 {
                    Divider()
                }
            }
        }
        .onHover { hovering in
            if hovering {
                overStackNC = mainIndex
            }
        }
        .padding(.horizontal, 6)
        .popoverDevicePanelSurface()
        .offset(y: 2.5)
    }

    private func presentation(
        for device: Device
    ) -> LogicalDevicePresentation {
        LogicalDevicePresentation(
            id: "nearcast:" + device.deviceID + ":" + device.deviceName,
            displayName: device.deviceName,
            compactName: DevicePresentationNaming.compactName(
                deviceType: device.deviceType,
                displayName: device.deviceName
            ),
            representative: device,
            components: [
                BatteryComponentPresentation(
                    role: .primary,
                    device: device
                )
            ],
            newestUpdate: device.lastUpdate
        )
    }

    private func ageText(for device: Device) -> String {
        let minutes = Int(
            (Date().timeIntervalSince1970 - device.lastUpdate) / 60
        )
        return "\(minutes) " + "mins ago".local
    }

    private func configureBatteryAlert(for device: Device) {
        DeviceActions.configureBatteryAlert(for: device) {
            alertList = $0
        }
    }
}


@MainActor
func openAboutPanel() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(nil)
}

@MainActor
func openSettingPanel() {
    DockPopoverController.shared.hide()
    (NSApp.delegate as? AppDelegate)?.presentSettings()
}


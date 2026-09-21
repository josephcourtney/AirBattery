//
//  ContentView.swift
//  AirBattery
//
//  Created by apple on 2023/9/4.
//
import AppKit
import SwiftUI
//import UserNotifications

struct MultiBatteryView: View {
    @AppStorage("showThisMac") var showThisMac = "icon"
    @AppStorage("carouselMode") var carouselMode = true
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("showOn") var showOn = "sbar"
    @AppStorage("twsMergeEnabled") private var twsMergeEnabled = true
    @AppStorage("twsMerge") private var twsMerge = 5

    @Environment(\.colorScheme) private var systemColorScheme
    @ObservedObject private var monitoring = MonitoringCoordinator.shared

    @State private var rollCount = 1
    @State private var lastTime = Double(Date().timeIntervalSince1970)
    @State private var presentationList: [LogicalDevicePresentation] = []

    var body: some View {
        DockTileSurfaceContent(
            presentations: presentationList,
            darkMode: darkMode,
            showMacAsPercent: showThisMac == "percent"
        )
        .onAppear {
            refreshDockPresentations(now: Date().timeIntervalSince1970)
        }
        .onChange(of: systemColorScheme) { _, _ in
            NSApp.dockTile.display()
        }
        .onChange(of: appearance) { _, _ in
            NSApp.dockTile.display()
        }
        .onChange(of: twsMergeEnabled) { _, _ in
            refreshDockPresentations(now: Date().timeIntervalSince1970)
        }
        .onChange(of: twsMerge) { _, _ in
            refreshDockPresentations(now: Date().timeIntervalSince1970)
        }
        .onReceive(monitoring.$fiveSecondTick) { time in
            guard showOn == "both" || showOn == "dock" else { return }
            refreshDockPresentations(now: time.timeIntervalSince1970)
            NSApp.dockTile.display()
        }
    }

    private var darkMode: Bool {
        switch appearance {
        case "true":
            return true
        case "false":
            return false
        default:
            return systemColorScheme == .dark
        }
    }

    private func refreshDockPresentations(now: Double) {
        var devices = AirBatteryModel.getAll()
        for url in getFiles(withExtension: "json", in: ncFolder) {
            devices += AirBatteryModel.ncGetAll(url: url)
        }

        let internalStatus = InternalBattery.status
        if internalStatus.hasBattery && showThisMac != "hidden" {
            devices.insert(ib2ab(internalStatus), at: 0)
        }

        let logical = AirBatteryModel.logicalPresentations(
            from: devices,
            mergeEarbuds: twsMergeEnabled,
            mergeThreshold: twsMerge
        )

        if !carouselMode {
            rollCount = 1
        }

        var page = logicalPage(logical, page: rollCount)
        if page.isEmpty && !logical.isEmpty {
            rollCount = 1
            page = logicalPage(logical, page: rollCount)
        }
        presentationList = page

        if now - lastTime >= 20 && logical.count > 4 && carouselMode {
            lastTime = now
            rollCount += 1
        }
    }

    private func logicalPage(
        _ devices: [LogicalDevicePresentation],
        page: Int
    ) -> [LogicalDevicePresentation] {
        let start = max(0, (page - 1) * 4)
        guard start < devices.count else { return [] }
        return Array(devices[start..<min(start + 4, devices.count)])
    }


}

struct BlurView: NSViewRepresentable {
    
    private let material: NSVisualEffectView.Material
    
    init(material: NSVisualEffectView.Material) {
        self.material = material
    }
    
    func makeNSView(context: Context) -> some NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView.material = material
    }
}

private struct PopoverHostSurfaceModifier: ViewModifier {
    let fromDock: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if fromDock {
            content.liquidGlassEffect(
                cornerRadius: 8,
                interactive: true,
                tint: .primary.opacity(0.04)
            )
        } else {
            content
        }
    }
}

private enum DeviceActions {
    static func configureBatteryAlert(
        for device: Device,
        onChange: @escaping ([btAlert]) -> Void
    ) {
        let alerts =
            ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
        let initial = alerts.first { $0.name == device.deviceName } ??
            btAlert(
                name: device.deviceName,
                full: 80,
                fullOn: true,
                fullSound: true,
                low: 20,
                lowOn: true,
                lowSound: true
            )

        let controller = AlertWindowController()
        controller.showAlert(
            with: initial,
            iconName: getDeviceIcon(device),
            onConfirm: { newAlert in
                var updated =
                    ud.get(
                        objectType: [btAlert].self,
                        forKey: "alertList"
                    ) ?? []
                updated.removeAll { $0.name == device.deviceName }
                updated.append(newAlert)
                ud.set(object: updated, forKey: "alertList")
                onChange(updated)
            },
            onCancel: {}
        )
    }

    static func togglePin(for device: Device) -> [String] {
        var names = AppPreferences.pinnedNames
        if names.contains(device.deviceName) {
            names.removeAll { $0 == device.deviceName }
            AppPreferences.pinnedNames = names
            refeshPinnedBar(unpin: device.deviceName)
        } else {
            names.append(device.deviceName)
            AppPreferences.pinnedNames = names
            refeshPinnedBar()
        }
        return names
    }
}

private struct DeviceRowHoverControls: View {
    let infoText: String
    let infoColor: Color
    let device: Device
    let alerted: Bool
    let pinned: Bool
    let canPin: Bool
    let canHide: Bool
    let onAlert: () -> Void
    let onPin: () -> Void
    let onCopy: () -> Void
    let onHide: () -> Void

    init(
        infoText: String,
        infoColor: Color = .secondary,
        device: Device,
        alerted: Bool,
        pinned: Bool,
        canPin: Bool = true,
        canHide: Bool = false,
        onAlert: @escaping () -> Void,
        onPin: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onHide: @escaping () -> Void = {}
    ) {
        self.infoText = infoText
        self.infoColor = infoColor
        self.device = device
        self.alerted = alerted
        self.pinned = pinned
        self.canPin = canPin
        self.canHide = canHide
        self.onAlert = onAlert
        self.onPin = onPin
        self.onCopy = onCopy
        self.onHide = onHide
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(infoText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(infoColor)

            Spacer().frame(width: 1)

            if device.hasBattery {
                DeviceRowActionButton(
                    imageName: alerted
                        ? "bell.circle.fill"
                        : "bell.circle",
                    help: alerted ? "Edit battery alert" : "Add battery alert",
                    action: onAlert
                )

                if canPin {
                    DeviceRowActionButton(
                        imageName: pinned
                            ? "pin.circle.fill"
                            : "pin.circle",
                        help: pinned ? "Unpin from menu bar" : "Pin to menu bar",
                        action: onPin
                    )
                }

                DeviceRowActionButton(
                    imageName: "list.clipboard.fill.circle",
                    help: "Copy device name",
                    action: onCopy
                )

                if canHide {
                    DeviceRowActionButton(
                        imageName: "eye.slash.circle",
                        help: "Hide device",
                        action: onHide
                    )
                }
            }
        }
    }
}

private struct DeviceRowActionButton: View {
    let imageName: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundColor(
                    isHovered ? .accentColor : .secondary
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .onHover { isHovered = $0 }
    }
}

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
    @State private var alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
    @State private var pinnedList = AppPreferences.pinnedNames
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
        var blackList = AppPreferences.blockedNames
        let devices = group.components
        for device in devices where !blackList.contains(device.deviceName) {
            blackList.append(device.deviceName)
        }
        AppPreferences.blockedNames = blackList
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
            MenuDeviceRowContent(
                presentation: presentation,
                compactName: fromDock
            )
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                overStack == index
                    ? Color.blackWhite.opacity(0.15)
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

    @ViewBuilder
    private func genericHoverControls(
        for device: Device,
        index: Int
    ) -> some View {
        let infoText: String
        if device.deviceID == "@MacInternalBattery" {
            let prefix = device.isCharging != 0
                ? "Until Full:"
                : "Until Empty:"
            infoText = "\(prefix) \(InternalBattery.status.timeLeft)"
        } else {
            let update =
                device.realUpdate != 0
                    ? device.realUpdate
                    : device.lastUpdate
            let minutes = Int(
                (Date().timeIntervalSince1970 - update) / 60
            )
            infoText = "\(minutes) " + "mins ago".local
        }

        DeviceRowHoverControls(
            infoText: infoText,
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
                var blackList = AppPreferences.blockedNames
                if !blackList.contains(device.deviceName) {
                    blackList.append(device.deviceName)
                }
                AppPreferences.blockedNames = blackList
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
                if !fromDock {
                    Color.clear
                        .frame(height: 8.5)
                        .onHover { hovering in
                            if hovering {
                                overStack = -1
                                overStack2 = -1
                                overStackNC = -1
                            }
                        }
                }
                PopoverToolbarSurfaceContent(
                    fromDock: fromDock,
                    nearcastEnabled: nearCast,
                    onHide: {
                        dockWindow.orderOut(nil)
                    },
                    onAbout: {
                        dockWindow.orderOut(nil)
                        statusBarItem.menu?.cancelTracking()
                        openAboutPanel()
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.2
                        ) {
                            NSApp.activate()
                        }
                    },
                    onSettings: {
                        dockWindow.orderOut(nil)
                        statusBarItem.menu?.cancelTracking()
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
                            dockWindow.orderOut(nil)
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
                                        var blackList = AppPreferences.blockedNames
                                        blackList.removeAll { $0 == hiddenDevices[index].deviceName }
                                        AppPreferences.blockedNames = blackList
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
                            nearcastView(devices: devices, mainIndex: index, overStackNC: $overStackNC)
                                .onHover{ hovering in
                                    overStack = -1
                                    overStack2 = -1
                                }
                        }
                    }
                }
                if !fromDock {
                    Color.clear
                        .frame(height: 8.5)
                        .onHover { hovering in
                            if hovering {
                                overStack = -1
                                overStack2 = -1
                                overStackNC = -1
                            }
                        }
                }
            }
        }
        .frame(width: 352)
        .modifier(PopoverHostSurfaceModifier(fromDock: fromDock))
        .onAppear { allDevices = allDevice }
        .onReceive(monitoring.$secondTick) { _ in
            if !fromDock && statusMenuIsOpen {
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

struct nearcastView: View {
    var devices: [Device]
    var mainIndex: Int
    @Binding var overStackNC: Int
    @State private var overStack = -1
    @State private var overCopyButton = false
    @State private var overAlertButton = false
    @State private var overPinButton = false
    @State private var alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
    @State private var pinnedList = AppPreferences.pinnedNames
    
    var body: some View {
        Spacer().frame(height: 8)
        VStack(spacing: 0){
            ForEach(devices.indices, id: \.self) { index in
                VStack(spacing: 0){
                    HStack {
                        Image(getDeviceIcon(devices[index]))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.blackWhite)
                            .frame(width: 22, height: 22, alignment: .center)
                        HStack(spacing: 1) {
                            Text("\(((Date().timeIntervalSince1970 - devices[index].lastUpdate) / 60) > 10 ? "⚠︎ " : "")\(devices[index].deviceName)")
                                .font(.system(size: 12))
                                .foregroundColor(.blackWhite)
                                .frame(height: 24, alignment: .center)
                                .padding(.horizontal, 7)
                            Spacer().frame(width: 0.5)
                            if alertList.map({$0.name}).contains(devices[index].deviceName) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blackWhite)
                            }
                            if pinnedList.contains(devices[index].deviceName) {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blackWhite)
                                    .offset(y: 0.2)
                            }
                        }.padding(.horizontal, 7)
                        if overStackNC == mainIndex && overStack == index {
                            Spacer()
                            HStack(spacing: 3) {
                                Text("\(Int((Date().timeIntervalSince1970 - devices[index].lastUpdate) / 60))"+" mins ago".local)
                                    .font(.system(size: 11))
                                if devices[index].hasBattery {
                                    Spacer().frame(width: 1)
                                    if !alertList.map({$0.name}).contains(devices[index].deviceName) {
                                        Button(action: {
                                            let alert = btAlert(name: devices[index].deviceName,
                                                                full: 80, fullOn: true, fullSound: true,
                                                                low: 20, lowOn: true, lowSound: true)
                                            let alertWindowController = AlertWindowController()
                                            alertWindowController.showAlert(with: alert, iconName: getDeviceIcon(devices[index]), onConfirm: { newAlert in
                                                alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
                                                alertList.append(newAlert)
                                                ud.set(object: alertList, forKey: "alertList")
                                            }, onCancel: {})
                                        }, label: {
                                            Image("bell.circle")
                                                .resizable().scaledToFit()
                                                .frame(width: 18, height: 18, alignment: .center)
                                                .foregroundColor(overAlertButton ? .accentColor : .secondary)
                                        })
                                        .buttonStyle(PlainButtonStyle())
                                        .onHover{ hovering in overAlertButton = hovering }
                                    } else {
                                        Button(action: {
                                            alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
                                            if let alert = alertList.first(where: {$0.name == devices[index].deviceName}) {
                                                let alertWindowController = AlertWindowController()
                                                alertWindowController.showAlert(with: alert, iconName: getDeviceIcon(devices[index]), onConfirm: { newAlert in
                                                    alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
                                                    alertList.removeAll(where: {$0.name == devices[index].deviceName})
                                                    alertList.append(newAlert)
                                                    ud.set(object: alertList, forKey: "alertList")
                                                }, onCancel: {})
                                            }
                                        }, label: {
                                            Image("bell.circle.fill")
                                                .resizable().scaledToFit()
                                                .frame(width: 18, height: 18, alignment: .center)
                                                .foregroundColor(overAlertButton ? .accentColor : .secondary)
                                        })
                                        .buttonStyle(PlainButtonStyle())
                                        .onHover{ hovering in overAlertButton = hovering }
                                    }
                                    if !pinnedList.contains(devices[index].deviceName) {
                                        Button(action: {
                                            pinnedList = AppPreferences.pinnedNames
                                            pinnedList.append(devices[index].deviceName)
                                            AppPreferences.pinnedNames = pinnedList
                                            refeshPinnedBar()
                                        }, label: {
                                            Image("pin.circle")
                                                .resizable().scaledToFit()
                                                .frame(width: 18, height: 18, alignment: .center)
                                                .foregroundColor(overPinButton ? .accentColor : .secondary)
                                        })
                                        .buttonStyle(PlainButtonStyle())
                                        .onHover{ hovering in overPinButton = hovering }
                                    } else {
                                        Button(action: {
                                            pinnedList = AppPreferences.pinnedNames
                                            pinnedList.removeAll { $0 == devices[index].deviceName }
                                            AppPreferences.pinnedNames = pinnedList
                                            refeshPinnedBar()
                                        }, label: {
                                            Image("pin.circle.fill")
                                                .resizable().scaledToFit()
                                                .frame(width: 18, height: 18, alignment: .center)
                                                .foregroundColor(overPinButton ? .accentColor : .secondary)
                                        })
                                        .buttonStyle(PlainButtonStyle())
                                        .onHover{ hovering in overPinButton = hovering }
                                    }
                                    Button(action: {
                                        copyToClipboard(devices[index].deviceName)
                                        _ = createAlert(title: "Device Name Copied".local,
                                                        message: String(format: "Device name \"%@\" has been copied to the clipboard.".local, devices[index].deviceName),
                                                        button1: "OK".local).runModal()
                                    }, label: {
                                        Image("list.clipboard.fill.circle")
                                            .resizable().scaledToFit()
                                            .frame(width: 18, height: 18, alignment: .center)
                                            .foregroundColor(overCopyButton ? .accentColor : .secondary)
                                    })
                                    .buttonStyle(PlainButtonStyle())
                                    .onHover{ hovering in overCopyButton = hovering }
                                }
                            }
                        } else {
                            Spacer()
                            if devices[index].hasBattery {
                                Text("\(devices[index].batteryLevel)%")
                                    .foregroundColor((devices[index].batteryLevel <= 10) ? Color.darkMyRed : .primary)
                                    .font(.system(size: 11))
                                BatteryView(item: devices[index])
                                    .scaleEffect(0.85)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .onHover{ hovering in overStack = index }
                }
                .background((overStackNC == mainIndex && overStack == index) ? Color.blackWhite.opacity(0.15) : .clear)
                .clipShape(RoundedCornersShape(radius: 2.9, corners: index == devices.count - 1 ? [.bottomLeft, .bottomRight] : (index == 0 ? [.topLeft, .topRight] : [])))
                if index != devices.count-1 { Divider() }
            }
        }
        .onHover{ hovering in overStackNC = mainIndex }
        .padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.secondary, lineWidth: 1)
                .padding(.vertical, -1)
                .padding(.horizontal, 5)
                .opacity(0.23)
        )
        .liquidGlassPanel(cornerRadius: 5, tint: .primary.opacity(0.02))
        .offset(y: 2.5)
    }

}

func openAboutPanel() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(nil)
}

func openSettingPanel() {
    dockWindow.orderOut(nil)
    Task { @MainActor in
        SettingsWindowController.shared.present()
    }
}


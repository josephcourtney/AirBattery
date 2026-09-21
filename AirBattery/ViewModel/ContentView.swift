//
//  ContentView.swift
//  AirBattery
//
//  Created by apple on 2023/9/4.
//
import AppKit
import SwiftUI
import WidgetKit
import Combine
//import UserNotifications

/*let test_data: [CGFloat] = [99,80,80,73,70,60,59,51,30,30,25,25,19,18,17,15,12,10,10,9] // 示例数据
struct BarChartView: View {
    let data: [CGFloat] // 电量数据，取值范围 0 到 1
    let barSpacing: CGFloat // 柱子之间的间距
    let barWidth: CGFloat // 柱子宽度

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: barSpacing) { // 设置底部对齐
                ForEach(0..<data.count, id: \.self) { index in
                    let height = (data[index] * geometry.size.height)/100
                    Capsule()
                        .fill(Color(getPowerColor(Int(data[index]))))
                        .frame(width: barWidth, height: height)
                        .padding(.bottom, -barWidth / 2) // 设置底部平坦
                }
            }
        }
    }
}*/

class AppearanceMonitor: ObservableObject {
    @Published var isDarkMode: Bool = false
    private var appearanceChangeCancellable: AnyCancellable?

    init() {
        updateAppearance()
        appearanceChangeCancellable = NotificationCenter.default.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAppearance()
            }
    }
    private func updateAppearance() {
        let appearance = NSApp.effectiveAppearance
        isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

struct MultiBatteryView: View {
    @AppStorage("showThisMac") var showThisMac = "icon"
    @AppStorage("carouselMode") var carouselMode = true
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("showOn") var showOn = "sbar"
    @AppStorage("widgetInterval") var widgetInterval = 0
    @AppStorage("readBTHID") var readBTHID = true
    @AppStorage("deviceName") var deviceName = "Mac"
    @AppStorage("nearCast") var nearCast = false
    @AppStorage("nearcastGroupID") var nearcastGroupID = ""
    @AppStorage("nearcastSharingKey") var nearcastSharingKey = ""
    
    @StateObject private var appearanceMonitor = AppearanceMonitor()

    @State private var rollCount = 1
    @State private var darkMode = getDarkMode()
    @State private var lastTime = Double(Date().timeIntervalSince1970)
    @State private var batteryList = AirBatteryModel.getAll()
    @State private var lineWidth = 6.0
    
    var body: some View {
        ZStack {
            Group{
                Image(darkMode ? "background_dark" : "background")
                RoundedRectangle(cornerRadius: 23.5, style: RoundedCornerStyle.continuous)
                    .strokeBorder(darkMode ? .white : .black, lineWidth: 2)
                    .frame(width: 104, height: 104)
                    .opacity(darkMode ? 0.25 : 0.0)
                RoundedRectangle(cornerRadius: 23.5, style: RoundedCornerStyle.continuous)
                    .strokeBorder(.black, lineWidth: 1)
                    .frame(width: 104, height: 104)
                    .opacity(darkMode ? 0.55 : 0.2)
            }
            if batteryList.count < 4 {
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth*1.2, lineCap: .round, lineJoin: .round))
                    .foregroundColor(darkMode ? .white : .black)
                    .opacity(darkMode ? 0.2 : 0.13)
                    .rotationEffect(Angle(degrees: 135))
                    .offset(x:-24, y: -24)
                    .frame(width: 38, height: 38, alignment: .center)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(batteryList[0..<2], id: \.self) { item in
                            ZStack {
                                Group {
                                    Group {
                                        Circle()
                                            .trim(from: 0.0, to: 0.75)
                                            .stroke(style: StrokeStyle(lineWidth: lineWidth*1.2, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(darkMode ? .white : .black)
                                            .opacity(darkMode ? 0.2 : 0.13)
                                        Circle()
                                            .trim(from: CGFloat(abs((min(Double(item.batteryLevel)/100.0*0.75, 0.75))-0.001)), to: CGFloat(abs((min(Double(item.batteryLevel)/100.0*0.75, 0.75))-0.0005)))
                                            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(Color(getPowerColor(item)))
                                            .shadow(color: .black, radius: lineWidth*0.76, x: 0, y: 0)
                                            .clipShape(
                                                Circle()
                                                    .trim(from: 0.0, to: 0.75)
                                                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                            )
                                            .opacity(item.batteryLevel == 100 ? 0 : 1)
                                        Circle()
                                            .trim(from: 0.0, to: Double(item.batteryLevel)/100.0*0.75)
                                            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(Color(getPowerColor(item)))
                                    }.rotationEffect(Angle(degrees: 135))
                                    
                                    if item.deviceType.contains("mac") && showThisMac == "percent"{
                                        Text(String(item.batteryLevel))
                                            .colorScheme(darkMode ? .dark : .light)
                                            .foregroundColor(item.isCharging != 0 ? Color("dark_"+getPowerColor(item)) : .blackWhite)
                                            .font(.custom("Helvetica-Bold", size: item.batteryLevel>99 ? 32 : 42))
                                            .frame(width: 100, alignment: .center)
                                            .scaleEffect(0.5)
                                            .offset(x:-0.2, y:1.5)
                                        
                                    } else {
                                        Image(getDeviceIcon(item))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .colorScheme(darkMode ? .dark : .light)
                                            .foregroundColor(item.isCharging != 0 ? Color("dark_"+getPowerColor(item)) : .blackWhite)
                                            .offset(y:-1)
                                            .frame(width: 44, height: 43, alignment: .center)
                                            .scaleEffect(0.5)
                                    }
                                }.frame(width: 38, height: 38, alignment: .center)
                                Text(item.hasBattery ? "\(item.batteryLevel)" : "")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(darkMode ? .white : .black)
                                    .scaleEffect(0.5)
                                    .offset(y: 17)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        ForEach(batteryList[2..<4], id: \.self) { item in
                            ZStack {
                                Group {
                                    Group {
                                        Circle()
                                            .trim(from: 0.0, to: 0.75)
                                            .stroke(style: StrokeStyle(lineWidth: lineWidth*1.2, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(darkMode ? .white : .black)
                                            .opacity(darkMode ? 0.2 : 0.13)
                                        Circle()
                                            .trim(from: CGFloat(abs((min(Double(item.batteryLevel)/100.0*0.75, 0.75))-0.001)), to: CGFloat(abs((min(Double(item.batteryLevel)/100.0*0.75, 0.75))-0.0005)))
                                            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(Color(getPowerColor(item)))
                                            .shadow(color: .black, radius: lineWidth*0.76, x: 0, y: 0)
                                            .clipShape(
                                                Circle()
                                                    .trim(from: 0.0, to: 0.75)
                                                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                            )
                                            .opacity(item.batteryLevel == 100 ? 0 : 1)
                                        Circle()
                                            .trim(from: 0.0, to: Double(item.batteryLevel)/100.0*0.75)
                                            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                                            .foregroundColor(Color(getPowerColor(item)))
                                    }.rotationEffect(Angle(degrees: 135))
                                    Image(getDeviceIcon(item))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .colorScheme(darkMode ? .dark : .light)
                                        .foregroundColor(item.isCharging != 0 ? Color("dark_"+getPowerColor(item)) : .blackWhite)
                                        .offset(y:-1)
                                        .frame(width: 44, height: 43, alignment: .center)
                                        .scaleEffect(0.5)
                                }.frame(width: 38, height: 38, alignment: .center)
                                Text(item.hasBattery ? "\(item.batteryLevel)" : "")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(darkMode ? .white : .black)
                                    .scaleEffect(0.5)
                                    .offset(y: 17)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 128, height: 128, alignment: .center)
        .onChange(of: appearanceMonitor.isDarkMode) { newValue in
            darkMode = newValue
            NSApp.dockTile.display()
        }
        .onChange(of: appearance) { _ in
            darkMode = getDarkMode()
            NSApp.dockTile.display()
        }
        .onReceive(alertTimer) {_ in batteryAlert() }
        .onReceive(widgetViewTimer) {_ in
            if widgetInterval != -1 { WidgetCenter.shared.reloadAllTimelines() }
        }
        .onReceive(dockTimer) {_ in IDeviceBattery.shared.scanDevices() }
        .onReceive(widgetDataTimer) {_ in
            SPBluetoothDataModel.shared.refeshData (completion: { result in
                DispatchQueue.global(qos: .background).async {
                    MagicBattery.shared.scanDevices()
                    AirBatteryModel.writeData()
                }
            }, error: {
                AirBatteryModel.writeData()
            })
        }
        .onReceive(nearCastTimer) {_ in
            if nearCast && isNearcastCredentialValid(
                groupID: nearcastGroupID,
                sharingKey: nearcastSharingKey
            ) {
                var allDevices = AirBatteryModel.getAll()
                allDevices.insert(ib2ab(InternalBattery.status), at: 0)
                do {
                    let jsonData = try JSONEncoder().encode(allDevices)
                    guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
                    guard let data = encryptNearcastString(
                        jsonString,
                        groupID: nearcastGroupID,
                        sharingKey: nearcastSharingKey
                    ) else { return }
                    let message = NCMessage(
                        id: nearcastGroupID,
                        sender: systemUUID ?? deviceName,
                        command: "",
                        content: data
                    )
                    netcastService.sendMessage(message)
                } catch {
                    print("Write JSON error：\(error)")
                }
            }
        }
        .onReceive(dockTimer) { t in
            if showOn == "both" || showOn == "dock" {
                var list = AirBatteryModel.getAll()
                let ncFiles = getFiles(withExtension: "json", in: ncFolder)
                for ncFile in ncFiles { list += AirBatteryModel.ncGetAll(url: ncFile) }
                let ibStatus = InternalBattery.status
                let now = Double(t.timeIntervalSince1970)
                
                if !carouselMode { rollCount = 1 }
                if ibStatus.hasBattery && showThisMac != "hidden" { list.insert(ib2ab(ibStatus), at: 0) }
                
                batteryList = sliceList(data: list, length: 4, count: rollCount)
                if batteryList == []{
                    rollCount = 1
                    batteryList = sliceList(data: list, length: 4, count: rollCount)
                }
                
                if now - lastTime >= 20 && list.count > 4 && carouselMode {
                    lastTime = now
                    rollCount = rollCount + 1
                }
                NSApp.dockTile.display()
            }
        }
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

private struct PopoverToolbarButton: View {
    let systemName: String
    let help: String
    var hoverColor: Color = .accentColor
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 28, height: 28)
                .foregroundColor(isHovered ? hoverColor : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered ? hoverColor.opacity(0.12) : Color.clear)
                )
                .contentShape(Rectangle())
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
    
    @State private var allDevices = [Device]()
    @State private var hiddenDevices = AirBatteryModel.getBlackList()
    @State private var overCopyButton = false
    @State private var overHideButton = false
    @State private var overAlertButton = false
    @State private var overPinButton = false
    @State private var overStack = -1
    @State private var overStack2 = -1
    @State private var overStackNC = -1
    @State private var hidden = [Int]()
    @State private var hidden2 = [Int]()
    @State private var alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
    @State private var pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
    @State private var allNearcast = getFiles(withExtension: "json", in: ncFolder)

    private func hasFollowingVisibleRow(after index: Int) -> Bool {
        guard index + 1 < allDevices.count else { return false }
        return allDevices[(index + 1)...].contains {
            !AirBatteryModel.isAirPodsSecondaryRow($0, in: allDevices)
        }
    }

    private func configureBatteryAlert(for device: Device) {
        alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
        let controller = AlertWindowController()

        if let existing = alertList.first(where: { $0.name == device.deviceName }) {
            controller.showAlert(
                with: existing,
                iconName: getDeviceIcon(device),
                onConfirm: { newAlert in
                    alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
                    alertList.removeAll { $0.name == device.deviceName }
                    alertList.append(newAlert)
                    ud.set(object: alertList, forKey: "alertList")
                },
                onCancel: {}
            )
        } else {
            let newAlert = btAlert(
                name: device.deviceName,
                full: 80,
                fullOn: true,
                fullSound: true,
                low: 20,
                lowOn: true,
                lowSound: true
            )
            controller.showAlert(
                with: newAlert,
                iconName: getDeviceIcon(device),
                onConfirm: { confirmed in
                    alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
                    alertList.append(confirmed)
                    ud.set(object: alertList, forKey: "alertList")
                },
                onCancel: {}
            )
        }
    }

    private func togglePin(for device: Device) {
        pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
        if pinnedList.contains(device.deviceName) {
            pinnedList.removeAll { $0 == device.deviceName }
            refeshPinnedBar(unpin: device.deviceName)
        } else {
            pinnedList.append(device.deviceName)
            refeshPinnedBar()
        }
        ud.set(pinnedList, forKey: "pinnedList")
    }

    private func hideAirPodsGroup(_ group: AirPodsBatteryGroup) {
        var blackList = (ud.object(forKey: "blackList") ?? []) as! [String]
        var devices = group.components
        if let legacy = group.legacyMergedEarbuds {
            devices.append(legacy)
        }
        for device in devices where !blackList.contains(device.deviceName) {
            blackList.append(device.deviceName)
        }
        ud.set(blackList, forKey: "blackList")
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

    @ViewBuilder
    private func airPodsLevel(
        iconDevice: Device,
        level: Int,
        charging: Int,
        help: String
    ) -> some View {
        HStack(spacing: 3) {
            Text("\(level)%")
                .font(.system(size: 11))
                .foregroundColor(level <= 10 ? .darkMyRed : .primary)
            Image(getDeviceIcon(iconDevice))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.blackWhite)
                .frame(width: 12, height: 12)
                .help(help)
            if charging != 0 {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 24)
        .fixedSize()
        .help(help)
    }

    private func mergedAirPodsIconDevice(
        _ group: AirPodsBatteryGroup,
        level: Int,
        charging: Int
    ) -> Device {
        let source = group.leftEarbud ?? group.rightEarbud ?? group.caseDevice
        return Device(
            deviceID: source?.deviceID ?? "@AirPodsMerged",
            deviceType: "ap_pod_all",
            deviceName: group.name,
            deviceModel: source?.deviceModel,
            batteryLevel: level,
            isCharging: charging,
            lastUpdate: source?.lastUpdate ?? Date().timeIntervalSince1970
        )
    }

    @ViewBuilder
    private func airPodsMenuRow(_ group: AirPodsBatteryGroup, index: Int) -> some View {
        let newestUpdate = group.components.map(\.lastUpdate).max() ?? 0
        HStack {
            if let caseDevice = group.caseDevice {
                Image(getDeviceIcon(caseDevice))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blackWhite)
                    .frame(width: 22, height: 22)
            }

            HStack(spacing: 1) {
                Text("\((Date().timeIntervalSince1970 - newestUpdate) / 60 > 10 ? "⚠︎ " : "")\(group.name)")
                    .font(.system(size: 12))
                    .foregroundColor(.blackWhite)
                    .frame(height: 24, alignment: .center)
                    .lineLimit(1)
                Spacer().frame(width: 0.5)
            }
            .padding(.horizontal, 7)

            Spacer()

            HStack(spacing: 7) {
                if let caseDevice = group.caseDevice {
                    airPodsLevel(
                        iconDevice: caseDevice,
                        level: caseDevice.batteryLevel,
                        charging: caseDevice.isCharging,
                        help: "Case"
                    )
                }

                if let merged = group.mergedEarbudLevel(
                    enabled: twsMergeEnabled,
                    threshold: twsMerge
                ) {
                    let charging = group.mergedEarbudCharging(
                        enabled: twsMergeEnabled,
                        threshold: twsMerge
                    ) ?? 0
                    airPodsLevel(
                        iconDevice: mergedAirPodsIconDevice(
                            group,
                            level: merged,
                            charging: charging
                        ),
                        level: merged,
                        charging: charging,
                        help: "Left and right earbuds"
                    )
                } else {
                    if let left = group.leftEarbud {
                        airPodsLevel(
                            iconDevice: left,
                            level: left.batteryLevel,
                            charging: left.isCharging,
                            help: "Left earbud"
                        )
                    }
                    if let right = group.rightEarbud {
                        airPodsLevel(
                            iconDevice: right,
                            level: right.batteryLevel,
                            charging: right.isCharging,
                            help: "Right earbud"
                        )
                    }
                    if group.leftEarbud == nil,
                       group.rightEarbud == nil,
                       let legacy = group.legacyMergedEarbuds {
                        airPodsLevel(
                            iconDevice: legacy,
                            level: legacy.batteryLevel,
                            charging: legacy.isCharging,
                            help: "Left and right earbuds"
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(overStack == index ? Color.blackWhite.opacity(0.15) : .clear)
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
                            alertList.contains(where: { $0.name == component.deviceName })
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
                HStack(spacing: 2) {
                    if !fromDock {
                        PopoverToolbarButton(
                            systemName: "xmark.circle.fill",
                            help: "Quit AirBattery".local,
                            hoverColor: .red
                        ) {
                            NSApp.terminate(self)
                        }
                    } else {
                        PopoverToolbarButton(
                            systemName: "minus.circle.fill",
                            help: "Hide".local,
                            hoverColor: .myYellow
                        ) {
                            dockWindow.orderOut(nil)
                        }
                    }

                    PopoverToolbarButton(systemName: "info.circle.fill", help: "About AirBattery".local) {
                        dockWindow.orderOut(nil)
                        statusBarItem.menu?.cancelTracking()
                        openAboutPanel()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }

                    PopoverToolbarButton(systemName: "gearshape", help: "Settings".local) {
                        dockWindow.orderOut(nil)
                        statusBarItem.menu?.cancelTracking()
                        openSettingPanel()
                    }

                    Spacer()

                    if nearCast {
                        PopoverToolbarButton(
                            systemName: "antenna.radiowaves.left.and.right.circle",
                            help: "Refresh Nearcast".local
                        ) {
                            netcastService.refeshAll()
                            if fromDock {
                                dockWindow.orderOut(nil)
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    allDevices = AirBatteryModel.getAll()
                                    let ibStatus = InternalBattery.status
                                    if ibStatus.hasBattery {
                                        allDevices.insert(ib2ab(ibStatus), at: 0)
                                    }
                                    allNearcast = getFiles(withExtension: "json", in: ncFolder)
                                }
                            }
                        }
                    }
                }
                .padding(.top, fromDock ? 8 : 6)
                .padding(.bottom, 4)
                .padding(.horizontal, 8)
                .onHover{ hovering in (overStack, overStack2) = (-1, -1) }
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
                            }else{
                                HStack {
                                    Image(getDeviceIcon(allDevices[index]))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(.blackWhite)
                                        .frame(width: 22, height: 22, alignment: .center)
                                    HStack(spacing: 1) {
                                        Text("\(((Date().timeIntervalSince1970 - allDevices[index].lastUpdate) / 60) > 10 ? "⚠︎ " : "")\(allDevices[index].deviceName)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blackWhite)
                                            .frame(height: 24, alignment: .center)
                                        Spacer().frame(width: 0.5)
                                        if alertList.map({$0.name}).contains(allDevices[index].deviceName) {
                                            Image(systemName: "bell.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.blackWhite)
                                        }
                                        if pinnedList.contains(allDevices[index].deviceName) {
                                            Image(systemName: "pin.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.blackWhite)
                                                .offset(y: 0.2)
                                        }
                                    }.padding(.horizontal, 7)
                                    Spacer()
                                    if allDevices[index].hasBattery {
                                        if overStack == index {
                                            HStack(spacing: 3) {
                                                if allDevices[index].deviceID == "@MacInternalBattery" {
                                                    Text(allDevices[index].isCharging != 0 ? "Until Full:" : "Until Empty:")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                    Text(InternalBattery.status.timeLeft)
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                } else {
                                                    if allDevices[index].realUpdate != 0.0 {
                                                        Text("\(Int((Date().timeIntervalSince1970 - allDevices[index].realUpdate) / 60))"+" mins ago".local)
                                                            .font(.system(size: 11, weight: .medium))
                                                            .foregroundColor(.secondary)
                                                    } else {
                                                        Text("\(Int((Date().timeIntervalSince1970 - allDevices[index].lastUpdate) / 60))"+" mins ago".local)
                                                            .font(.system(size: 11, weight: .medium))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer().frame(width: 1)
                                                if !alertList.map({$0.name}).contains(allDevices[index].deviceName) {
                                                    Button(action: {
                                                        let alert = btAlert(name: allDevices[index].deviceName,
                                                                                    full: 80, fullOn: true, fullSound: true,
                                                                                    low: 20, lowOn: true, lowSound: true)
                                                        let alertWindowController = AlertWindowController()
                                                        alertWindowController.showAlert(with: alert, iconName: getDeviceIcon(allDevices[index]), onConfirm: { newAlert in
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
                                                        if let alert = alertList.first(where: {$0.name == allDevices[index].deviceName}) {
                                                            let alertWindowController = AlertWindowController()
                                                            alertWindowController.showAlert(with: alert, iconName: getDeviceIcon(allDevices[index]), onConfirm: { newAlert in
                                                                alertList = ud.get(objectType: [btAlert].self, forKey: "alertList") ?? []
                                                                alertList.removeAll {$0.name == allDevices[index].deviceName}
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
                                                if allDevices[index].deviceID != "@MacInternalBattery" {
                                                    if !pinnedList.contains(allDevices[index].deviceName) {
                                                        Button(action: {
                                                            pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
                                                            pinnedList.append(allDevices[index].deviceName)
                                                            ud.set(pinnedList, forKey: "pinnedList")
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
                                                            pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
                                                            pinnedList.removeAll(where:  { $0 == allDevices[index].deviceName })
                                                            refeshPinnedBar(unpin: allDevices[index].deviceName)
                                                            ud.set(pinnedList, forKey: "pinnedList")
                                                        }, label: {
                                                            Image("pin.circle.fill")
                                                                .resizable().scaledToFit()
                                                                .frame(width: 18, height: 18, alignment: .center)
                                                                .foregroundColor(overPinButton ? .accentColor : .secondary)
                                                        })
                                                        .buttonStyle(PlainButtonStyle())
                                                        .onHover{ hovering in overPinButton = hovering }
                                                    }
                                                }
                                                if #available(macOS 14, *) {
                                                    Button(action: {
                                                        copyToClipboard(allDevices[index].deviceName)
                                                        DispatchQueue.main.async {
                                                            _ = createAlert(title: "Device Name Copied".local,
                                                                            message: String(format: "Device name \"%@\" has been copied to the clipboard.".local, allDevices[index].deviceName),
                                                                            button1: "OK".local).runModal()
                                                        }
                                                    }, label: {
                                                        Image("list.clipboard.fill.circle")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 18, height: 18, alignment: .center)
                                                            .foregroundColor(overCopyButton ? .accentColor : .secondary)
                                                    })
                                                    .buttonStyle(PlainButtonStyle())
                                                    .onHover{ hovering in overCopyButton = hovering }
                                                }
                                                
                                                if allDevices[index].deviceID != "@MacInternalBattery" {
                                                    Button(action: {
                                                        hidden.append(index)
                                                        var blackList = (ud.object(forKey: "blackList") ?? []) as! [String]
                                                        blackList.append(allDevices[index].deviceName)
                                                        ud.set(blackList, forKey: "blackList")
                                                        let pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
                                                        if pinnedList.contains(allDevices[index].deviceName){
                                                            refeshPinnedBar()
                                                        }
                                                    }, label: {
                                                        Image("eye.slash.circle")
                                                            .resizable().scaledToFit()
                                                            .frame(width: 18, height: 18, alignment: .center)
                                                            .foregroundColor(overHideButton ? .accentColor : .secondary)
                                                    })
                                                    .buttonStyle(PlainButtonStyle())
                                                    .onHover{ hovering in overHideButton = hovering }
                                                }
                                            }
                                        } else {
                                            Text("\(allDevices[index].batteryLevel)%")
                                                .foregroundColor((allDevices[index].batteryLevel <= 10) ? Color.darkMyRed : .primary)
                                                .font(.system(size: 11))
                                            BatteryView(item: allDevices[index])
                                                .scaleEffect(0.85)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(overStack == index ? Color.blackWhite.opacity(0.15) : .clear)//.cornerRadius(4)
                                .clipShape(RoundedCornersShape(radius: 2.9, corners: index == allDevices.count - (hiddenDevices.count > 0 ? 0 : 1) ? [.bottomLeft, .bottomRight] : (index == 0 ? [.topLeft, .topRight] : [])))
                                .onHover{ hovering in
                                    overStack2 = -1
                                    overStackNC = -1
                                    if overStack != index { overStack = index }
                                }
                                /*.contextMenu{
                                    if nearCast && ["Trackpad", "Keyboard", "Mouse", "MMouse"].contains(allDevices[index].deviceType) {
                                        Section(header: Text("Transmit to...").textCase(nil)) {
                                            Divider()
                                            ForEach(netcastService.transceiver.availablePeers, id: \.self) { peer in
                                                Button (action:{
                                                    createNotification(title: "Transmitting".local,
                                                                       message: String(format: "%@ -> %@".local, allDevices[index].deviceName, peer.name),
                                                                       interval: 1)
                                                    if fromDock {
                                                        dockWindow.orderOut(nil)
                                                    } else {
                                                        menuPopover.performClose(nil)
                                                    }
                                                    DispatchQueue.global(qos: .background).async {
                                                        let ret = BTTool.disconnect(mac: allDevices[index].deviceID)
                                                        if ret {
                                                            netcastService.transDevice(device: allDevices[index], to: peer.name)
                                                        } else {
                                                            createNotification(title: "Transmission Failed".local,
                                                                               message: String(format: "Failed to disconnect %@!".local, allDevices[index].deviceName))
                                                        }
                                                    }
                                                }, label:{ Text(peer.name)})
                                            }
                                            if netcastService.transceiver.availablePeers.isEmpty { Text("No Available Peers".local) }
                                        }
                                    }
                                    if allDevices[index].deviceID != "@MacInternalBattery" {
                                        if !pinnedList.contains(allDevices[index].deviceName) {
                                            Button(action: {
                                                pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
                                                pinnedList.append(allDevices[index].deviceName)
                                                ud.set(pinnedList, forKey: "pinnedList")
                                                refeshPinnedBar()
                                            }) {
                                                Label("Pin to Menu Bar", systemImage: "")
                                            }
                                        } else {
                                            Button(action: {
                                                pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
                                                pinnedList.removeAll { $0 == allDevices[index].deviceName }
                                                ud.set(pinnedList, forKey: "pinnedList")
                                                refeshPinnedBar()
                                            }) {
                                                Label("Unpin This Device", systemImage: "")
                                            }
                                        }
                                        Divider()
                                        Menu(content: {
                                        }, label: {
                                            Label("Transfer to...", systemImage: "")
                                        })
                                        Divider()
                                        if #available(macOS 14, *) {
                                            Button(action: {
                                                copyToClipboard(allDevices[index].deviceName)
                                                _ = createAlert(title: "Device Name Copied".local,
                                                                message: String(format: "Device name: \"%@\" has been copied to the clipboard.".local, allDevices[index].deviceName),
                                                                button1: "OK".local).runModal()
                                            }) {
                                                Label("Copy Device Name", systemImage: "")
                                            }
                                        }
                                        Button(action: {
                                            hidden.append(index)
                                            var blackList = (ud.object(forKey: "blackList") ?? []) as! [String]
                                            blackList.append(allDevices[index].deviceName)
                                            ud.set(blackList, forKey: "blackList")
                                        }) {
                                            Label("Hide From List", systemImage: "")
                                        }
                                    }
                                }*/
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
                                        var blackList = (ud.object(forKey: "blackList") ?? []) as! [String]
                                        blackList.removeAll { $0 == hiddenDevices[index].deviceName }
                                        ud.set(blackList, forKey: "blackList")
                                        let pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
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
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.secondary, lineWidth: 1)
                        .padding(.vertical, -1)
                        .padding(.horizontal, 5)
                        .opacity(0.23)
                )
                .liquidGlassPanel(cornerRadius: 5, tint: .primary.opacity(0.02))
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
        .liquidGlassEffect(cornerRadius: fromDock ? 8 : 10, interactive: true, tint: .primary.opacity(0.04))
        .onAppear { allDevices = allDevice }
        .onReceive(mainTimer) { t in
            if !fromDock && menuPopover.isShown {
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
    @State private var pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
    
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
                                            pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
                                            pinnedList.append(devices[index].deviceName)
                                            ud.set(pinnedList, forKey: "pinnedList")
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
                                            pinnedList = (ud.object(forKey: "pinnedList") ?? []) as! [String]
                                            pinnedList.removeAll { $0 == devices[index].deviceName }
                                            ud.set(pinnedList, forKey: "pinnedList")
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
                                    if #available(macOS 14, *) {
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
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(nil)
}

func openSettingPanel() {
    dockWindow.orderOut(nil)
    Task { @MainActor in
        SettingsWindowController.shared.present()
    }
}

func findNSSplitVIew(view: NSView?) -> NSSplitView? {
    var queue = [NSView]()
    if let root = view {
        queue.append(root)
    }
    while !queue.isEmpty {
        let current = queue.removeFirst()
        if current is NSSplitView {
            return current as? NSSplitView
        }
        for subview in current.subviews {
            queue.append(subview)
        }
    }
    return nil
}

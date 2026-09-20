//
//  AirBatteryModel.swift
//  AirBattery
//
//  Created by apple on 2024/2/6.
//
import SwiftUI
import Foundation

enum IDeviceConnectionSource: String, Hashable {
    case network = "Network"
    case usb = "USB"
}

struct IDeviceDiscoveryCandidate: Identifiable, Hashable {
    let identifier: String
    var name: String?
    var deviceType: String?
    var model: String?
    var sources: Set<IDeviceConnectionSource>
    var lastSeen: Date
    var batteryReadable: Bool

    var id: String { identifier }
}

class IDeviceBattery: ObservableObject {
    static var shared: IDeviceBattery = IDeviceBattery()
    
    //var scanTimer: Timer?
    @AppStorage("readPencil") var readPencil = false
    @AppStorage("readIDevice") var readIDevice = true
    @AppStorage("updateInterval") var updateInterval = 1
    @Published private(set) var discoveryCandidates: [IDeviceDiscoveryCandidate] = []

    private let scanLock = NSLock()
    private var scanInFlight = false
    private let companionProbeLock = NSLock()
    private var companionProbeDisabledForLaunch = false
    private var lastCompanionProbe: [String: TimeInterval] = [:]
    private let companionProbeInterval: TimeInterval = 5 * 60

    private func recordObservation(
        identifier: String,
        source: IDeviceConnectionSource,
        name: String? = nil,
        deviceType: String? = nil,
        model: String? = nil,
        batteryReadable: Bool? = nil
    ) {
        guard !identifier.isEmpty else { return }
        DispatchQueue.main.async {
            if let index = self.discoveryCandidates.firstIndex(where: { $0.identifier == identifier }) {
                self.discoveryCandidates[index].sources.insert(source)
                self.discoveryCandidates[index].lastSeen = Date()
                if let name { self.discoveryCandidates[index].name = name }
                if let deviceType { self.discoveryCandidates[index].deviceType = deviceType }
                if let model { self.discoveryCandidates[index].model = model }
                if let batteryReadable {
                    self.discoveryCandidates[index].batteryReadable =
                        self.discoveryCandidates[index].batteryReadable || batteryReadable
                }
            } else {
                self.discoveryCandidates.append(
                    IDeviceDiscoveryCandidate(
                        identifier: identifier,
                        name: name,
                        deviceType: deviceType,
                        model: model,
                        sources: [source],
                        lastSeen: Date(),
                        batteryReadable: batteryReadable ?? false
                    )
                )
            }
        }
    }
    
    func clearDiscoveryCandidates() {
        DispatchQueue.main.async {
            self.discoveryCandidates.removeAll()
        }
    }

    func startScan() {
        //let interval = TimeInterval(5.0)
        //scanTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(scanDevices), userInfo: nil, repeats: true)
        print("ℹ️ Start scanning iDevice devices...")
        scanDevices()
    }
    
    @objc func scanDevices() {
        scanLock.lock()
        guard !scanInFlight else {
            scanLock.unlock()
            return
        }
        scanInFlight = true
        scanLock.unlock()

        Thread.detachNewThread {
            defer {
                self.scanLock.lock()
                self.scanInFlight = false
                self.scanLock.unlock()
            }

            if !self.readIDevice { return }
            self.getIDeviceBattery()
        }
    }
    
    func getPencil(d: Device, type: String = "") {
        if d.deviceType == "iPad" && readPencil {
            Thread.detachNewThread {
                if let result = process(path: "/bin/bash", arguments: ["\(Bundle.main.resourcePath!)/logReader.sh", "\(Bundle.main.resourcePath!)/libimobiledevice/bin/idevicesyslog", type, d.deviceID], timeout: 11 * self.updateInterval) {
                    if let json = try? JSONSerialization.jsonObject(with: Data(result.utf8), options: []) as? [String: Any] {
                        if let level = json["level"] as? Int, let model = json["model"] as? String, let vendor = json["vendor"] as? String {
                            let status = (json["status"] as? Int) ?? 0
                            print("ℹ️ Pencil of \(d.deviceName): \(result)")
                            AirBatteryModel.updateDevice(Device(deviceID: "Pencil_"+d.deviceID, deviceType: vendor == "Apple" ? "ApplePencil" : "Pencil", deviceName: vendor == "Apple" ? "Apple Pencil".local : "Pencil".local, deviceModel: model, batteryLevel: level, isCharging: status, parentName: d.deviceName, lastUpdate: Date().timeIntervalSince1970))
                        }
                    }
                }
            }
        }
    }
    
    func getIDeviceBattery() {
        if let result = process(path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/idevice_id", arguments: ["-n"]) {
            for id in result.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
                recordObservation(identifier: id, source: .network)
                if let d = AirBatteryModel.getByID(id) {
                    if (Double(Date().timeIntervalSince1970) - d.lastUpdate) > Double(60 * updateInterval) { writeBatteryInfo(id, "-n") }
                    getPencil(d: d, type: "-n")
                } else {
                    writeBatteryInfo(id, "-n")
                }
            }
        }
        if let result = process(path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/idevice_id", arguments: ["-l"]) {
            for id in result.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
                recordObservation(identifier: id, source: .usb)
                if let d = AirBatteryModel.getByID(id) {
                    if (Double(Date().timeIntervalSince1970) - d.lastUpdate) > Double(60 * updateInterval) { writeBatteryInfo(id, "") }
                    getPencil(d: d)
                } else {
                    writeBatteryInfo(id, "")
                }
            }
        }
    }
    
    private func shouldProbeCompanion(parentID: String, deviceType: String) -> Bool {
        guard deviceType.caseInsensitiveCompare("iPhone") == .orderedSame else {
            return false
        }

        let now = Date().timeIntervalSince1970
        companionProbeLock.lock()
        defer { companionProbeLock.unlock() }

        guard !companionProbeDisabledForLaunch else { return false }
        if let lastProbe = lastCompanionProbe[parentID],
           now - lastProbe < companionProbeInterval {
            return false
        }

        // Reserve the slot before launching the helper so overlapping refreshes
        // cannot start duplicate companion-proxy probes.
        lastCompanionProbe[parentID] = now
        return true
    }

    private func updateWatchBattery(
        parentID: String,
        parentName: String,
        deviceType: String,
        lastUpdate: TimeInterval
    ) {
        guard shouldProbeCompanion(parentID: parentID, deviceType: deviceType) else {
            return
        }

        let result = processWithStatus(
            path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/comptest",
            arguments: [parentID],
            timeout: 10
        )

        guard let result else { return }

        if result.terminationReason == .uncaughtSignal {
            companionProbeLock.lock()
            companionProbeDisabledForLaunch = true
            companionProbeLock.unlock()
            print(
                "⚠️ Disabling Apple Watch companion probing for this launch: " +
                "comptest terminated by signal \(result.terminationStatus)"
            )
            return
        }

        guard result.terminationStatus == 0, !result.output.isEmpty else {
            return
        }

        let watchInfo = result.output.components(separatedBy: .newlines)
        guard let watchID = watchInfo
                .first(where: { $0.contains("Checking watch") })?
                .components(separatedBy: " ")
                .last,
              let watchName = watchInfo
                .first(where: { $0.contains("DeviceName") })?
                .components(separatedBy: ": ")
                .last,
              let watchModel = watchInfo
                .first(where: { $0.contains("ProductType") })?
                .components(separatedBy: ": ")
                .last,
              let watchLevel = watchInfo
                .first(where: { $0.contains("BatteryCurrentCapacity") })?
                .components(separatedBy: ": ")
                .last,
              let watchCharging = watchInfo
                .first(where: { $0.contains("BatteryIsCharging") })?
                .components(separatedBy: ": ")
                .last,
              let level = Int(watchLevel),
              let charging = Bool(watchCharging)
        else {
            return
        }

        AirBatteryModel.updateDevice(
            Device(
                deviceID: watchID,
                deviceType: "Watch",
                deviceName: watchName,
                deviceModel: watchModel,
                batteryLevel: level,
                isCharging: charging ? 1 : 0,
                parentName: parentName,
                lastUpdate: lastUpdate
            )
        )
    }

    func writeBatteryInfo(_ id: String, _ connectType: String) {
        //print("ℹ️ Getting Battery Info for \(id)")
        let source: IDeviceConnectionSource = connectType == "-n" ? .network : .usb
        let lastUpdate = Date().timeIntervalSince1970
        if connectType == "" {
            _ = process(path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/wificonnection", arguments: ["-u", id, "true"])
            // 修复 iOS"私有无线局域网地址"导致配对记录 MAC 与 Bonjour 广播 MAC 不匹配、拔线后无法通过 Wi-Fi 连接的问题
            _ = process(path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/wificonnection", arguments: ["-u", id, "syncmac"])
        }
        if let deviceInfo = process(path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/ideviceinfo", arguments: [connectType, "-u", id]){
            let i = deviceInfo.components(separatedBy: .newlines)
            if let deviceName = i.filter({ $0.contains("DeviceName") }).first?.components(separatedBy: ": ").last,
               let model = i.filter({ $0.contains("ProductType") }).first?.components(separatedBy: ": ").last,
               let type = i.filter({ $0.contains("DeviceClass") }).first?.components(separatedBy: ": ").last {
                recordObservation(
                    identifier: id,
                    source: source,
                    name: deviceName,
                    deviceType: type,
                    model: model
                )
                if let batteryInfo = process(path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/ideviceinfo", arguments: [connectType, "-u", id, "-q", "com.apple.mobile.battery"]) {
                    let b = batteryInfo.components(separatedBy: .newlines)
                    if let level = b.filter({ $0.contains("BatteryCurrentCapacity") }).first?.components(separatedBy: ": ").last,
                       let charging = b.filter({ $0.contains("BatteryIsCharging") }).first!.components(separatedBy: ": ").last {
                        AirBatteryModel.updateDevice(Device(deviceID: id, deviceType: type, deviceName: deviceName, deviceModel: model, batteryLevel: Int(level)!, isCharging: Bool(charging)! ? 1 : 0, lastUpdate: lastUpdate))
                        recordObservation(
                            identifier: id,
                            source: source,
                            name: deviceName,
                            deviceType: type,
                            model: model,
                            batteryReadable: true
                        )
                        updateWatchBattery(
                            parentID: id,
                            parentName: deviceName,
                            deviceType: type,
                            lastUpdate: lastUpdate
                        )
                    }
                }
            }
        }
    }
}

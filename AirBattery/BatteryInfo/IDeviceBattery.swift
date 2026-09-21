//
//  AirBatteryModel.swift
//  AirBattery
//
//  Created by apple on 2024/2/6.
//
import Combine
import Foundation

class IDeviceBattery: ObservableObject {
    static var shared: IDeviceBattery = IDeviceBattery()
    
    var readPencil: Bool { AppPreferences.readPencil }
    var readIDevice: Bool { AppPreferences.readIDevice }
    var updateInterval: Int { AppPreferences.updateInterval }
    @Published private(set) var discoveryCandidates: [IDeviceDiscoveryCandidate] = []

    private let scanGate = ExclusiveScanGate()
    private let companionProbeState = CompanionProbeState(interval: 5 * 60)

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
            let now = Date()
            if let index = self.discoveryCandidates.firstIndex(where: { $0.identifier == identifier }) {
                self.discoveryCandidates[index].merge(
                    source: source,
                    name: name,
                    deviceType: deviceType,
                    model: model,
                    batteryReadable: batteryReadable,
                    lastSeen: now
                )
            } else {
                self.discoveryCandidates.append(
                    IDeviceDiscoveryCandidate(
                        identifier: identifier,
                        name: name,
                        deviceType: deviceType,
                        model: model,
                        sources: [source],
                        lastSeen: now,
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
        print("ℹ️ Start scanning iDevice devices...")
        scanDevices()
    }

    func scanDevices() {
        guard scanGate.tryBegin() else { return }

        DispatchQueue.global(qos: .utility).async {
            defer { self.scanGate.end() }

            if !self.readIDevice { return }
            self.getIDeviceBattery()
        }
    }
    
    func getPencil(d: Device, type: String = "") {
        if d.deviceType == "iPad" && readPencil {
            DispatchQueue.global(qos: .utility).async {
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
    
    private func updateWatchBattery(
        parentID: String,
        parentName: String,
        deviceType: String,
        lastUpdate: TimeInterval
    ) {
        guard companionProbeState.shouldProbe(
            parentID: parentID,
            deviceType: deviceType,
            now: Date().timeIntervalSince1970
        ) else {
            return
        }

        let result = processWithStatus(
            path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/airbattery-mobile",
            arguments: ["companion-battery", parentID],
            timeout: 10
        )

        guard let result else { return }

        if result.terminationReason == .uncaughtSignal {
            companionProbeState.disableForLaunch()
            print(
                "⚠️ Disabling Apple Watch companion probing for this launch: " +
                "airbattery-mobile terminated by signal \(result.terminationStatus)"
            )
            return
        }

        guard result.terminationStatus == 0,
              let data = result.output.data(using: .utf8),
              let response = try? JSONDecoder().decode(CompanionBatteryResponse.self, from: data)
        else {
            return
        }

        for watch in response.validWatches {
            AirBatteryModel.updateDevice(
                Device(
                    deviceID: watch.id,
                    deviceType: "Watch",
                    deviceName: watch.name,
                    deviceModel: watch.productType,
                    batteryLevel: watch.batteryLevel,
                    isCharging: watch.isCharging ? 1 : 0,
                    parentName: parentName,
                    lastUpdate: lastUpdate
                )
            )
        }
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
        if let deviceInfo = process(
            path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/ideviceinfo",
            arguments: [connectType, "-u", id]
        ), let metadata = IDeviceInfoParser.metadata(from: deviceInfo) {
            recordObservation(
                identifier: id,
                source: source,
                name: metadata.name,
                deviceType: metadata.deviceClass,
                model: metadata.productType
            )

            if let batteryInfo = process(
                path: "\(Bundle.main.resourcePath!)/libimobiledevice/bin/ideviceinfo",
                arguments: [connectType, "-u", id, "-q", "com.apple.mobile.battery"]
            ), let battery = IDeviceInfoParser.battery(from: batteryInfo) {
                AirBatteryModel.updateDevice(
                    Device(
                        deviceID: id,
                        deviceType: metadata.deviceClass,
                        deviceName: metadata.name,
                        deviceModel: metadata.productType,
                        batteryLevel: battery.level,
                        isCharging: battery.isCharging ? 1 : 0,
                        lastUpdate: lastUpdate,
                        mobileDeviceID: id,
                        batterySource: .libimobiledevice
                    )
                )
                recordObservation(
                    identifier: id,
                    source: source,
                    name: metadata.name,
                    deviceType: metadata.deviceClass,
                    model: metadata.productType,
                    batteryReadable: true
                )
                updateWatchBattery(
                    parentID: id,
                    parentName: metadata.name,
                    deviceType: metadata.deviceClass,
                    lastUpdate: lastUpdate
                )
            }
        }
    }
}

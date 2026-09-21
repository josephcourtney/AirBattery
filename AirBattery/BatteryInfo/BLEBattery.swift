//
//  AirpodsBattery.swift
//  AirBattery
//
//  Created by apple on 2024/2/9.
//
//  =================================================
//  AirPods Pro/Beats BLE 常规广播数据包定义分析:
//  advertisementData长度 = 29bit
//  00~01: 制造商ID, 固定4c00
//  02~04: 未知
//  05~06: 设备型号ID:
//           0220 = Airpods
//           0e20 = Airpods Pro
//           0a20 = Airpods Max
//           0f20 = Airpods 2
//           1320 = Airpods 3
//           1420 = Airpods Pro 2
//           0320 = PowerBeats
//           0b20 = PowerBeats Pro
//           0c20 = Beats Solo Pro
//           1120 = Beats Studio Buds
//           1020 = Beats Flex
//           0520 = BeatsX
//           0620 = Beats Solo3
//           0920 = Beats Studio3
//           1720 = Beats Studio Pro
//           1220 = Beats Fit Pro
//           1620 = Beats Studio Buds+
//  07.1:  未知
//  07.2:  耳机取出状态:
//           5 = 两只耳机都在盒内
//           1 = 任意一只耳机被取出
//  08.1:  粗略电量(左耳):
//           0~10: x10 = 电量, f: 失联
//  08.2:  粗略电量(右耳):
//           0~10: x10 = 电量, f: 失联
//  09.1:  未知
//  09.2:  充电状态
//  10.1:  翻转指示
//  10.2:  未知
//  14:    左耳电量/充电指示
//           ff = 失联
//           <64(hex) = 未充电, 当前电量
//           >64(hex) = 在充电, 减80(hex)为当前电量
//  15:    右耳电量/充电指示
//           ff = 失联
//           <64(hex) = 未充电, 当前电量
//           >64(hex) = 电量(在充电, 减80(hex)为当前电量)
//  16:    充电盒电量/充电指示
//           ff = 失联
//           <64(hex) = 未在充电
//           >64(hex) = 在充电, 减80(hex)为当前电量
//  17~19: 未知
//  20~23: 未知
//  24~28: 未知
//  =================================================
//  AirPods Pro 2 BLE 合盖广播数据包定义分析:
//  advertisementData长度 = 25bit
//  00~01: 制造商ID, 固定4c00
//  02~03: 未知
//  04:    耳机取出状态:
//           24 = 双耳都在盒外
//           26 = 仅右耳被取出
//           2c = 仅左耳被取出
//           2e = 双耳都在盒内
//  05:    未知
//  06~10: 未知
//  11:    未知
//  12:    充电盒电量/充电指示
//           失联 = ff
//           <64(hex) = 电量(未在充电)
//           >64(hex) = 电量(在充电, 减80(hex)为当前电量)
//  13:    左耳电量/充电指示
//           被取出 = ff
//           >64(hex) = 电量(在充电, 减80(hex)为当前电量)
//  14:    右耳电量/充电指示
//           被取出 = ff
//           >64(hex) = 电量(在充电, 减80(hex)为当前电量)
//  15~20: 未知
//  21~22: 未知
//  23~24: 未知
//  =================================================
import Combine
import Foundation
import CoreBluetooth

enum BLEDiscoveryMode: String, CaseIterable, Codable {
    case passive
    case review
    case automatic

    var title: String {
        switch self {
        case .passive: return "Observe only"
        case .review: return "Ask before querying"
        case .automatic: return "Query automatically"
        }
    }

    var detail: String {
        switch self {
        case .passive:
            return "AirBattery observes unknown devices without connecting. Only devices explicitly allowed for battery queries may be contacted."
        case .review:
            return "AirBattery observes unknown devices and suggests likely battery devices in Devices. It connects only after you allow battery queries."
        case .automatic:
            return "AirBattery may connect to promising newly discovered BLE devices automatically when a battery query is needed."
        }
    }
}

enum BLEDevicePolicy: String, CaseIterable, Codable {
    case allow
    case observe
    case ignore

    var title: String {
        switch self {
        case .allow: return "Allow queries"
        case .observe: return "Passive only"
        case .ignore: return "Ignore"
        }
    }
}

struct BLEDeviceRule: Codable, Hashable, Identifiable {
    let identifier: String
    var name: String
    var policy: BLEDevicePolicy

    var id: String { identifier }
}

struct BLELogicalDeviceRule: Codable, Hashable, Identifiable {
    let key: String
    var name: String
    var policy: BLEDevicePolicy

    var id: String { key }
}

struct BLEDiscoveryCandidate: Hashable, Identifiable {
    let identifier: String
    var name: String
    var rssi: Int
    var smoothedRSSI: Double
    var firstSeen: Date
    var lastSeen: Date
    var seenCount: Int
    var isConnectable: Bool
    var advertisesBatteryService: Bool
    var hasPassiveBatteryData: Bool
    var matchesPairedName: Bool
    var lastProbeResult: String?

    var id: String { identifier }
    var displayRSSI: Int { Int(smoothedRSSI.rounded()) }
}

struct BLELogicalDeviceSnapshot: Identifiable {
    let key: String
    let name: String
    let policy: BLEDevicePolicy?
    let identities: [BLEDiscoveryCandidate]
    let exactRules: [BLEDeviceRule]

    var id: String { key }
}

final class BLEDiscoveryPolicyStore: ObservableObject {
    static let shared = BLEDiscoveryPolicyStore()

    @Published private(set) var rules: [BLEDeviceRule]
    @Published private(set) var logicalRules: [BLELogicalDeviceRule]
    @Published private(set) var candidates: [BLEDiscoveryCandidate] = []

    private let rulesKey = "bleDevicePolicyRules"
    private let logicalRulesKey = "bleLogicalDevicePolicyRulesV1"

    private init() {
        let storedRules: [BLEDeviceRule]
        if let data = ud.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([BLEDeviceRule].self, from: data) {
            storedRules = decoded
        } else {
            storedRules = []
        }

        if let data = ud.data(forKey: logicalRulesKey),
           let decoded = try? JSONDecoder().decode([BLELogicalDeviceRule].self, from: data) {
            rules = storedRules
            logicalRules = decoded
        } else {
            var remainingRules = storedRules
            var migratedRules: [BLELogicalDeviceRule] = []
            let grouped = Dictionary(grouping: storedRules) {
                Self.logicalKey(for: $0.name)
            }
            for (key, group) in grouped {
                let policies = Set(group.map(\.policy))
                guard policies.count == 1, let policy = policies.first, let name = group.first?.name else {
                    continue
                }
                migratedRules.append(BLELogicalDeviceRule(key: key, name: name, policy: policy))
                remainingRules.removeAll { Self.logicalKey(for: $0.name) == key }
            }
            rules = remainingRules
            logicalRules = migratedRules.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            if !migratedRules.isEmpty {
                if let data = try? JSONEncoder().encode(rules) {
                    ud.set(data, forKey: rulesKey)
                }
                if let data = try? JSONEncoder().encode(logicalRules) {
                    ud.set(data, forKey: logicalRulesKey)
                }
            }
        }
    }

    static func logicalKey(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func exactPolicy(identifier: String) -> BLEDevicePolicy? {
        rules.first(where: { $0.identifier == identifier })?.policy
    }

    func logicalPolicy(name: String) -> BLEDevicePolicy? {
        let key = Self.logicalKey(for: name)
        return logicalRules.first(where: { $0.key == key })?.policy
    }

    func explicitPolicy(identifier: String, name: String) -> BLEDevicePolicy? {
        exactPolicy(identifier: identifier) ?? logicalPolicy(name: name)
    }

    func setPolicy(identifier: String, name: String, policy: BLEDevicePolicy) {
        if let index = rules.firstIndex(where: { $0.identifier == identifier }) {
            rules[index].name = name
            rules[index].policy = policy
        } else {
            rules.append(BLEDeviceRule(identifier: identifier, name: name, policy: policy))
        }
        rules.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveRules()
    }

    func clearPolicy(identifier: String) {
        rules.removeAll(where: { $0.identifier == identifier })
        saveRules()
    }

    func setLogicalPolicy(name: String, policy: BLEDevicePolicy) {
        let key = Self.logicalKey(for: name)
        if let index = logicalRules.firstIndex(where: { $0.key == key }) {
            logicalRules[index].name = name
            logicalRules[index].policy = policy
        } else {
            logicalRules.append(BLELogicalDeviceRule(key: key, name: name, policy: policy))
        }
        // Changing the logical rule establishes a new baseline and clears old overrides.
        rules.removeAll { Self.logicalKey(for: $0.name) == key }
        logicalRules.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveRules()
        saveLogicalRules()
    }

    func clearLogicalPolicy(name: String) {
        let key = Self.logicalKey(for: name)
        logicalRules.removeAll(where: { $0.key == key })
        saveLogicalRules()
    }

    func recordObservation(
        identifier: String,
        name: String,
        rssi: Int,
        isConnectable: Bool,
        advertisesBatteryService: Bool,
        hasPassiveBatteryData: Bool,
        matchesPairedName: Bool
    ) {
        let now = Date()
        if let index = candidates.firstIndex(where: { $0.identifier == identifier }) {
            candidates[index].name = name
            candidates[index].rssi = rssi
            candidates[index].smoothedRSSI =
                candidates[index].smoothedRSSI * 0.75 + Double(rssi) * 0.25
            candidates[index].lastSeen = now
            candidates[index].seenCount += 1
            candidates[index].isConnectable = isConnectable
            candidates[index].advertisesBatteryService =
                candidates[index].advertisesBatteryService || advertisesBatteryService
            candidates[index].hasPassiveBatteryData =
                candidates[index].hasPassiveBatteryData || hasPassiveBatteryData
            candidates[index].matchesPairedName =
                candidates[index].matchesPairedName || matchesPairedName
        } else {
            candidates.append(
                BLEDiscoveryCandidate(
                    identifier: identifier,
                    name: name,
                    rssi: rssi,
                    smoothedRSSI: Double(rssi),
                    firstSeen: now,
                    lastSeen: now,
                    seenCount: 1,
                    isConnectable: isConnectable,
                    advertisesBatteryService: advertisesBatteryService,
                    hasPassiveBatteryData: hasPassiveBatteryData,
                    matchesPairedName: matchesPairedName,
                    lastProbeResult: nil
                )
            )
        }

        trimCandidateHistoryIfNeeded()
    }

    func candidate(identifier: String) -> BLEDiscoveryCandidate? {
        candidates.first(where: { $0.identifier == identifier })
    }

    var nearbyCandidates: [BLEDiscoveryCandidate] {
        candidates.filter {
            explicitPolicy(identifier: $0.identifier, name: $0.name) == nil
        }
    }

    var suggestedCandidates: [BLEDiscoveryCandidate] {
        let mode = BLEDiscoveryMode(rawValue: ud.string(forKey: "bleDiscoveryMode") ?? "") ?? .review
        guard mode == .review else { return [] }
        guard ud.bool(forKey: "readBLEDevice") || ud.bool(forKey: "ideviceOverBLE") else { return [] }
        return nearbyCandidates.filter(isReviewCandidate)
    }

    var otherNearbyCandidates: [BLEDiscoveryCandidate] {
        let suggestedIDs = Set(suggestedCandidates.map(\.identifier))
        return nearbyCandidates.filter { !suggestedIDs.contains($0.identifier) }
    }

    var knownLogicalDevices: [BLELogicalDeviceSnapshot] {
        let keys = Set(logicalRules.map(\.key) + rules.map { Self.logicalKey(for: $0.name) })
        return keys.compactMap { key in
            let logicalRule = logicalRules.first(where: { $0.key == key })
            let exactRules = rules.filter { Self.logicalKey(for: $0.name) == key }
            let identities = candidates.filter { Self.logicalKey(for: $0.name) == key }
            let name = logicalRule?.name ?? exactRules.first?.name ?? identities.first?.name
            guard let name else { return nil }
            return BLELogicalDeviceSnapshot(
                key: key,
                name: name,
                policy: logicalRule?.policy,
                identities: identities,
                exactRules: exactRules
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func recordProbeResult(identifier: String, result: String) {
        guard let index = candidates.firstIndex(where: { $0.identifier == identifier }) else { return }
        candidates[index].lastProbeResult = result
    }

    func clearNearby() {
        candidates.removeAll {
            explicitPolicy(identifier: $0.identifier, name: $0.name) == nil
        }
    }

    private func trimCandidateHistoryIfNeeded() {
        while candidates.count > 100 {
            let removable = candidates.indices.filter {
                explicitPolicy(
                    identifier: candidates[$0].identifier,
                    name: candidates[$0].name
                ) == nil
            }
            let pool = removable.isEmpty ? Array(candidates.indices) : removable
            guard let oldestIndex = pool.min(by: {
                candidates[$0].lastSeen < candidates[$1].lastSeen
            }) else { return }
            candidates.remove(at: oldestIndex)
        }
    }

    func effectivePolicy(
        identifier: String,
        name: String,
        mode: BLEDiscoveryMode
    ) -> BLEDevicePolicy {
        if let explicit = explicitPolicy(identifier: identifier, name: name) {
            return explicit
        }
        switch mode {
        case .passive, .review:
            return .observe
        case .automatic:
            return .allow
        }
    }

    func isReviewCandidate(_ candidate: BLEDiscoveryCandidate) -> Bool {
        guard explicitPolicy(identifier: candidate.identifier, name: candidate.name) == nil else { return false }
        guard candidate.seenCount >= 3 else { return false }
        guard !candidate.hasPassiveBatteryData else { return false }
        return candidate.matchesPairedName ||
            candidate.advertisesBatteryService ||
            candidate.lastProbeResult != nil
    }

    var reviewCount: Int {
        suggestedCandidates.count
    }

    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            ud.set(data, forKey: rulesKey)
        }
    }

    private func saveLogicalRules() {
        if let data = try? JSONEncoder().encode(logicalRules) {
            ud.set(data, forKey: logicalRulesKey)
        }
    }
}

class BLEBattery: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var ideviceOverBLE: Bool { AppPreferences.ideviceOverBLE }
    var readBTDevice: Bool { AppPreferences.readBTDevice }
    var readBLEDevice: Bool { AppPreferences.readBLEDevice }
    var bleDiscoveryMode: String { AppPreferences.bleDiscoveryMode }
    var updateInterval: Int { AppPreferences.updateInterval }
    
    var centralManager: CBCentralManager!
    var peripherals: [CBPeripheral?] = []
    var otherAppleDevices: [String] = []
    var bleDevicesLevel: [String:UInt8] = [:]
    var bleDevicesVendor: [String:String] = [:]
    private let discoveryPolicy = BLEDiscoveryPolicyStore.shared
    private var pairedDeviceNames: Set<String> = []

    // Generic BLE discovery may require an active connection, which can trigger
    // a macOS pairing prompt. Remember failed/non-battery probes for this app
    // launch so the same nearby device is not retried every scan cycle.
    private var genericProbePeripheralIDs: Set<UUID> = []
    private var genericProbeInFlight: Set<UUID> = []
    private var genericProbeRejected: Set<UUID> = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let authorization = CBManager.authorization
        print("ℹ️ Bluetooth state=\(central.state.rawValue) authorization=\(authorization.rawValue)")

        switch authorization {
        case .allowedAlways:
            break
        case .notDetermined:
            print("ℹ️ Bluetooth permission has not been decided yet; starting discovery so macOS can resolve authorization.")
        case .denied:
            print("⚠️ Bluetooth permission is denied for AirBattery.")
        case .restricted:
            print("⚠️ Bluetooth permission is restricted for AirBattery.")
        @unknown default:
            print("⚠️ Unknown Bluetooth authorization state: \(authorization.rawValue)")
        }

        // The central manager state is the authoritative indication that the
        // adapter is usable. Do not require .allowedAlways here: on macOS the
        // authorization value can still be .notDetermined when the manager is
        // already powered on, and beginning CoreBluetooth use is what allows
        // the system to resolve/request that permission.
        if central.state == .poweredOn {
            scan(longScan: true)
        }
    }

    func startScan() {
        print("ℹ️ Start scanning BLE devices...")
        scan(longScan: true)
    }

    func scan(longScan: Bool = false) {
        if centralManager.state == .poweredOn && !centralManager.isScanning {
            pairedDeviceNames = Set(getPaired())
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + (longScan ? 15.0 : 5.0)) {
                self.stopScan()
            }
        }
    }

    func stopScan() {
        centralManager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        rejectGenericProbe(peripheral, reason: "connection failed")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if genericProbeInFlight.contains(peripheral.identifier) {
            rejectGenericProbe(peripheral, reason: "disconnected before battery discovery")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var get = false
        var genericProbe = false
        let now = Double(Date().timeIntervalSince1970)
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard let deviceName = peripheral.name ?? advertisedName, !deviceName.isEmpty else { return }

        if AirBatteryModel.checkIfBlocked(name: deviceName) { return }

        let identifier = peripheral.identifier.uuidString
        let isPaired = pairedDeviceNames.contains(deviceName)
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let advertisesBatteryService = serviceUUIDs.contains(CBUUID(string: "180F"))
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let hasPassiveBatteryData = manufacturerData.map { data in
            data.count > 2 &&
                data[0] == 76 &&
                ((data.count == 25 && data[2] == 18) || (data.count == 29 && data[2] == 7))
        } ?? false
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? true

        discoveryPolicy.recordObservation(
            identifier: identifier,
            name: deviceName,
            rssi: RSSI.intValue,
            isConnectable: isConnectable,
            advertisesBatteryService: advertisesBatteryService,
            hasPassiveBatteryData: hasPassiveBatteryData,
            matchesPairedName: isPaired
        )

        if discoveryPolicy.explicitPolicy(identifier: identifier, name: deviceName) == .ignore { return }

        AirBatteryModel.noteBLEPresence(name: deviceName)

        let mode = BLEDiscoveryMode(rawValue: bleDiscoveryMode) ?? .review
        let activePolicy = discoveryPolicy.effectivePolicy(
            identifier: identifier,
            name: deviceName,
            mode: mode
        )

        if let data = manufacturerData, data.count > 0 {
            if data[0] != 76 {
                // Generic BLE devices are always discovered passively first.
                // An active connection is made only when the effective policy allows it.
                if readBLEDevice &&
                    activePolicy == .allow &&
                    isConnectable &&
                    !genericProbeRejected.contains(peripheral.identifier) &&
                    !genericProbeInFlight.contains(peripheral.identifier) {
                    if let device = AirBatteryModel.getByName(deviceName) {
                        if now - device.lastUpdate > Double(60 * updateInterval) {
                            get = true
                            genericProbe = true
                        }
                    } else {
                        get = true
                        genericProbe = true
                    }
                }
            } else if data.count > 2 {
                // iOS-over-BLE can also require an active connection, so it follows
                // the same per-device permission policy.
                if [16, 12].contains(data[2]) &&
                    !otherAppleDevices.contains(deviceName) &&
                    ideviceOverBLE &&
                    activePolicy == .allow &&
                    isConnectable {
                    if let device = AirBatteryModel.getByName(deviceName), device.deviceModel != nil {
                        if now - device.lastUpdate > Double(60 * updateInterval) { get = true }
                    } else {
                        get = true
                    }
                }

                // AirPods and Beats battery advertisements are passive and remain
                // available in Observe-only mode.
                if data.count == 25 && data[2] == 18 && readBTDevice {
                    getAirpods(peripheral: peripheral, data: data, messageType: "close")
                }
                if data.count == 29 && data[2] == 7 && readBTDevice {
                    getAirpods(peripheral: peripheral, data: data, messageType: "open")
                }
            }
        }

        if get {
            if genericProbe {
                genericProbePeripheralIDs.insert(peripheral.identifier)
                genericProbeInFlight.insert(peripheral.identifier)
            }
            self.peripherals.append(peripheral)
            self.centralManager.connect(peripheral, options: nil)
        }
    }

    private func rejectGenericProbe(_ peripheral: CBPeripheral, reason: String) {
        let identifier = peripheral.identifier
        guard genericProbePeripheralIDs.contains(identifier) else { return }
        genericProbeRejected.insert(identifier)
        genericProbeInFlight.remove(identifier)
        discoveryPolicy.recordProbeResult(identifier: identifier.uuidString, result: reason)
        genericProbePeripheralIDs.remove(identifier)
        if let index = self.peripherals.firstIndex(of: peripheral) {
            self.peripherals.remove(at: index)
        }
        centralManager.cancelPeripheralConnection(peripheral)
        print("ℹ️ Skipping future BLE battery probes for \(peripheral.name ?? identifier.uuidString): \(reason)")
    }

    private func finishGenericProbe(_ peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        genericProbeInFlight.remove(identifier)
        genericProbePeripheralIDs.remove(identifier)
        discoveryPolicy.recordProbeResult(identifier: identifier.uuidString, result: "Battery query succeeded")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            rejectGenericProbe(peripheral, reason: "service discovery failed")
            return
        }
        guard let services = peripheral.services else {
            rejectGenericProbe(peripheral, reason: "no services discovered")
            return
        }

        if genericProbePeripheralIDs.contains(peripheral.identifier) &&
            !services.contains(where: { $0.uuid == CBUUID(string: "180F") }) {
            rejectGenericProbe(peripheral, reason: "no Battery Service")
            return
        }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            if service.uuid == CBUUID(string: "180F") {
                rejectGenericProbe(peripheral, reason: "battery characteristic discovery failed")
            }
            return
        }
        guard let characteristics = service.characteristics else {
            if service.uuid == CBUUID(string: "180F") {
                rejectGenericProbe(peripheral, reason: "Battery Service has no characteristics")
            }
            return
        }

        if service.uuid == CBUUID(string: "180F") {
            guard let batteryLevel = characteristics.first(where: { $0.uuid == CBUUID(string: "2A19") }) else {
                rejectGenericProbe(peripheral, reason: "Battery Service has no Battery Level characteristic")
                return
            }
            peripheral.readValue(for: batteryLevel)
        } else if service.uuid == CBUUID(string: "180A") {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string: "2A24") ||
                    characteristic.uuid == CBUUID(string: "2A29") {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
    
    //电量信息
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //guard let name = peripheral.name else { return }
        //let blockedItems = (ud.object(forKey: "blockedDevices") as? [String]) ?? [String]()
        //if blockedItems.contains(name) && !whitelistMode { return }
        //if !blockedItems.contains(name) && whitelistMode { return }
        
        if characteristic.uuid == CBUUID(string: "2A19"){
            if error != nil {
                rejectGenericProbe(peripheral, reason: "battery level read failed")
                return
            }
            if let data = characteristic.value, !data.isEmpty, let deviceName = peripheral.name {
                let now = Date().timeIntervalSince1970
                let level = Int(data[0])
                if level > 100 {
                    rejectGenericProbe(peripheral, reason: "invalid battery level")
                    return
                }
                var charging = 0
                //if let lastLevel = bleDevicesLevel[deviceName], cStatusOfBLE {
                if let lastLevel = bleDevicesLevel[deviceName] {
                    if level > lastLevel { charging = 1 }
                    //if level < lastLevel { charging = 0 }
                }
                bleDevicesLevel[deviceName] = data[0]
                finishGenericProbe(peripheral)
                if var device = AirBatteryModel.getByName(deviceName) {
                    device.bleDeviceID = peripheral.identifier.uuidString
                    device.batteryLevel = level
                    device.lastUpdate = now
                    device.batterySource = .ble
                    if charging != -1 { device.isCharging = charging }
                    AirBatteryModel.updateDevice(device)
                } else {
                    let device = Device(
                        deviceID: peripheral.identifier.uuidString,
                        deviceType: getType(deviceName),
                        deviceName: deviceName,
                        batteryLevel: level,
                        isCharging: charging,
                        lastUpdate: now,
                        bleDeviceID: peripheral.identifier.uuidString,
                        batterySource: .ble
                    )
                    AirBatteryModel.updateDevice(device)
                }
            } else {
                rejectGenericProbe(peripheral, reason: "battery level missing")
            }
        }
        
        //设备型号
        if characteristic.uuid == CBUUID(string: "2A24") {
            if let data = characteristic.value, let model = data.ascii(), let deviceName = peripheral.name, let vendor = bleDevicesVendor[deviceName] {
                if vendor == "Apple Inc." && model.contains("Watch") { otherAppleDevices.append(deviceName); return }
                if var device = AirBatteryModel.getByName(deviceName), device.deviceModel != model{
                    if vendor == "Apple Inc." {
                        device.deviceType = model.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "\\d", with: "", options: .regularExpression, range: nil)
                        device.deviceModel = model
                    } else {
                        device.deviceType = getType(deviceName)
                    }
                    device.lastUpdate = Date().timeIntervalSince1970
                    AirBatteryModel.updateDevice(device)
                }
            }
        }
        
        //厂商信息
        if characteristic.uuid == CBUUID(string: "2A29") {
            if let deviceName = peripheral.name {
                //Apple = Apple Inc.
                if let data = characteristic.value, let vendor = data.ascii() { bleDevicesVendor[deviceName] = vendor }
            }
        }
        //self.centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func getLevel(_ name: String, _ side: String) -> UInt8{
        //guard let result = process(path: "/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"]) else { return 255 }
        if let json = try? JSONSerialization.jsonObject(with: Data(SPBluetoothDataModel.shared.data.utf8), options: []) as? [String: Any],
        let SPBluetoothDataTypeRaw = json["SPBluetoothDataType"] as? [Any],
        let SPBluetoothDataType = SPBluetoothDataTypeRaw[0] as? [String: Any],
        let device_connected = SPBluetoothDataType["device_connected"] as? [Any] {
            for device in device_connected{
                let d = device as! [String: Any]
                if let n = d.keys.first,n == name,let info = d[n] as? [String: Any] {
                    if let level = info["device_batteryLevel"+side] as? String {
                        return UInt8(level.replacingOccurrences(of: "%", with: "")) ?? 255
                    }
                }
            }
        }
        return 255
    }
    
    func getType(_ name: String) -> String{
        //guard let result = process(path: "/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"]) else { return "general_bt" }
        if let json = try? JSONSerialization.jsonObject(with: Data(SPBluetoothDataModel.shared.data.utf8), options: []) as? [String: Any],
        let SPBluetoothDataTypeRaw = json["SPBluetoothDataType"] as? [Any],
        let SPBluetoothDataType = SPBluetoothDataTypeRaw[0] as? [String: Any],
        let device_connected = SPBluetoothDataType["device_connected"] as? [Any] {
            for device in device_connected{
                let d = device as! [String: Any]
                if let n = d.keys.first,n == name,let info = d[n] as? [String: Any] {
                    if let type = info["device_minorType"] as? String {
                        return type
                    }
                }
            }
        }
        return "general_bt"
    }
    
    func getAirpods(peripheral: CBPeripheral, data: Data, messageType: String) {
        guard let name = peripheral.name else { return }
        if AirBatteryModel.checkIfBlocked(name: name) { return }
        
        if let deviceName = peripheral.name{
            //NSLog("AirPods: \(messageType) message [\(data.hexEncodedString())]")
            let now = Date().timeIntervalSince1970
            let dataHex = data.hexEncodedString()
            let index = dataHex.index(dataHex.startIndex, offsetBy: 14)
            let flip = (strtoul(String(dataHex[index]), nil, 16) & 0x02) == 0
            let deviceID = peripheral.identifier.uuidString
            var model = (messageType == "open" ? getHeadphoneModel(String(format: "%02x%02x", data[6], data[5])) : "Airpods Pro 2")
            if let Case = AirBatteryModel.getByName(deviceName + " (Case)".local) { model = Case.deviceModel ?? model }
            
            var caseLevel = data[messageType == "open" ? 16 : 12]
            var caseCharging = 0
            if caseLevel != 255 {
                caseCharging = caseLevel > 100 ? 1 : 0
                caseLevel = (caseLevel ^ 128) & caseLevel
            }else{ caseLevel = getLevel(deviceName, "Case") }
            
            var leftLevel = data[messageType == "open" ? (flip ? 15 : 14) : 13]
            var leftCharging = 0
            if leftLevel != 255 {
                leftCharging = leftLevel > 100 ? 1 : 0
                leftLevel = (leftLevel ^ 128) & leftLevel
            }else{ leftLevel = getLevel(deviceName, "Left") }
            
            var rightLevel = data[messageType == "open" ? (flip ? 14 : 15) : 14]
            var rightCharging = 0
            if rightLevel != 255 {
                rightCharging = rightLevel > 100 ? 1 : 0
                rightLevel = (rightLevel ^ 128) & rightLevel
            }else{ rightLevel = getLevel(deviceName, "Right") }
            
            if !["Airpods Max", "Beats Solo Pro", "Beats Solo 3", "Beats Studio Pro"].contains(model) {
                if caseLevel != 255 { AirBatteryModel.updateDevice(Device(deviceID: deviceID, deviceType: "ap_case", deviceName: deviceName + " (Case)".local, deviceModel: model, batteryLevel: Int(caseLevel), isCharging: caseCharging, lastUpdate: now)) }
                
                // Keep the physical component readings as the source of truth.
                // Earbud merging is a presentation choice and must never discard L/R values.
                AirBatteryModel.hideDevice(deviceName + " 🄻🅁")
                if leftLevel != 255 {
                    AirBatteryModel.updateDevice(
                        Device(
                            deviceID: deviceID + "_Left",
                            deviceType: "ap_pod_left",
                            deviceName: deviceName + " 🄻",
                            deviceModel: model,
                            batteryLevel: Int(leftLevel),
                            isCharging: leftCharging,
                            isHidden: false,
                            parentName: deviceName + " (Case)".local,
                            lastUpdate: now
                        )
                    )
                }
                if rightLevel != 255 {
                    AirBatteryModel.updateDevice(
                        Device(
                            deviceID: deviceID + "_Right",
                            deviceType: "ap_pod_right",
                            deviceName: deviceName + " 🅁",
                            deviceModel: model,
                            batteryLevel: Int(rightLevel),
                            isCharging: rightCharging,
                            isHidden: false,
                            parentName: deviceName + " (Case)".local,
                            lastUpdate: now
                        )
                    )
                }
            } else {
                if model == "Beats Studio Pro" {
                    AirBatteryModel.updateDevice(Device(deviceID: deviceID, deviceType: "ap_case", deviceName: deviceName, deviceModel: model, batteryLevel: Int(rightLevel), isCharging: rightCharging, lastUpdate: now))
                } else {
                    leftLevel = leftLevel != 255 ? leftLevel : 0
                    rightLevel = rightLevel != 255 ? rightLevel : 0
                    AirBatteryModel.updateDevice(Device(deviceID: deviceID, deviceType: "ap_case", deviceName: deviceName, deviceModel: model, batteryLevel: Int(max(rightLevel, leftLevel)), isCharging: rightCharging + leftCharging > 0 ? 1 : 0, lastUpdate: now))
                }
            }
            //print("Type: \(messageType), C:\(caseLevel), L:\(leftLevel), R:\(rightLevel), Flip:\(messageType == "open" ? "\(flip)" : "none")")
            //print("Raw Data: \(data.hexEncodedString())")
        }
    }
    
    func getPaired() -> [String]{
        var paired:[String] = []
        //guard let result = process(path: "/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType", "-json"]) else { return paired }
        if let json = try? JSONSerialization.jsonObject(with: Data(SPBluetoothDataModel.shared.data.utf8), options: []) as? [String: Any],
        let SPBluetoothDataTypeRaw = json["SPBluetoothDataType"] as? [Any],
        let SPBluetoothDataType = SPBluetoothDataTypeRaw[0] as? [String: Any]{
            if let device_connected = SPBluetoothDataType["device_connected"] as? [Any]{
                for device in device_connected{
                    let d = device as! [String: Any]
                    if let key = d.keys.first { paired.append(key) }
                }
            }
            if let device_connected = SPBluetoothDataType["device_not_connected"] as? [Any]{
                for device in device_connected{
                    let d = device as! [String: Any]
                    if let key = d.keys.first { paired.append(key) }
                }
            }
        }
        return paired
    }
}

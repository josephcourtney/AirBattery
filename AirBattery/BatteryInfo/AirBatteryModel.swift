//
//  AirBatteryModel.swift
//  AirBattery
//
//  Created by apple on 2024/2/9.
//

import Foundation

struct btdDevice: Codable, Equatable {
    let time: Date
    let vid: String
    let pid: String
    let type: String
    let mac: String
    let name: String
    let level: Int
}

struct Device: Hashable, Codable {
    var hasBattery: Bool = true
    var deviceID: String
    var deviceType: String
    var deviceName: String
    var deviceModel: String?
    var batteryLevel: Int
    var isCharging: Int
    var isCharged: Bool = false
    var isPaused: Bool = false
    var acPowered: Bool = false
    var isHidden: Bool = false
    var lowPower: Bool = false
    var parentName: String = ""
    var lastUpdate: Double
    var realUpdate: Double = 0.0
    var mobileDeviceID: String?
    var bleDeviceID: String?
    var batterySource: DeviceObservationSource?
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hasBattery)
        hasher.combine(deviceID)
        hasher.combine(deviceType)
        hasher.combine(deviceName)
        hasher.combine(deviceModel)
        hasher.combine(batteryLevel)
        hasher.combine(isCharging)
        hasher.combine(isCharged)
        hasher.combine(isPaused)
        hasher.combine(acPowered)
        hasher.combine(isHidden)
        hasher.combine(lowPower)
        hasher.combine(lastUpdate)
        hasher.combine(realUpdate)
        hasher.combine(parentName)
        hasher.combine(mobileDeviceID)
        hasher.combine(bleDeviceID)
        hasher.combine(batterySource)
    }

    mutating func mergeIdentifiers(fromExisting existing: Device) {
        var identifiers = DeviceIdentifierSet(
            canonicalID: existing.deviceID,
            mobileDeviceID: existing.mobileDeviceID,
            bleDeviceID: existing.bleDeviceID
        )
        identifiers.merge(
            canonicalID: deviceID,
            mobileDeviceID: mobileDeviceID,
            bleDeviceID: bleDeviceID
        )
        deviceID = identifiers.canonicalID
        mobileDeviceID = identifiers.mobileDeviceID
        bleDeviceID = identifiers.bleDeviceID
    }

    func matchesIdentifier(_ identifier: String) -> Bool {
        DeviceIdentifierSet(
            canonicalID: deviceID,
            mobileDeviceID: mobileDeviceID,
            bleDeviceID: bleDeviceID
        ).matches(identifier)
    }
}


struct AirPodsBatteryGroup: Hashable {
    let name: String
    let caseDevice: Device?
    let leftEarbud: Device?
    let rightEarbud: Device?
    let legacyMergedEarbuds: Device?

    var components: [Device] {
        var result = [caseDevice, leftEarbud, rightEarbud].compactMap { $0 }
        if leftEarbud == nil, rightEarbud == nil, let legacyMergedEarbuds {
            result.append(legacyMergedEarbuds)
        }
        return result
    }

    var componentCount: Int {
        components.count
    }

    func mergedEarbudLevel(enabled: Bool, threshold: Int) -> Int? {
        guard let leftEarbud, let rightEarbud else { return nil }
        return EarbudMergePolicy.mergedLevel(
            enabled: enabled,
            threshold: threshold,
            leftLevel: leftEarbud.batteryLevel,
            leftCharging: leftEarbud.isCharging,
            rightLevel: rightEarbud.batteryLevel,
            rightCharging: rightEarbud.isCharging
        )
    }

    func mergedEarbudCharging(enabled: Bool, threshold: Int) -> Int? {
        guard let leftEarbud, let rightEarbud else { return nil }
        return EarbudMergePolicy.mergedCharging(
            enabled: enabled,
            threshold: threshold,
            leftLevel: leftEarbud.batteryLevel,
            leftCharging: leftEarbud.isCharging,
            rightLevel: rightEarbud.batteryLevel,
            rightCharging: rightEarbud.isCharging
        )
    }
}

struct BatteryComponentPresentation: Identifiable, Hashable {
    let role: BatteryComponentRole
    let device: Device

    var id: String {
        role.rawValue + ":" + device.deviceID
    }

    var label: String {
        DevicePresentationNaming.componentLabel(role)
    }

    var level: Int { device.batteryLevel }
    var charging: Int { device.isCharging }
}

struct LogicalDevicePresentation: Identifiable, Hashable {
    let id: String
    let displayName: String
    let compactName: String
    let representative: Device
    let components: [BatteryComponentPresentation]
    let newestUpdate: Double

    var latestBatterySource: DeviceObservationSource? {
        components
            .map(\.device)
            .filter { $0.batterySource != nil }
            .max(by: { $0.lastUpdate < $1.lastUpdate })?
            .batterySource
    }

    var primaryLevel: Int {
        components.first?.level ?? representative.batteryLevel
    }
}

class AirBatteryModel {
    static var lock = false
    static var Devices: [Device] = []
    static let machineType = ud.string(forKey: "machineType") ?? "Mac"
    static let key = "com.josephcourtney.AirBattery.widget"
    static let appGroupIdentifier = "group.com.josephcourtney.AirBattery"

    private static let presenceLock = NSLock()
    private static var lastBLEPresence: [String: Double] = [:]

    static func noteBLEPresence(name: String) {
        let key = normalizedObservationName(name)
        presenceLock.lock()
        lastBLEPresence[key] = Date().timeIntervalSince1970
        presenceLock.unlock()
    }

    static func batteryDevices(observedAs name: String) -> [Device] {
        let key = normalizedObservationName(name)
        return getAll(noFilter: true).filter {
            $0.hasBattery && normalizedObservationName(observationName(for: $0)) == key
        }
    }

    private static func isRecentlyBLEObserved(_ device: Device, now: Double) -> Bool {
        let interval = max(1, ud.integer(forKey: "updateInterval"))
        // BLE scans repeat every 29 * updateInterval seconds. Keep a last-known
        // battery record visible while the corresponding device is still being
        // observed, without altering the battery reading's real timestamp.
        let presenceLifetime = Double(max(90, interval * 65))
        let key = normalizedObservationName(observationName(for: device))
        presenceLock.lock()
        let lastSeen = lastBLEPresence[key]
        presenceLock.unlock()
        guard let lastSeen else { return false }
        return now - lastSeen <= presenceLifetime
    }

    private static func observationName(for device: Device) -> String {
        var name = device.deviceName
        if device.deviceType.hasPrefix("ap_pod") && !device.parentName.isEmpty {
            name = device.parentName
        }
        for suffix in [" (Case)", "（充电盒）", " 🄻🅁", " 🄻", " 🅁"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name
    }

    private static func normalizedObservationName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func airPodsBaseName(for device: Device) -> String? {
        guard device.deviceType == "ap_case" || device.deviceType.hasPrefix("ap_pod") else {
            return nil
        }

        var name = device.deviceType.hasPrefix("ap_pod") && !device.parentName.isEmpty
            ? device.parentName
            : device.deviceName
        for suffix in [" (Case)", "（充电盒）", " 🄻🅁", " 🄻", " 🅁"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name
    }

    static func airPodsGroup(for device: Device, in devices: [Device]) -> AirPodsBatteryGroup? {
        guard let baseName = airPodsBaseName(for: device) else { return nil }
        let matching = devices.filter { candidate in
            guard let candidateBase = airPodsBaseName(for: candidate) else { return false }
            return normalizedObservationName(candidateBase) == normalizedObservationName(baseName)
        }

        let caseDevice = matching.first {
            $0.deviceType == "ap_case" &&
                ($0.deviceName.hasSuffix(" (Case)") || $0.deviceName.hasSuffix("（充电盒）"))
        }
        let left = matching.first { $0.deviceType == "ap_pod_left" }
        let right = matching.first { $0.deviceType == "ap_pod_right" }
        let legacyMerged = matching.first { $0.deviceType == "ap_pod_all" }

        guard caseDevice != nil || left != nil || right != nil || legacyMerged != nil else {
            return nil
        }
        return AirPodsBatteryGroup(
            name: baseName,
            caseDevice: caseDevice,
            leftEarbud: left,
            rightEarbud: right,
            legacyMergedEarbuds: legacyMerged
        )
    }

    static func airPodsGroup(observedAs name: String) -> AirPodsBatteryGroup? {
        let devices = getAll(noFilter: true)
        guard let representative = devices.first(where: {
            guard let base = airPodsBaseName(for: $0) else { return false }
            return normalizedObservationName(base) == normalizedObservationName(name)
        }) else {
            return nil
        }
        return airPodsGroup(for: representative, in: devices)
    }

    private static func mergedAirPodsDevice(
        _ group: AirPodsBatteryGroup,
        level: Int,
        charging: Int
    ) -> Device {
        let source = group.leftEarbud ?? group.rightEarbud ?? group.caseDevice ?? group.legacyMergedEarbuds!
        return Device(
            deviceID: source.deviceID,
            deviceType: "ap_pod_all",
            deviceName: group.name,
            deviceModel: source.deviceModel,
            batteryLevel: level,
            isCharging: charging,
            parentName: group.name,
            lastUpdate: source.lastUpdate,
            mobileDeviceID: source.mobileDeviceID,
            bleDeviceID: source.bleDeviceID,
            batterySource: source.batterySource
        )
    }

    static func logicalPresentations(
        from devices: [Device],
        mergeEarbuds: Bool,
        mergeThreshold: Int
    ) -> [LogicalDevicePresentation] {
        var result: [LogicalDevicePresentation] = []
        var consumedAirPods = Set<String>()

        for device in devices {
            if let baseName = airPodsBaseName(for: device),
               let group = airPodsGroup(for: device, in: devices) {
                let key = normalizedObservationName(baseName)
                guard consumedAirPods.insert(key).inserted else { continue }

                var components: [BatteryComponentPresentation] = []
                if let caseDevice = group.caseDevice {
                    components.append(
                        BatteryComponentPresentation(role: .caseBattery, device: caseDevice)
                    )
                }

                if let merged = group.mergedEarbudLevel(
                    enabled: mergeEarbuds,
                    threshold: mergeThreshold
                ) {
                    let charging = group.mergedEarbudCharging(
                        enabled: mergeEarbuds,
                        threshold: mergeThreshold
                    ) ?? 0
                    components.append(
                        BatteryComponentPresentation(
                            role: .earbuds,
                            device: mergedAirPodsDevice(
                                group,
                                level: merged,
                                charging: charging
                            )
                        )
                    )
                } else {
                    if let left = group.leftEarbud {
                        components.append(
                            BatteryComponentPresentation(role: .leftEarbud, device: left)
                        )
                    }
                    if let right = group.rightEarbud {
                        components.append(
                            BatteryComponentPresentation(role: .rightEarbud, device: right)
                        )
                    }
                    if group.leftEarbud == nil,
                       group.rightEarbud == nil,
                       let legacy = group.legacyMergedEarbuds {
                        components.append(
                            BatteryComponentPresentation(role: .earbuds, device: legacy)
                        )
                    }
                }

                guard let representative =
                    group.caseDevice ??
                    group.leftEarbud ??
                    group.rightEarbud ??
                    group.legacyMergedEarbuds
                else {
                    continue
                }

                result.append(
                    LogicalDevicePresentation(
                        id: "airpods:" + key,
                        displayName: group.name,
                        compactName: DevicePresentationNaming.compactName(
                            deviceType: representative.deviceType,
                            displayName: group.name
                        ),
                        representative: representative,
                        components: components,
                        newestUpdate: group.components.map(\.lastUpdate).max() ??
                            representative.lastUpdate
                    )
                )
                continue
            }

            result.append(
                LogicalDevicePresentation(
                    id: "device:" + device.deviceID + ":" + device.deviceName,
                    displayName: device.deviceName,
                    compactName: DevicePresentationNaming.compactName(
                        deviceType: device.deviceType,
                        displayName: device.deviceName
                    ),
                    representative: device,
                    components: [
                        BatteryComponentPresentation(role: .primary, device: device)
                    ],
                    newestUpdate: device.lastUpdate
                )
            )
        }

        return result
    }

    static func widgetLogicalPresentations(
        from devices: [Device]
    ) -> [LogicalDevicePresentation] {
        logicalPresentations(
            from: devices.filter(\.hasBattery),
            mergeEarbuds: false,
            mergeThreshold: 0
        )
    }

    static func widgetPresentationOrder(
        from devices: [Device]
    ) -> [Device] {
        widgetLogicalPresentations(from: devices)
            .flatMap(\.components)
            .map(\.device)
    }

    static func presentation(
        for device: Device,
        in devices: [Device],
        mergeEarbuds: Bool,
        mergeThreshold: Int
    ) -> LogicalDevicePresentation? {
        logicalPresentations(
            from: devices,
            mergeEarbuds: mergeEarbuds,
            mergeThreshold: mergeThreshold
        ).first {
            $0.components.contains(where: {
                $0.device.deviceID == device.deviceID &&
                $0.device.deviceType == device.deviceType
            }) ||
            $0.representative.deviceID == device.deviceID
        }
    }

    static func isAirPodsSecondaryRow(_ device: Device, in devices: [Device]) -> Bool {
        guard let group = airPodsGroup(for: device, in: devices),
              let representative =
                group.caseDevice ??
                group.leftEarbud ??
                group.rightEarbud ??
                group.legacyMergedEarbuds
        else {
            return false
        }

        return !(
            representative.deviceID == device.deviceID &&
            representative.deviceType == device.deviceType &&
            representative.deviceName == device.deviceName
        )
    }

    static func groupedDisplayRowCount(_ devices: [Device]) -> Int {
        devices.filter { !isAirPodsSecondaryRow($0, in: devices) }.count
    }

    static func groupedAirPodsRowCount(_ devices: [Device]) -> Int {
        Set(
            devices.compactMap { device in
                airPodsBaseName(for: device).map(normalizedObservationName)
            }
        ).count
    }
    
    static func updateDevice(_ device: Device) {
        //let blockedItems = (ud.object(forKey: "blockedDevices") as? [String]) ?? [String]()
        //if blockedItems.contains(device.deviceName) { return }
        if lock { return }
        lock = true
        //self.Devices.removeAll(where: {blockedItems.contains($0.deviceName)})
        if let index = self.Devices.firstIndex(where: { $0.deviceName == device.deviceName }) {
            var merged = device
            merged.mergeIdentifiers(fromExisting: self.Devices[index])
            self.Devices[index] = merged
        } else {
            self.Devices.append(device)
        }
        lock = false
    }
    
    static func hideDevice(_ name: String) {
        for index in Devices.indices {
            if Devices[index].deviceName == name {
                Devices[index].isHidden = true
            }
        }
    }
    
    static func unhideDevice(_ name: String) {
        for index in Devices.indices {
            if Devices[index].deviceName == name {
                Devices[index].isHidden = false
            }
        }
    }
    
    static func getBlackList() -> [Device] {
        let blackList = (ud.object(forKey: "blackList") ?? []) as! [String]
        let devices = getAll(noFilter: true)
        return devices.filter({ blackList.contains($0.deviceName) })
    }
    
    static func getAll(reverse: Bool = false, noFilter: Bool = false) -> [Device] {
        let thisMac = ud.string(forKey: "deviceName")
        let disappearTime = (ud.object(forKey: "disappearTime") ?? 20) as! Int
        let blackList = (ud.object(forKey: "blackList") ?? []) as! [String]
        let now = Double(Date().timeIntervalSince1970)
        var list = (reverse ? Array(Devices.reversed()) : Devices).filter {
            now - $0.lastUpdate < Double(disappearTime * 60) ||
                isRecentlyBLEObserved($0, now: now)
        }
        if !noFilter { list = list.filter { !blackList.contains($0.deviceName) && !$0.isHidden } }
        var newList: [Device] = list.filter({ $0.parentName == thisMac })
        for d in list {
            if d.parentName == "" && d.parentName != thisMac {
                newList.append(d)
                for sd in list.filter({ $0.parentName == d.deviceName }) {
                    newList.append(sd)
                }
            }
        }
        for dd in list.filter({ !newList.contains($0) }) { newList.append(dd) }
        return newList.filter({ !checkIfBlocked(name: $0.deviceName) })
    }
    
    static func getByName(_ name: String) -> Device? {
        for d in getAll(noFilter: true) { if d.deviceName == name { return d } }
        return nil
    }
    
    static func getByID(_ id: String) -> Device? {
        for d in getAll(noFilter: true) {
            if d.matchesIdentifier(id) { return d }
        }
        return nil
    }
    
    
    static func sharedDataDirectory() -> URL {
        if let container = fd.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            let directory = container.appendingPathComponent(
                "Documents",
                isDirectory: true
            )
            try? fd.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
        }

        // This fallback keeps development/ad-hoc tools useful if the App Group
        // entitlement is unavailable. Production app/widget builds use the
        // shared container above.
        if Bundle.main.bundleIdentifier == key {
            return fd.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
        }
        return fd.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent(
            "Containers/\(key)/Data/Documents",
            isDirectory: true
        )
    }

    static func getJsonURL() -> URL {
        sharedDataDirectory().appendingPathComponent("data.json")
    }

    static func getNearcastURL() -> URL {
        let url = sharedDataDirectory().appendingPathComponent(
            "NearcastData",
            isDirectory: true
        )
        try? fd.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func getHeartbeatURL() -> URL {
        sharedDataDirectory().appendingPathComponent("heartbeat")
    }

    static func snapshotIsFresh(
        maxAge: TimeInterval = 120,
        now: Date = Date()
    ) -> Bool {
        guard let attributes = try? fd.attributesOfItem(
            atPath: getHeartbeatURL().path
        ),
        let modified = attributes[.modificationDate] as? Date
        else {
            return false
        }
        return now.timeIntervalSince(modified) <= maxAge
    }

    static func migrateLegacySharedStorageIfNeeded() {
        guard fd.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) != nil else {
            return
        }

        let destination = sharedDataDirectory()
        let legacy = fd.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent(
            "Containers/\(key)/Data/Documents",
            isDirectory: true
        )

        let oldData = legacy.appendingPathComponent("data.json")
        let newData = destination.appendingPathComponent("data.json")
        if !fd.fileExists(atPath: newData.path),
           fd.fileExists(atPath: oldData.path) {
            try? fd.copyItem(at: oldData, to: newData)
        }

        let oldNearcast = legacy.appendingPathComponent(
            "NearcastData",
            isDirectory: true
        )
        let newNearcast = destination.appendingPathComponent(
            "NearcastData",
            isDirectory: true
        )
        if !fd.fileExists(atPath: newNearcast.path),
           fd.fileExists(atPath: oldNearcast.path) {
            try? fd.copyItem(at: oldNearcast, to: newNearcast)
        }
    }
    
    static func widgetStoredDevices(
        from devices: [Device],
        internalBattery: Device?,
        reverse: Bool
    ) -> [Device] {
        var ordered = reverse ? Array(devices.reversed()) : devices
        if let internalBattery, internalBattery.hasBattery {
            ordered.insert(internalBattery, at: 0)
        }
        return ordered
    }

    static func writeData(){
        //let showMac = ud.object(forKey: "showMacOnWidget") as? Bool ?? true
        let revList = ud.object(forKey: "revListOnWidget") as? Bool ?? false

        let ibStatus = InternalBattery.status
        let devices = widgetStoredDevices(
            from: getAll(),
            internalBattery: ibStatus.hasBattery ? ib2ab(ibStatus) : nil,
            reverse: revList
        )
        do {
            let jsonData = try JSONEncoder().encode(devices)
            try jsonData.write(to: getJsonURL(), options: .atomic)
            try Data().write(to: getHeartbeatURL(), options: .atomic)
        } catch {
            print("Write JSON error：\(error)")
        }
    }
    
    static func readData(url: URL = getJsonURL()) -> [Device]{
        do {
            let jsonData = try Data(contentsOf: url)
            let list = try JSONDecoder().decode([Device].self, from: jsonData)
            return list
        } catch {
            print("Read JSON error：\(error)")
        }
        return []
    }
    
    static func ncGetAll(url: URL, fromWidget: Bool = false) -> [Device] {
        let disappearTime = (ud.object(forKey: "disappearTime") ?? 20) as! Int
        let devices = readData(url: url)
        let now = Double(Date().timeIntervalSince1970)
        var localDevices = getAll().map({ $0.deviceName })
        if fromWidget { localDevices = readData().map({ $0.deviceName }) }
        var list = devices.filter{(now - $0.lastUpdate < Double(disappearTime * 60))}.filter({!localDevices.contains($0.deviceName)})
        if let first = devices.first { if !list.contains(first) && list.count != 0 { list.insert(first, at: 0) }}
        if let first = list.first { if list.count == 1 && !first.hasBattery { return [] }}
        return list
    }
    
    static func checkIfBlocked(name: String) -> Bool {
        let whitelistMode = ud.bool(forKey: "whitelistMode")
        let filteredNames = (ud.object(forKey: "blockedDevices") as? [String]) ?? []

        if whitelistMode {
            // An empty allowlist should not make Bluetooth discovery silently
            // discard every device. Treat it as no broad name filter until at
            // least one allowed name is configured.
            return !filteredNames.isEmpty && !filteredNames.contains(name)
        }

        return filteredNames.contains(name)
    }
}

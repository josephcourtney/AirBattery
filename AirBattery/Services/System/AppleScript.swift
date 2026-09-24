//
//  AppleScript.swift
//  AirBattery
//
//  Created by apple on 2024/7/3.
//

import Foundation
import WidgetKit

class listAll: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        var allDevices = DeviceStore.shared.getAll(noFilter: true)
        let ibStatus = InternalBattery.status
        if ibStatus.hasBattery { allDevices.insert(ib2ab(ibStatus), at: 0) }
        let ncFiles = getFiles(withExtension: "json", in: BatterySnapshotStore.nearcastDirectory)
        for ncFile in ncFiles { allDevices += BatterySnapshotStore.nearcastDevices(at: ncFile) }
        return allDevices.map({ $0.deviceName })
    }
}

class reloadAll: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DispatchQueue.global(qos: .utility).async {
            print("Reloading all widgets...")
            BatterySnapshotStore.writeCurrentSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

class getUsage: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let device = evaluatedArguments?["name"] as? String else {
            return -1
        }
        var allDevices = DeviceStore.shared.getAll(noFilter: true)
        let ibStatus = InternalBattery.status
        if ibStatus.hasBattery { allDevices.insert(ib2ab(ibStatus), at: 0) }
        let ncFiles = getFiles(withExtension: "json", in: BatterySnapshotStore.nearcastDirectory)
        for ncFile in ncFiles { allDevices += BatterySnapshotStore.nearcastDevices(at: ncFile) }
        for d in allDevices { if d.deviceName == device { return d.batteryLevel } }
        return -1
    }
}

class getStatus: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let device = evaluatedArguments?["name"] as? String else {
            return -1
        }
        var allDevices = DeviceStore.shared.getAll(noFilter: true)
        let ibStatus = InternalBattery.status
        if ibStatus.hasBattery { allDevices.insert(ib2ab(ibStatus), at: 0) }
        let ncFiles = getFiles(withExtension: "json", in: BatterySnapshotStore.nearcastDirectory)
        for ncFile in ncFiles { allDevices += BatterySnapshotStore.nearcastDevices(at: ncFile) }
        for d in allDevices { if d.deviceName == device { return d.isCharging } }
        return -1
    }
}


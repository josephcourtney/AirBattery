//
//  BTDBattery.swift
//  AirBattery
//
//  Created by apple on 2024/6/23.
//

import Foundation
import IOBluetooth

private struct BluetoothLogEntry: Decodable {
    let mac: String
    var name: String
    let type: String
    let time: String
    let level: Int
    let status: String

    var identity: String {
        "\(name)\u{1f}\(mac)\u{1f}\(type)"
    }
}

final class BTDBattery {
    static var allDevices = [String]()

    var readBTHID: Bool { AppPreferences.readBTHID }

    func startScan() {
        print("ℹ️ Start scanning Bluetooth HID devices...")
        scanDevices(longScan: true)
    }

    func scanDevices(longScan: Bool = false) {
        DispatchQueue.global(qos: .utility).async {
            guard self.readBTHID else { return }

            if longScan {
                BTDBattery.getOtherDevice(last: "2h", timeout: 25)
            }

            let connectedNames = Set(BTDBattery.getConnected())
            for name in BTDBattery.allDevices where connectedNames.contains(name) {
                guard var device = AirBatteryModel.getByName(name) else {
                    continue
                }
                device.lastUpdate = Date().timeIntervalSince1970
                AirBatteryModel.updateDevice(device)
            }
        }
    }

    static func getConnected(mac: Bool = false) -> [String] {
        guard let paired =
            IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]
        else {
            return []
        }

        let connected = paired.filter { $0.isConnected() }
        if mac {
            return connected.compactMap {
                guard let address = $0.addressString, !address.isEmpty else {
                    return nil
                }
                return address.uppercased()
                    .replacingOccurrences(of: "-", with: ":")
            }
        }

        return connected.compactMap {
            guard let name = $0.name, !name.isEmpty else { return nil }
            return name
        }
    }

    static func getOtherDevice(
        last: String = "10m",
        timeout: Int = 0
    ) {
        guard let resourcePath = Bundle.main.resourcePath,
              let result = process(
                  path: "/bin/bash",
                  arguments: [
                      "\(resourcePath)/logReader.sh",
                      "mac",
                      last,
                  ],
                  timeout: timeout
              )
        else {
            return
        }

        let decoder = JSONDecoder()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withTimeZone,
        ]
        var latest: [String: BluetoothLogEntry] = [:]

        for line in result.split(separator: "\n") {
            guard let entry = try? decoder.decode(
                BluetoothLogEntry.self,
                from: Data(line.utf8)
            ) else {
                continue
            }
            latest[entry.identity] = entry
        }

        let connected = Set(getConnected(mac: true))
        let parent = AppPreferences.deviceName

        for var entry in latest.values where connected.contains(entry.mac) {
            if entry.name.isEmpty {
                entry.name = "\(entry.type) (\(entry.mac))"
            }
            if !allDevices.contains(entry.name) {
                allDevices.append(entry.name)
            }

            AirBatteryModel.updateDevice(
                Device(
                    deviceID: entry.mac,
                    deviceType: entry.type,
                    deviceName: entry.name,
                    batteryLevel: min(100, max(0, entry.level)),
                    isCharging: entry.status == "+" ? 1 : 0,
                    parentName: parent,
                    lastUpdate: Date().timeIntervalSince1970,
                    realUpdate:
                        isoFormatter.date(from: entry.time)?
                            .timeIntervalSince1970 ?? 0
                )
            )
        }
    }
}

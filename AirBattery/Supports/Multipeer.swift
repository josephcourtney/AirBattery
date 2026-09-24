//
//  Multipeer.swift
//  AirBattery
//
//  Created by apple on 2024/6/10.
//

import Combine
import Foundation
import MultipeerKit

@MainActor
final class MultipeerService: ObservableObject {
    var nearcastGroupID: String { AppPreferences.nearcastGroupID }
    var nearcastSharingKey: String { AppPreferences.nearcastSharingKey }
    var deviceName: String { AppPreferences.deviceName }
    let transceiver: MultipeerTransceiver

    init(serviceType: String) {
        let configuration = MultipeerConfiguration(
            serviceType: serviceType,
            peerName: getMacDeviceName(),
            defaults: UserDefaults.standard,
            security: .default,
            invitation: .automatic)
        transceiver = MultipeerTransceiver(configuration: configuration)
        
        // Start the transceiver
        //transceiver.resume()
        
        // Handle received data
        transceiver.receive(Data.self) { [weak self] data, peer in
            let peerID = peer.id
            let peerName = peer.name
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let message = try? JSONDecoder().decode(NCMessage.self, from: data) else {
                    print("Failed to decode message")
                    return
                }
                if message.id != self.nearcastGroupID { return }
                switch message.command {
                case "resend":
                    var allDevices = AirBatteryModel.getAll()
                    allDevices.insert(ib2ab(InternalBattery.status), at: 0)
                    do {
                        let jsonData = try JSONEncoder().encode(allDevices)
                        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
                        guard let data = encryptNearcastString(jsonString, groupID: self.nearcastGroupID, sharingKey: self.nearcastSharingKey) else { return }
                        let message = NCMessage(id: String(self.nearcastGroupID), sender: systemUUID ?? self.deviceName, command: "", content: data)
                        self.sendMessage(message, peerID: peerID)
                    } catch {
                        print("Write JSON error：\(error)")
                    }
                    return
                case "trans":
                    // Legacy peers may still send this command. Its payload was
                    // never consumed, so keep it as a no-op compatibility sink.
                    return
                case "notify":
                    print("Info received.")
                    if let jsonString = decryptNearcastString(message.content, groupID: self.nearcastGroupID, sharingKey: self.nearcastSharingKey) {
                        if let jsonData = jsonString.data(using: .utf8) {
                            if let info = try? JSONDecoder().decode(NCNotification.self, from: jsonData) {
                                switch info.type {
                                case 1:
                                    createNotification(title: info.title, message: "\(info.info) (\(peerName))")
                                case 255:
                                    createNotification(title: info.title, message: "\(peerName) \(info.info)")
                                case 254:
                                    let mac = info.atta
                                    DispatchQueue.global(qos: .utility).async {
                                        _ = BTTool.connect(mac: mac)
                                    }
                                    createNotification(title: info.title, message: "\(peerName) \(info.info)")
                                default:
                                    createNotification(title: info.title, message: info.info)
                                }
                            }
                        } else {
                            print("Failed to convert JSON string to Data.")
                        }
                    }
                case "":
                    print("Data received.")
                    if let jsonString = decryptNearcastString(message.content, groupID: self.nearcastGroupID, sharingKey: self.nearcastSharingKey) {
                        if let jsonData = jsonString.data(using: .utf8) {
                            let url = ncFolder.appendingPathComponent("\(message.sender).json")
                            try? jsonData.write(to: url)
                        } else {
                            print("Failed to convert JSON string to Data.")
                        }
                    }
                default:
                    print("Unknown command: \(message.command)")
                    if let info = self.createInfo(type: 255, title: "Unknown Command".local, info: String(format: "doesn't support command \"%@\"".local, message.command)) {
                        self.sendMessage(info, peerID: peerID)
                    }
                    return
                }
            }
        }
        
        print("⚙️ Nearcast Group ID: \(nearcastGroupID)")
    }
    
    func resume() {
        transceiver.resume()
        print("ℹ️ Nearcast is running...")
    }
    
    func stop() {
        transceiver.stop()
        print("ℹ️ Nearcast has stopped")
    }

    func sendMessage(_ message: NCMessage, peerID: String? = nil) {
        guard let data = try? JSONEncoder().encode(message) else {
            print("Failed to encode message")
            return
        }
        let peers = removeDuplicatesPeer(peers: transceiver.availablePeers)
        if let peerID {
            transceiver.send(data, to: peers.filter({ $0.id == peerID }))
        } else {
            for peer in peers { transceiver.send(data, to: [peer]) }
        }
    }
    
    func refeshAll() {
        print("ℹ️ Pulling data...")
        let message = NCMessage(id: String(nearcastGroupID), sender: systemUUID ?? self.deviceName, command: "resend", content: "")
        self.sendMessage(message)
    }
    
    func createInfo(type: Int = 0, title: String, info: String, atta: String = "") -> NCMessage? {
        do {
            let notification = NCNotification(type: type, title: title, info: info, atta: atta)
            let jsonData = try JSONEncoder().encode(notification)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
            guard let data = encryptNearcastString(jsonString, groupID: self.nearcastGroupID, sharingKey: self.nearcastSharingKey) else { return nil }
            return NCMessage(id: String(self.nearcastGroupID), sender: systemUUID ?? self.deviceName, command: "notify", content: data)
        } catch {
            print("Write JSON error：\(error)")
        }
        return nil
    }
}

func removeDuplicatesPeer(peers: [Peer]) -> [Peer] {
    var seenIDs = Set<String>()
    let filteredPeers = peers.filter { peer in
        if seenIDs.contains(peer.id) {
            return false
        } else {
            seenIDs.insert(peer.id)
            return true
        }
    }
    return filteredPeers
}

struct NCMessage: Codable, Sendable {
    let id: String
    let sender: String
    let command: String
    let content: String
}

struct NCNotification: Codable, Sendable {
    /// 0 = normal
    /// 1 = normal error
    /// 254 = bt error
    /// 255 = unknow command
    let type: Int
    let title: String
    let info: String
    let atta: String
}

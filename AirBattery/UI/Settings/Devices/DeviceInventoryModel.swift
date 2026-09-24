import Combine
import Foundation

@MainActor
final class DeviceInventoryModel: ObservableObject {
    @Published private(set) var devices: [KnownDeviceSnapshot] = []

    func refresh(using service: DeviceInventoryService) {
        devices = service.currentInventory()
    }
}

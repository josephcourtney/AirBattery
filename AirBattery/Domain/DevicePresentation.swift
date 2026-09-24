import Foundation

enum BatteryComponentRole: String, Codable, Hashable {
    case primary
    case caseBattery
    case leftEarbud
    case rightEarbud
    case earbuds
}

enum DevicePresentationNaming {
    static func compactName(deviceType: String, displayName: String) -> String {
        let type = deviceType.lowercased()
        let name = displayName.lowercased()

        if type == "ap_case" || type.hasPrefix("ap_pod") || name.contains("airpods") {
            return "AirPods"
        }
        if type.contains("watch") || name.contains("apple watch") {
            return "Watch"
        }
        if type.contains("iphone") {
            return "iPhone"
        }
        if type.contains("ipad") {
            return "iPad"
        }
        if type.contains("mac") || type.contains("book") || type.contains("mini") ||
            type.contains("studio") || type.contains("imac") {
            return "Mac"
        }
        if type.contains("keyboard") || name.contains("keyboard") {
            return "Keyboard"
        }
        if type.contains("mouse") || name.contains("mouse") ||
            name.contains("mx ergo") {
            return "Mouse"
        }
        if type.contains("trackpad") || name.contains("trackpad") {
            return "Trackpad"
        }
        return displayName
    }

    static func componentLabel(_ role: BatteryComponentRole) -> String {
        switch role {
        case .primary: return "Battery"
        case .caseBattery: return "Case"
        case .leftEarbud: return "Left"
        case .rightEarbud: return "Right"
        case .earbuds: return "Earbuds"
        }
    }
}

import Foundation
import ServiceManagement

@discardableResult
func isLoginItemEnabled() -> Bool {
    switch SMAppService.mainApp.status {
    case .enabled, .requiresApproval:
        return true
    case .notRegistered, .notFound:
        return false
    @unknown default:
        return false
    }
}

@discardableResult
func ensureLoginItem(enabled: Bool) -> Bool {
    let service = SMAppService.mainApp
    do {
        if enabled {
            if service.status == .notRegistered || service.status == .notFound {
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
        return true
    } catch {
        NSLog(
            "[AirBattery] SMAppService main-app registration failed: \(error.localizedDescription)"
        )
        return false
    }
}

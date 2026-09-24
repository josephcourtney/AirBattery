import AppKit

@MainActor
final class SurfaceController {
    static let shared = SurfaceController()

    private init() {}

    func apply(
        _ surfaceSelection: String,
        settingsVisible: Bool
    ) {
        let showsMenuBar =
            surfaceSelection == "sbar" || surfaceSelection == "both"

        StatusBarController.shared.setMenuBarVisible(showsMenuBar)
        syncActivation(
            surfaceSelection: surfaceSelection,
            settingsVisible: settingsVisible
        )
    }

    func syncActivation(
        surfaceSelection: String,
        settingsVisible: Bool
    ) {
        let policy: NSApplication.ActivationPolicy
        if settingsVisible {
            policy = .regular
        } else {
            policy =
                surfaceSelection == "dock" || surfaceSelection == "both"
                    ? .regular
                    : .accessory
        }

        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }
}


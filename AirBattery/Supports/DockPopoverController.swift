import AppKit
import SwiftUI

@MainActor
final class DockPopoverController {
    static let shared = DockPopoverController()

    private var window: AutoHideWindow?

    private init() {}

    var isVisible: Bool {
        window?.isVisible == true
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if isVisible {
            hide()
            return
        }
        show()
    }

    private func show() {
        var allDevices = AirBatteryModel.getAll()
        let internalBattery = InternalBattery.status
        if internalBattery.hasBattery {
            allDevices.insert(ib2ab(internalBattery), at: 0)
        }

        let rootView = popover(fromDock: true, allDevice: allDevices)
        let contentView = ContentFittingHostingView(
            width: 352,
            rootView: rootView
        )
        contentView.layoutSubtreeIfNeeded()
        contentView.resizeToFitContent()
        let menuHeight = contentView.frame.height
        let anchorMouse = NSEvent.mouseLocation

        let origin = popupOrigin(
            size: NSSize(width: 352, height: menuHeight),
            mouse: anchorMouse
        )
        contentView.frame = NSRect(
            x: 0,
            y: 0,
            width: 352,
            height: menuHeight
        )

        let popup = AutoHideWindow(
            contentRect: NSRect(
                x: origin.x,
                y: origin.y,
                width: 352,
                height: menuHeight
            ),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        popup.title = "AirBattery Dock Window"
        popup.level = .popUpMenu
        popup.contentView = contentView
        popup.isOpaque = false
        popup.backgroundColor = .clear
        popup.contentView?.wantsLayer = true
        popup.contentView?.layer?.cornerRadius = 7
        popup.contentView?.layer?.masksToBounds = true
        contentView.onHeightChange = { [weak self, weak popup] height in
            guard let self, let popup else { return }
            let size = NSSize(width: 352, height: height)
            let origin = self.popupOrigin(
                size: size,
                mouse: anchorMouse
            )
            popup.setFrame(
                NSRect(origin: origin, size: size),
                display: true
            )
        }
        popup.makeKeyAndOrderFront(nil)
        window = popup
    }

    private func popupOrigin(
        size: NSSize,
        mouse: NSPoint
    ) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouse, $0.frame, false)
        }) else {
            return mouse
        }

        let visibleFrame = screen.visibleFrame
        let orientation =
            UserDefaults(suiteName: "com.apple.dock")?
                .string(forKey: "orientation") ?? "bottom"

        var x = mouse.x
        var y = mouse.y

        switch orientation {
        case "bottom":
            if x + 186 > visibleFrame.maxX {
                x = visibleFrame.maxX - 362
            } else if x - 166 < visibleFrame.minX {
                x = visibleFrame.minX + 10
            } else {
                x -= 176
            }
            y = max(y, visibleFrame.minY) + 20

        case "right":
            x =
                x + size.width > visibleFrame.maxX
                    ? visibleFrame.maxX - size.width - 20
                    : x + 10
            y = max(y - size.height / 2, visibleFrame.minY)

        case "left":
            x =
                x + size.width > visibleFrame.maxX
                    ? visibleFrame.maxX - size.width - 20
                    : x
            x = x < visibleFrame.minX ? visibleFrame.minX + 20 : x + 10
            y = max(y - size.height / 2, visibleFrame.minY)

        default:
            break
        }

        return NSPoint(x: x, y: y)
    }
}

final class AutoHideWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }
}

//
//  WindowAccessor.swift
//  xHistory
//
//  Created by apple on 2024/11/7.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AirBattery Settings"
        window.contentViewController = hostingController
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.titlebarSeparatorStyle = .automatic
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("AirBatterySettingsWindow")

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }

        // Reassert these constraints when reopening in case SwiftUI/AppKit
        // changed them while the content hierarchy was being constructed.
        window.styleMask.insert(.resizable)
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.standardWindowButton(.zoomButton)?.isEnabled = true

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async {
            guard let splitView = findNSSplitVIew(view: window.contentView),
                  let controller = splitView.delegate as? NSSplitViewController
            else {
                return
            }
            controller.splitViewItems.first?.canCollapse = false
            controller.splitViewItems.first?.minimumThickness = 190
            controller.splitViewItems.first?.maximumThickness = 190
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onWindowOpen: ((NSWindow?) -> Void)?
    var onWindowActive: ((NSWindow?) -> Void)?
    var onWindowDeactivate: ((NSWindow?) -> Void)?
    var onWindowClose: (() -> Void)?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = context.coordinator
                context.coordinator.window = window
                self.onWindowOpen?(window)
            } else {
                self.onWindowOpen?(nil)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onWindowOpen: onWindowOpen,
            onWindowActive: onWindowActive,
            onWindowDeactivate: onWindowDeactivate,
            onWindowClose: onWindowClose
        )
    }

    class Coordinator: NSObject, NSWindowDelegate {
        weak var window: NSWindow? // 使用 weak 避免循环引用
        var onWindowOpen: ((NSWindow?) -> Void)?
        var onWindowActive: ((NSWindow?) -> Void)?
        var onWindowDeactivate: ((NSWindow?) -> Void)?
        var onWindowClose: (() -> Void)?

        init(onWindowOpen: ((NSWindow?) -> Void)? = nil,
             onWindowActive: ((NSWindow?) -> Void)? = nil,
             onWindowDeactivate: ((NSWindow?) -> Void)? = nil,
             onWindowClose: (() -> Void)? = nil) {
            self.onWindowOpen = onWindowOpen
            self.onWindowClose = onWindowClose
            self.onWindowActive = onWindowActive
            self.onWindowDeactivate = onWindowDeactivate
        }

        func windowWillClose(_ notification: Notification) {
            onWindowClose?()
        }
        
        func windowDidBecomeKey(_ notification: Notification) {
            onWindowActive?(window)
        }

        func windowDidResignKey(_ notification: Notification) {
            onWindowDeactivate?(window)
        }
    }
}

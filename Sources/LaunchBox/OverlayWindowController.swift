import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var window: LauncherOverlayWindow?
    private let store: LaunchStore

    init(store: LaunchStore) {
        self.store = store
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        let window = LauncherOverlayWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.onEscape = { [weak self, weak window] in
            guard let self else {
                return
            }

            if store.query.isEmpty {
                hide(window)
            } else {
                store.query = ""
            }
        }
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.hidesOnDeactivate = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = NSHostingView(
            rootView: LauncherOverlayView(store: store) { [weak self, weak window] in
                self?.hide(window)
            }
        )

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
    }

    func hide(_ targetWindow: NSWindow? = nil) {
        let targetWindow = targetWindow ?? window
        targetWindow?.orderOut(nil)
        if targetWindow === window {
            window = nil
        }
        store.query = ""
    }
}

private final class LauncherOverlayWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, KeyboardCommandRouter.shared.handle(event) {
            return
        }

        if event.type == .keyDown, event.keyCode == 53 {
            onEscape?()
            return
        }

        super.sendEvent(event)
    }
}

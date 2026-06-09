import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var window: LauncherOverlayWindow?
    private let store: LaunchStore
    private let transitionDuration: TimeInterval = 0.24
    private let hiddenContentScale: CGFloat = 0.985
    private let visibleContentScale: CGFloat = 1
    private var transitionGeneration = 0

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
            transitionGeneration += 1
            NSApp.activate(ignoringOtherApps: true)
            window.setFrame(currentScreenFrame, display: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
            fadeIn(window)
            return
        }

        let window = LauncherOverlayWindow(
            contentRect: currentScreenFrame,
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
        window.alphaValue = 0
        window.contentView = NSHostingView(
            rootView: LauncherOverlayView(store: store) { [weak self, weak window] in
                self?.hide(window)
            }
        )
        prepareContentLayer(for: window)
        setContentScale(hiddenContentScale, for: window, animated: false)

        self.window = window
        transitionGeneration += 1
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
        fadeIn(window)
    }

    func hide(_ targetWindow: NSWindow? = nil) {
        guard let targetWindow = targetWindow ?? window else {
            store.query = ""
            return
        }

        store.query = ""
        transitionGeneration += 1
        fadeOut(targetWindow, generation: transitionGeneration)
    }

    private func fadeIn(_ targetWindow: NSWindow) {
        prepareContentLayer(for: targetWindow)
        animateContentScale(visibleContentScale, for: targetWindow)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = transitionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            targetWindow.animator().alphaValue = 1
        }
    }

    private func fadeOut(_ targetWindow: NSWindow, generation: Int) {
        prepareContentLayer(for: targetWindow)
        animateContentScale(hiddenContentScale, for: targetWindow)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = transitionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            targetWindow.animator().alphaValue = 0
        } completionHandler: { [weak self, weak targetWindow] in
            Task { @MainActor in
                guard let targetWindow else {
                    return
                }

                guard let self,
                      self.transitionGeneration == generation,
                      let currentWindow = self.window,
                      currentWindow === targetWindow else {
                    return
                }

                targetWindow.orderOut(nil)
                targetWindow.alphaValue = 1
                self.setContentScale(self.visibleContentScale, for: targetWindow, animated: false)
            }
        }
    }

    private var currentScreenFrame: NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        return screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    }

    private func prepareContentLayer(for targetWindow: NSWindow) {
        targetWindow.contentView?.wantsLayer = true
    }

    private func animateContentScale(_ scale: CGFloat, for targetWindow: NSWindow) {
        setContentScale(scale, for: targetWindow, animated: true)
    }

    private func setContentScale(_ scale: CGFloat, for targetWindow: NSWindow, animated: Bool) {
        guard let layer = targetWindow.contentView?.layer else {
            return
        }

        let transform = CATransform3DMakeScale(scale, scale, 1)
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(transitionDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            layer.transform = transform
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.transform = transform
            CATransaction.commit()
        }
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

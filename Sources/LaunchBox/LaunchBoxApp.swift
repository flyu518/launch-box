import AppKit
import SwiftUI

@main
struct LaunchBoxApp: App {
    @NSApplicationDelegateAdaptor(AppCoordinator.self) private var coordinator

    var body: some Scene {
        Settings {
            PreferencesView(store: coordinator.store) {
                coordinator.reloadHotKey()
            }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于启动台") {
                    coordinator.showAbout()
                }

                Button("检查更新...") {
                    coordinator.showAbout(checkUpdates: true)
                }
            }
        }
    }
}

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    let store = LaunchStore()
    private lazy var overlay = OverlayWindowController(store: store)
    private lazy var hotKey = HotKeyManager { [weak self] in
        self?.toggleOverlay()
    }
    private var statusBarController: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var aboutWindowController: AboutWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppIconFactory.dockIcon()
        store.load()
        store.rescan()
        statusBarController = StatusBarController(
            onPrimaryClick: { [weak self] in
                self?.showOverlay()
            },
            onRescan: { [weak self] in
                self?.store.rescan()
            },
            onAbout: { [weak self] in
                self?.showAbout()
            },
            onCheckUpdates: { [weak self] in
                self?.showAbout(checkUpdates: true)
            },
            onSettings: { [weak self] in
                self?.showSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        reloadHotKey()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showOverlay()
        return false
    }

    func showOverlay() {
        overlay.show()
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: store) { [weak self] in
                self?.reloadHotKey()
            }
        }

        settingsWindowController?.show()
    }

    func showAbout(checkUpdates: Bool = false) {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }

        aboutWindowController?.show(checkUpdates: checkUpdates)
    }

    func toggleOverlay() {
        overlay.toggle()
    }

    func reloadHotKey() {
        hotKey.register(settings: store.library.hotKey)
    }
}

@MainActor
private final class AboutWindowController {
    private let updateCheck = UpdateCheckModel()
    private let window: NSWindow

    init() {
        let hostingController = NSHostingController(
            rootView: AboutView(updateCheck: updateCheck)
        )

        window = NSWindow(contentViewController: hostingController)
        window.title = "关于启动台"
        window.styleMask = [.titled, .closable]
        window.minSize = NSSize(width: 420, height: 340)
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show(checkUpdates: Bool = false) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        if checkUpdates {
            Task {
                await updateCheck.check()
            }
        }
    }
}

@MainActor
private final class SettingsWindowController {
    private let window: NSWindow

    init(store: LaunchStore, onHotKeyChange: @escaping () -> Void) {
        let hostingController = NSHostingController(
            rootView: PreferencesView(store: store, onHotKeyChange: onHotKeyChange)
        )

        window = NSWindow(contentViewController: hostingController)
        window.title = "启动台设置"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 520, height: 260)
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onPrimaryClick: () -> Void
    private let onRescan: () -> Void
    private let onAbout: () -> Void
    private let onCheckUpdates: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void

    init(
        onPrimaryClick: @escaping () -> Void,
        onRescan: @escaping () -> Void,
        onAbout: @escaping () -> Void,
        onCheckUpdates: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.onPrimaryClick = onPrimaryClick
        self.onRescan = onRescan
        self.onAbout = onAbout
        self.onCheckUpdates = onCheckUpdates
        self.onSettings = onSettings
        self.onQuit = onQuit
        super.init()

        if let button = statusItem.button {
            button.image = AppIconFactory.menuBarIcon()
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            onPrimaryClick()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "打开启动台", action: #selector(openLauncher), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重新扫描应用", action: #selector(rescanApps), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "关于启动台", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "检查更新...", action: #selector(checkUpdates), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openLauncher() {
        onPrimaryClick()
    }

    @objc private func rescanApps() {
        onRescan()
    }

    @objc private func openAbout() {
        onAbout()
    }

    @objc private func checkUpdates() {
        onCheckUpdates()
    }

    @objc private func openSettings() {
        onSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}

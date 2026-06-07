import AppKit
import LaunchBoxCore

enum AppLauncher {
    @discardableResult
    static func open(_ app: LaunchApp) -> Bool {
        guard FileManager.default.fileExists(atPath: app.path) else {
            return false
        }

        return NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
    }

    @discardableResult
    static func revealInFinder(_ app: LaunchApp) -> Bool {
        guard FileManager.default.fileExists(atPath: app.path) else {
            return false
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
        return true
    }
}

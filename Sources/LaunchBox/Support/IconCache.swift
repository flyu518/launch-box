import AppKit
import LaunchBoxCore

@MainActor
final class IconCache: ObservableObject {
    private var icons: [String: NSImage] = [:]

    func icon(for app: LaunchApp) -> NSImage {
        if let icon = icons[app.id] {
            return icon
        }

        let icon = NSWorkspace.shared.icon(forFile: app.path)
        icon.size = NSSize(width: 96, height: 96)
        icons[app.id] = icon
        return icon
    }
}

import Foundation
import ServiceManagement

enum LoginItemManager {
    private static let legacyLabel = "dev.local.launch-box.login"

    private static var legacyLaunchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(legacyLabel).plist", isDirectory: false)
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }

        removeLegacyLaunchAgentIfNeeded()
    }

    private static func removeLegacyLaunchAgentIfNeeded() {
        guard FileManager.default.fileExists(atPath: legacyLaunchAgentURL.path) else {
            return
        }

        try? FileManager.default.removeItem(at: legacyLaunchAgentURL)
    }
}

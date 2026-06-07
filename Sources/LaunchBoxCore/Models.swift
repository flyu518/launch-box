import Foundation

public struct LaunchApp: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let name: String
    public let bundleIdentifier: String?
    public let path: String
    public let alternateNames: [String]

    public var id: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier)"
        }
        return "path:\(path)"
    }

    public init(name: String, bundleIdentifier: String?, path: String, alternateNames: [String] = []) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.alternateNames = alternateNames
    }
}

public enum LaunchItemID: Codable, Equatable, Hashable, Sendable {
    case app(String)
    case folder(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    private enum ItemType: String, Codable {
        case app
        case folder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        let id = try container.decode(String.self, forKey: .id)

        switch type {
        case .app:
            self = .app(id)
        case .folder:
            self = .folder(id)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .app(let id):
            try container.encode(ItemType.app, forKey: .type)
            try container.encode(id, forKey: .id)
        case .folder(let id):
            try container.encode(ItemType.folder, forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}

public struct LaunchCategory: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var itemIDs: [LaunchItemID]

    public init(id: String = UUID().uuidString, name: String, itemIDs: [LaunchItemID] = []) {
        self.id = id
        self.name = name
        self.itemIDs = itemIDs
    }
}

public struct LaunchFolder: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var appIDs: [String]

    public init(id: String = UUID().uuidString, name: String, appIDs: [String] = []) {
        self.id = id
        self.name = name
        self.appIDs = appIDs
    }
}

public struct RecentApp: Codable, Equatable, Sendable {
    public var appID: String
    public var openedAt: Date

    public init(appID: String, openedAt: Date = Date()) {
        self.appID = appID
        self.openedAt = openedAt
    }
}

public struct HotKeySettings: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var isEnabled: Bool

    public init(keyCode: UInt32 = 49, modifiers: UInt32 = 2_048, isEnabled: Bool = true) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }
}

public struct LaunchLibrary: Codable, Equatable, Sendable {
    public var appOrder: [String]
    public var favoriteAppIDs: [String]
    public var recents: [RecentApp]
    public var categories: [LaunchCategory]
    public var folders: [LaunchFolder]
    public var hiddenAppIDs: Set<String>
    public var hotKey: HotKeySettings

    public init(
        appOrder: [String] = [],
        favoriteAppIDs: [String] = [],
        recents: [RecentApp] = [],
        categories: [LaunchCategory] = [],
        folders: [LaunchFolder] = [],
        hiddenAppIDs: Set<String> = [],
        hotKey: HotKeySettings = HotKeySettings()
    ) {
        self.appOrder = appOrder
        self.favoriteAppIDs = favoriteAppIDs
        self.recents = recents
        self.categories = categories
        self.folders = folders
        self.hiddenAppIDs = hiddenAppIDs
        self.hotKey = hotKey
    }
}

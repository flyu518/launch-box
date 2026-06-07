import Foundation

public struct LaunchDragID: Equatable, Hashable, RawRepresentable, Sendable {
    public let itemID: LaunchItemID

    public var rawValue: String {
        switch itemID {
        case .app(let id):
            return "\(Self.appPrefix)\(id)"
        case .folder(let id):
            return "\(Self.folderPrefix)\(id)"
        }
    }

    public var appID: String? {
        guard case .app(let id) = itemID else {
            return nil
        }
        return id
    }

    public var folderID: String? {
        guard case .folder(let id) = itemID else {
            return nil
        }
        return id
    }

    public var isApp: Bool {
        appID != nil
    }

    public var isFolder: Bool {
        folderID != nil
    }

    public init(itemID: LaunchItemID) {
        self.itemID = itemID
    }

    public init?(rawValue: String) {
        if rawValue.hasPrefix(Self.appPrefix) {
            itemID = .app(String(rawValue.dropFirst(Self.appPrefix.count)))
        } else if rawValue.hasPrefix(Self.folderPrefix) {
            itemID = .folder(String(rawValue.dropFirst(Self.folderPrefix.count)))
        } else {
            return nil
        }
    }

    private static let appPrefix = "app|"
    private static let folderPrefix = "folder|"
}

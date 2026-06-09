import AppKit
import Foundation
import LaunchBoxCore

enum LauncherSection: Hashable {
    case all
    case favorites
    case recent
    case uncategorized
    case category(String)
    case hidden

    var title: String {
        switch self {
        case .all: "全部"
        case .favorites: "收藏"
        case .recent: "最近"
        case .uncategorized: "未分类"
        case .category: "分类"
        case .hidden: "隐藏"
        }
    }
}

enum SectionNavigationDirection {
    case previous
    case next
}

struct GridEntry: Identifiable, Equatable {
    var id: String
    var title: String
    var app: LaunchApp?
    var folder: LaunchFolder?
    var folderApps: [LaunchApp]

    var isFolder: Bool {
        folder != nil
    }
}

@MainActor
final class LaunchStore: ObservableObject {
    @Published var apps: [LaunchApp] = []
    @Published var library = LaunchLibrary()
    @Published var activeSection: LauncherSection = .all
    @Published var query = ""
    @Published var warning: String?
    @Published var isSidebarCollapsed = true

    private let scanner = AppScanner()
    private let persistence: LibraryPersistence

    init(persistence: LibraryPersistence = .applicationSupportDefault) {
        self.persistence = persistence
    }

    var sortedCategories: [LaunchCategory] {
        library.categories
    }

    var orderedSections: [LauncherSection] {
        [.all, .favorites, .recent, .uncategorized] + sortedCategories.map { .category($0.id) } + [.hidden]
    }

    var appsByID: [String: LaunchApp] {
        Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
    }

    var visibleApps: [LaunchApp] {
        apps.filter { !library.hiddenAppIDs.contains($0.id) }
    }

    var hiddenApps: [LaunchApp] {
        orderApps(
            apps.filter { library.hiddenAppIDs.contains($0.id) },
            using: library.appOrder
        )
    }

    var activeEntries: [GridEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return AppSearch
                .filter(appsForActiveSection(includeFolders: false), query: trimmed)
                .map(appEntry)
        }

        switch activeSection {
        case .category(let categoryID):
            return entriesForCategory(categoryID)
        case .hidden:
            return hiddenApps.map(appEntry)
        default:
            return appsForActiveSection(includeFolders: false).map(appEntry)
        }
    }

    func load() {
        do {
            library = try persistence.load()
        } catch {
            warning = "读取配置失败，已使用空配置。"
            library = LaunchLibrary()
        }
    }

    func save() {
        do {
            try persistence.save(library)
        } catch {
            warning = "保存配置失败：\(error.localizedDescription)"
        }
    }

    func exportLibrary(to destinationURL: URL) throws {
        try persistence.export(library, to: destinationURL)
    }

    func importLibrary(from sourceURL: URL) throws -> URL? {
        let imported = try persistence.importLibrary(from: sourceURL)
        let backupURL = try persistence.backupCurrentFile(label: "before-import")

        library = imported
        activeSection = .all
        query = ""
        warning = nil
        try persistence.save(library)
        return backupURL
    }

    func rescan() {
        apps = scanner.scan()
        ensureGlobalAppOrderContainsVisibleApps()
    }

    func rescanAsync() async -> Int {
        let scanner = scanner
        let scannedApps = await Task.detached(priority: .userInitiated) {
            scanner.scan()
        }.value

        apps = scannedApps
        ensureGlobalAppOrderContainsVisibleApps()
        return scannedApps.count
    }

    @discardableResult
    func open(_ app: LaunchApp) -> Bool {
        if AppLauncher.open(app) {
            library.recordLaunch(appID: app.id)
            save()
            return true
        }

        warning = "无法打开“\(app.name)”。"
        return false
    }

    func createCategory(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let category = library.createCategory(named: trimmed)
        activeSection = .category(category.id)
        save()
    }

    func renameCategory(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        library.renameCategory(id: id, to: trimmed)
        save()
    }

    func deleteCategory(id: String) {
        library.deleteCategory(id: id)
        if activeSection == .category(id) {
            activeSection = .all
        }
        save()
    }

    func moveCategory(id: String, before targetID: String?) {
        guard id != targetID else {
            return
        }

        library.moveCategory(id: id, before: targetID)
        save()
    }

    func moveActiveSection(_ direction: SectionNavigationDirection) {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let sections = orderedSections
        guard sections.count > 1,
              let currentIndex = sections.firstIndex(of: activeSection) else {
            activeSection = .all
            return
        }

        let offset: Int
        switch direction {
        case .previous:
            offset = -1
        case .next:
            offset = 1
        }

        let targetIndex = (currentIndex + offset + sections.count) % sections.count
        activeSection = sections[targetIndex]
    }

    func toggleFavorite(appID: String) {
        library.toggleFavorite(appID: appID)
        save()
    }

    func hideApp(_ appID: String) {
        library.hiddenAppIDs.insert(appID)
        save()
    }

    func unhideApp(_ appID: String) {
        library.hiddenAppIDs.remove(appID)
        save()
    }

    func resetLayout() {
        library.appOrder = visibleApps.map(\.id)
        library.favoriteAppIDs = []
        library.recents = []
        library.categories = []
        library.folders = []
        activeSection = .all
        query = ""
        save()
    }

    func addApp(_ appID: String, toCategory categoryID: String) {
        library.addApp(appID, toCategory: categoryID)
        save()
    }

    func app(_ appID: String, isInCategory categoryID: String) -> Bool {
        guard let category = library.category(withID: categoryID) else {
            return false
        }
        return categoryContainsApp(category, appID: appID)
    }

    @discardableResult
    func toggleApp(_ appID: String, inCategory categoryID: String) -> Bool {
        if app(appID, isInCategory: categoryID) {
            library.removeAppCompletely(appID, fromCategory: categoryID)
            save()
            return false
        }

        library.addApp(appID, toCategory: categoryID)
        save()
        return true
    }

    func addDraggedApp(_ dragID: String, toCategory categoryID: String) -> String? {
        guard let appID = LaunchDragID(rawValue: dragID)?.appID else {
            return nil
        }

        addApp(appID, toCategory: categoryID)
        return appsByID[appID]?.name
    }

    func favoriteDraggedApp(_ dragID: String) -> String? {
        guard let appID = LaunchDragID(rawValue: dragID)?.appID else {
            return nil
        }

        if !isFavorite(appID) {
            library.toggleFavorite(appID: appID)
            save()
        }

        return appsByID[appID]?.name
    }

    func hideDraggedApp(_ dragID: String) -> String? {
        guard let appID = LaunchDragID(rawValue: dragID)?.appID else {
            return nil
        }

        library.hiddenAppIDs.insert(appID)
        save()
        return appsByID[appID]?.name
    }

    func createCategory(named name: String, containing appID: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let category = library.createCategory(named: trimmed)
        library.addApp(appID, toCategory: category.id)
        save()
    }

    func createFolder(named name: String, appIDs: [String], inCategory categoryID: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        library.createFolder(named: trimmed, inCategory: categoryID, appIDs: appIDs)
        save()
    }

    func renameFolder(id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        library.renameFolder(id: id, to: trimmed)
        save()
    }

    func createFolderFromDrag(_ dragID: String, onto targetID: String) -> GridEntry? {
        guard case .category(let categoryID) = activeSection,
              let draggedAppID = LaunchDragID(rawValue: dragID)?.appID,
              let targetAppID = LaunchDragID(rawValue: targetID)?.appID,
              draggedAppID != targetAppID else {
            return nil
        }

        let folder = library.createFolder(
            named: "新文件夹",
            inCategory: categoryID,
            appIDs: [targetAppID, draggedAppID]
        )
        save()
        return folderEntry(id: folder.id)
    }

    func addDraggedApp(_ dragID: String, toFolder targetID: String) -> GridEntry? {
        guard case .category(let categoryID) = activeSection,
              let appID = LaunchDragID(rawValue: dragID)?.appID,
              let folderID = LaunchDragID(rawValue: targetID)?.folderID else {
            return nil
        }

        library.addApp(appID, toFolder: folderID, inCategory: categoryID)
        save()
        return folderEntry(id: folderID)
    }

    func moveAppOutOfFolder(appID: String, folderID: String) -> Bool {
        guard case .category(let categoryID) = activeSection else {
            return false
        }

        library.removeApp(appID, fromFolder: folderID, inCategory: categoryID)
        save()
        return library.folder(withID: folderID) != nil
    }

    func moveEntry(dragID: String, before targetID: String?) {
        guard let item = LaunchDragID(rawValue: dragID)?.itemID else {
            return
        }

        switch activeSection {
        case .all, .uncategorized, .hidden:
            guard case .app(let appID) = item else {
                return
            }
            let targetAppID = targetID.flatMap { LaunchDragID(rawValue: $0)?.appID }
            library.moveAppInGlobalOrder(appID, before: targetAppID)
        case .favorites:
            guard case .app(let appID) = item else {
                return
            }
            let targetAppID = targetID.flatMap { LaunchDragID(rawValue: $0)?.appID }
            library.moveFavorite(appID, before: targetAppID)
        case .category(let categoryID):
            library.moveItem(
                item,
                before: targetID.flatMap { LaunchDragID(rawValue: $0)?.itemID },
                inCategory: categoryID
            )
        case .recent:
            return
        }

        save()
    }

    func removeEntry(_ entry: GridEntry) {
        guard case .category(let categoryID) = activeSection else {
            return
        }

        if let app = entry.app {
            library.removeApp(app.id, fromCategory: categoryID)
        } else if let folder = entry.folder {
            library.removeItem(.folder(folder.id), fromCategory: categoryID)
        }

        save()
    }

    func isFavorite(_ appID: String) -> Bool {
        library.favoriteAppIDs.contains(appID)
    }

    func categoryNames(for appID: String) -> [String] {
        library.categories.compactMap { category in
            if categoryContainsApp(category, appID: appID) {
                return category.name
            }
            return nil
        }
    }

    func statusBadges(for app: LaunchApp) -> [String] {
        var badges: [String] = []
        if isFavorite(app.id) {
            badges.append("收藏")
        }

        badges.append(contentsOf: categoryNames(for: app.id))

        return badges
    }

    func categoryName(id: String) -> String {
        library.category(withID: id)?.name ?? "分类"
    }

    func folderEntry(id folderID: String) -> GridEntry? {
        guard let folder = library.folder(withID: folderID) else {
            return nil
        }

        let appsByID = appsByID
        let folderApps = folder.appIDs
            .compactMap { appsByID[$0] }
            .filter { !library.hiddenAppIDs.contains($0.id) }
        return GridEntry(
            id: LaunchDragID(itemID: .folder(folder.id)).rawValue,
            title: folder.name,
            app: nil,
            folder: folder,
            folderApps: folderApps
        )
    }

    private func entriesForCategory(_ categoryID: String) -> [GridEntry] {
        guard let category = library.category(withID: categoryID) else {
            return []
        }

        let appsByID = appsByID
        return category.itemIDs.compactMap { itemID in
            switch itemID {
            case .app(let appID):
                guard !library.hiddenAppIDs.contains(appID) else {
                    return nil
                }
                return appsByID[appID].map(appEntry)
            case .folder(let folderID):
                return folderEntry(id: folderID)
            }
        }
    }

    private func appsForActiveSection(includeFolders: Bool) -> [LaunchApp] {
        let appsByID = appsByID
        let visibleApps = apps.filter { !library.hiddenAppIDs.contains($0.id) }

        switch activeSection {
        case .all:
            return orderApps(visibleApps, using: library.appOrder)
        case .favorites:
            return library.favoriteAppIDs.compactMap { appID in
                guard !library.hiddenAppIDs.contains(appID) else {
                    return nil
                }
                return appsByID[appID]
            }
        case .recent:
            return library.recents.compactMap { recent in
                guard !library.hiddenAppIDs.contains(recent.appID) else {
                    return nil
                }
                return appsByID[recent.appID]
            }
        case .uncategorized:
            let assigned = assignedAppIDs()
            return orderApps(visibleApps.filter { !assigned.contains($0.id) }, using: library.appOrder)
        case .hidden:
            return hiddenApps
        case .category(let categoryID):
            guard includeFolders else {
                return entriesForCategory(categoryID).flatMap { entry in
                    if let app = entry.app {
                        return [app]
                    }
                    return entry.folderApps
                }
            }
            return []
        }
    }

    private func assignedAppIDs() -> Set<String> {
        var ids = Set<String>()

        for category in library.categories {
            for itemID in category.itemIDs {
                if case .app(let appID) = itemID {
                    ids.insert(appID)
                }
            }
        }

        for folder in library.folders {
            ids.formUnion(folder.appIDs)
        }

        return ids
    }

    private func categoryContainsApp(_ category: LaunchCategory, appID: String) -> Bool {
        for itemID in category.itemIDs {
            switch itemID {
            case .app(let candidate) where candidate == appID:
                return true
            case .folder(let folderID):
                if library.folder(withID: folderID)?.appIDs.contains(appID) == true {
                    return true
                }
            default:
                continue
            }
        }

        return false
    }

    private func appEntry(_ app: LaunchApp) -> GridEntry {
        GridEntry(
            id: LaunchDragID(itemID: .app(app.id)).rawValue,
            title: app.name,
            app: app,
            folder: nil,
            folderApps: []
        )
    }

    private func ensureGlobalAppOrderContainsVisibleApps() {
        var order = library.appOrder.filter { appID in
            apps.contains { $0.id == appID }
        }
        let knownIDs = Set(order)
        let missingIDs = apps
            .filter { !library.hiddenAppIDs.contains($0.id) && !knownIDs.contains($0.id) }
            .map(\.id)

        order.append(contentsOf: missingIDs)
        guard order != library.appOrder else {
            return
        }

        library.appOrder = order
        save()
    }

    private func orderApps(_ apps: [LaunchApp], using order: [String]) -> [LaunchApp] {
        let orderIndex = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
        return apps.sorted { lhs, rhs in
            let lhsIndex = orderIndex[lhs.id] ?? Int.max
            let rhsIndex = orderIndex[rhs.id] ?? Int.max
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

}

private extension LibraryPersistence {
    static var applicationSupportDefault: LibraryPersistence {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("launch-box", isDirectory: true)

        let legacyDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("launch_box", isDirectory: true)

        migrateLegacyApplicationSupportIfNeeded(from: legacyDirectory, to: baseDirectory)

        return LibraryPersistence(baseDirectory: baseDirectory)
    }

    static func migrateLegacyApplicationSupportIfNeeded(from legacyDirectory: URL, to baseDirectory: URL) {
        let fileManager = FileManager.default
        let fileName = "LaunchLibrary.json"
        let legacyFile = legacyDirectory.appendingPathComponent(fileName, isDirectory: false)
        let currentFile = baseDirectory.appendingPathComponent(fileName, isDirectory: false)

        guard fileManager.fileExists(atPath: legacyFile.path),
              !fileManager.fileExists(atPath: currentFile.path) else {
            return
        }

        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
            try fileManager.copyItem(at: legacyFile, to: currentFile)
        } catch {
            // Loading will fall back to an empty library and surface the normal warning.
        }
    }
}

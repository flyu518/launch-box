import Foundation

public extension LaunchLibrary {
    func category(withID id: String) -> LaunchCategory? {
        categories.first { $0.id == id }
    }

    func folder(withID id: String) -> LaunchFolder? {
        folders.first { $0.id == id }
    }

    @discardableResult
    mutating func createCategory(named name: String) -> LaunchCategory {
        let category = LaunchCategory(name: name)
        categories.append(category)
        return category
    }

    mutating func renameCategory(id: String, to name: String) {
        guard let index = categories.firstIndex(where: { $0.id == id }) else {
            return
        }
        categories[index].name = name
    }

    mutating func deleteCategory(id: String) {
        let folderIDs = category(withID: id)?.folderIDs ?? []
        categories.removeAll { $0.id == id }
        cleanupFoldersIfUnreferenced(ids: folderIDs)
    }

    @discardableResult
    mutating func createFolder(named name: String, appIDs: [String] = []) -> LaunchFolder {
        let uniqueAppIDs = appIDs.uniqued()
        let folder = LaunchFolder(name: name, appIDs: uniqueAppIDs)
        folders.append(folder)
        return folder
    }

    @discardableResult
    mutating func createFolder(named name: String, inCategory categoryID: String, appIDs: [String]) -> LaunchFolder {
        let folder = createFolder(named: name, appIDs: appIDs)
        for appID in folder.appIDs {
            removeAppFromCategorySurface(appID, categoryID: categoryID)
            removeAppFromFolders(appID, inCategory: categoryID, exceptFolderID: folder.id)
        }
        addFolder(folder.id, toCategory: categoryID)
        return folder
    }

    mutating func renameFolder(id: String, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            return
        }
        folders[index].name = name
    }

    mutating func addApp(_ appID: String, toCategory categoryID: String) {
        removeAppFromFolders(appID, inCategory: categoryID, exceptFolderID: nil)
        addItem(.app(appID), toCategory: categoryID)
    }

    mutating func addFolder(_ folderID: String, toCategory categoryID: String) {
        addItem(.folder(folderID), toCategory: categoryID)
    }

    mutating func addApp(_ appID: String, toFolder folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else {
            return
        }
        guard !folders[index].appIDs.contains(appID) else {
            return
        }
        folders[index].appIDs.append(appID)
    }

    mutating func addApp(_ appID: String, toFolder folderID: String, inCategory categoryID: String) {
        guard category(withID: categoryID)?.itemIDs.contains(.folder(folderID)) == true else {
            return
        }

        removeAppFromCategorySurface(appID, categoryID: categoryID)
        removeAppFromFolders(appID, inCategory: categoryID, exceptFolderID: folderID)
        addApp(appID, toFolder: folderID)
    }

    mutating func removeApp(_ appID: String, fromCategory categoryID: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }
        categories[index].itemIDs.removeAll { $0 == .app(appID) }
    }

    mutating func removeAppCompletely(_ appID: String, fromCategory categoryID: String) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }

        var itemIDs = categories[categoryIndex].itemIDs.filter { $0 != .app(appID) }

        for itemID in categories[categoryIndex].itemIDs {
            guard case .folder(let folderID) = itemID,
                  let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else {
                continue
            }

            folders[folderIndex].appIDs.removeAll { $0 == appID }
            let remainingAppIDs = folders[folderIndex].appIDs

            if remainingAppIDs.isEmpty {
                itemIDs.removeAll { $0 == .folder(folderID) }
                cleanupFolder(id: folderID)
            } else if remainingAppIDs.count == 1 {
                if let folderItemIndex = itemIDs.firstIndex(of: .folder(folderID)) {
                    itemIDs[folderItemIndex] = .app(remainingAppIDs[0])
                }
                cleanupFolder(id: folderID)
            }
        }

        categories[categoryIndex].itemIDs = itemIDs.uniqued()
    }

    mutating func removeItem(_ itemID: LaunchItemID, fromCategory categoryID: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }
        categories[index].itemIDs.removeAll { $0 == itemID }

        if case .folder(let folderID) = itemID {
            cleanupFoldersIfUnreferenced(ids: [folderID])
        }
    }

    mutating func removeApp(_ appID: String, fromFolder folderID: String, inCategory categoryID: String) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }),
              let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }

        folders[folderIndex].appIDs.removeAll { $0 == appID }
        let remainingAppIDs = folders[folderIndex].appIDs

        guard let folderItemIndex = categories[categoryIndex].itemIDs.firstIndex(of: .folder(folderID)) else {
            addItem(.app(appID), toCategory: categoryID)
            cleanupFolder(id: folderID)
            return
        }

        if remainingAppIDs.count <= 1 {
            var replacementItems = categories[categoryIndex].itemIDs
            replacementItems.remove(at: folderItemIndex)
            if let remainingAppID = remainingAppIDs.first {
                replacementItems.insert(.app(remainingAppID), at: folderItemIndex)
            }
            replacementItems.insert(.app(appID), at: min(folderItemIndex + 1, replacementItems.count))
            categories[categoryIndex].itemIDs = replacementItems.uniqued()
            cleanupFolder(id: folderID)
            return
        }

        categories[categoryIndex].itemIDs.insert(.app(appID), at: folderItemIndex + 1)
        categories[categoryIndex].itemIDs = categories[categoryIndex].itemIDs.uniqued()
    }

    mutating func moveItem(_ itemID: LaunchItemID, before targetID: LaunchItemID?, inCategory categoryID: String) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }

        var itemIDs = categories[categoryIndex].itemIDs.filter { $0 != itemID }
        if let targetID, let targetIndex = itemIDs.firstIndex(of: targetID) {
            itemIDs.insert(itemID, at: targetIndex)
        } else {
            itemIDs.append(itemID)
        }

        categories[categoryIndex].itemIDs = itemIDs
    }

    mutating func moveAppInGlobalOrder(_ appID: String, before targetID: String?) {
        appOrder = moved(appID, before: targetID, in: appOrder)
    }

    mutating func moveFavorite(_ appID: String, before targetID: String?) {
        favoriteAppIDs = moved(appID, before: targetID, in: favoriteAppIDs)
    }

    mutating func moveCategory(id: String, before targetID: String?) {
        guard let category = categories.first(where: { $0.id == id }) else {
            return
        }

        categories.removeAll { $0.id == id }
        if let targetID, let targetIndex = categories.firstIndex(where: { $0.id == targetID }) {
            categories.insert(category, at: targetIndex)
        } else {
            categories.append(category)
        }
    }

    mutating func toggleFavorite(appID: String) {
        if favoriteAppIDs.contains(appID) {
            favoriteAppIDs.removeAll { $0 == appID }
        } else {
            favoriteAppIDs.append(appID)
        }
    }

    mutating func recordLaunch(appID: String, limit: Int = 20, openedAt: Date = Date()) {
        recents.removeAll { $0.appID == appID }
        recents.insert(RecentApp(appID: appID, openedAt: openedAt), at: 0)

        if recents.count > limit {
            recents = Array(recents.prefix(limit))
        }
    }

    private mutating func addItem(_ itemID: LaunchItemID, toCategory categoryID: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }
        guard !categories[index].itemIDs.contains(itemID) else {
            return
        }
        categories[index].itemIDs.append(itemID)
    }

    private mutating func removeAppFromCategorySurface(_ appID: String, categoryID: String) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }
        categories[index].itemIDs.removeAll { $0 == .app(appID) }
    }

    private mutating func removeAppFromFolders(
        _ appID: String,
        inCategory categoryID: String,
        exceptFolderID: String?
    ) {
        guard let category = category(withID: categoryID) else {
            return
        }

        let folderIDs = category.itemIDs.compactMap { itemID -> String? in
            guard case .folder(let folderID) = itemID,
                  folderID != exceptFolderID else {
                return nil
            }
            return folderID
        }

        for folderID in folderIDs {
            guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else {
                continue
            }
            folders[folderIndex].appIDs.removeAll { $0 == appID }
            cleanupFolderIfNeeded(id: folderID, inCategory: categoryID)
        }
    }

    private mutating func cleanupFolderIfNeeded(id folderID: String, inCategory categoryID: String) {
        guard let folder = folder(withID: folderID), folder.appIDs.count <= 1 else {
            return
        }

        guard let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }),
              let folderItemIndex = categories[categoryIndex].itemIDs.firstIndex(of: .folder(folderID)) else {
            cleanupFolder(id: folderID)
            return
        }

        categories[categoryIndex].itemIDs.remove(at: folderItemIndex)
        if let appID = folder.appIDs.first {
            categories[categoryIndex].itemIDs.insert(.app(appID), at: folderItemIndex)
        }
        cleanupFolder(id: folderID)
    }

    private mutating func cleanupFolder(id folderID: String) {
        folders.removeAll { $0.id == folderID }
        for index in categories.indices {
            categories[index].itemIDs.removeAll { $0 == .folder(folderID) }
        }
    }

    private mutating func cleanupFoldersIfUnreferenced(ids folderIDs: [String]) {
        let unreferencedFolderIDs = Set(folderIDs).filter { folderID in
            !categories.contains { $0.itemIDs.contains(.folder(folderID)) }
        }

        guard !unreferencedFolderIDs.isEmpty else {
            return
        }

        folders.removeAll { unreferencedFolderIDs.contains($0.id) }
    }

    private func moved<T: Equatable>(_ item: T, before target: T?, in items: [T]) -> [T] {
        var movedItems = items.filter { $0 != item }
        if let target, let targetIndex = movedItems.firstIndex(of: target) {
            movedItems.insert(item, at: targetIndex)
        } else {
            movedItems.append(item)
        }
        return movedItems
    }
}

private extension LaunchCategory {
    var folderIDs: [String] {
        itemIDs.compactMap { itemID in
            guard case .folder(let folderID) = itemID else {
                return nil
            }
            return folderID
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

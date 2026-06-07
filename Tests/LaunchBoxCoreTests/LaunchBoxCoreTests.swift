import Foundation
import XCTest
@testable import LaunchBoxCore

final class LaunchBoxCoreTests: XCTestCase {
    func testSearchMatchesNameBundleIdentifierAndPathCaseInsensitively() {
        let apps = [
            LaunchApp(
                name: "Xcode",
                bundleIdentifier: "com.apple.dt.Xcode",
                path: "/Applications/Xcode.app"
            ),
            LaunchApp(
                name: "Preview",
                bundleIdentifier: "com.apple.Preview",
                path: "/System/Applications/Preview.app"
            ),
            LaunchApp(
                name: "TablePlus",
                bundleIdentifier: "com.tinyapp.TablePlus",
                path: "/Users/test/Applications/TablePlus.app"
            )
        ]

        XCTAssertEqual(AppSearch.filter(apps, query: "xco").map(\.name), ["Xcode"])
        XCTAssertEqual(AppSearch.filter(apps, query: "APPLE.PRE").map(\.name), ["Preview"])
        XCTAssertEqual(AppSearch.filter(apps, query: "tableplus.app").map(\.name), ["TablePlus"])
        XCTAssertEqual(AppSearch.filter(apps, query: "   ").map(\.name), ["Preview", "TablePlus", "Xcode"])
    }

    func testSearchMatchesChineseNamePinyinAndEnglishAliases() {
        let apps = [
            LaunchApp(
                name: "飞书",
                bundleIdentifier: "com.electron.lark",
                path: "/Applications/Lark.app",
                alternateNames: ["Lark", "Feishu"]
            )
        ]

        XCTAssertEqual(AppSearch.filter(apps, query: "飞").map(\.name), ["飞书"])
        XCTAssertEqual(AppSearch.filter(apps, query: "fei").map(\.name), ["飞书"])
        XCTAssertEqual(AppSearch.filter(apps, query: "feishu").map(\.name), ["飞书"])
        XCTAssertEqual(AppSearch.filter(apps, query: "lark").map(\.name), ["飞书"])
        XCTAssertEqual(AppSearch.filter(apps, query: "feishu").map(\.name), ["飞书"])
    }

    func testAppIdentityPrefersBundleIdentifierAndFallsBackToPath() {
        let bundled = LaunchApp(
            name: "Notes",
            bundleIdentifier: "com.apple.Notes",
            path: "/System/Applications/Notes.app"
        )
        let unbundled = LaunchApp(
            name: "Tool",
            bundleIdentifier: nil,
            path: "/Applications/Tool.app"
        )

        XCTAssertEqual(bundled.id, "bundle:com.apple.Notes")
        XCTAssertEqual(unbundled.id, "path:/Applications/Tool.app")
    }

    func testKeyboardClassifierMapsPlainNavigationKeys() {
        XCTAssertEqual(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 36)), .open)
        XCTAssertEqual(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 123)), .moveLeft)
        XCTAssertEqual(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 124)), .moveRight)
        XCTAssertEqual(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 125)), .moveDown)
        XCTAssertEqual(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 126)), .moveUp)
    }

    func testKeyboardClassifierDoesNotInterceptTextOrModifiedKeys() {
        XCTAssertNil(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 0)))
        XCTAssertNil(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 123, hasCommand: true)))
        XCTAssertNil(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 123, hasOption: true)))
        XCTAssertNil(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 123, hasControl: true)))
        XCTAssertNil(KeyboardCommandClassifier.command(for: LauncherKeyboardInput(keyCode: 123, hasShift: true)))
    }

    func testKeyboardClassifierDoesNotInterceptModalOrFolderPanelInput() {
        XCTAssertNil(
            KeyboardCommandClassifier.command(
                for: LauncherKeyboardInput(keyCode: 123, isModalActive: true)
            )
        )
        XCTAssertNil(
            KeyboardCommandClassifier.command(
                for: LauncherKeyboardInput(keyCode: 123, isFolderOpen: true)
            )
        )
    }

    func testCategoryCanContainAppsAndFoldersInOrder() {
        var library = LaunchLibrary()
        let dev = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "Apple", appIDs: ["bundle:com.apple.Terminal"])

        library.addApp("bundle:com.apple.dt.Xcode", toCategory: dev.id)
        library.addFolder(folder.id, toCategory: dev.id)
        library.moveItem(
            LaunchItemID.folder(folder.id),
            before: LaunchItemID.app("bundle:com.apple.dt.Xcode"),
            inCategory: dev.id
        )

        XCTAssertEqual(
            library.category(withID: dev.id)?.itemIDs,
            [.folder(folder.id), .app("bundle:com.apple.dt.Xcode")]
        )
    }

    func testLaunchDragIDRoundTrip() throws {
        let appDragID = LaunchDragID(itemID: .app("bundle:com.apple.Terminal")).rawValue
        let folderDragID = LaunchDragID(itemID: .folder("folder-1")).rawValue

        XCTAssertEqual(LaunchDragID(rawValue: appDragID)?.itemID, .app("bundle:com.apple.Terminal"))
        XCTAssertEqual(LaunchDragID(rawValue: appDragID)?.appID, "bundle:com.apple.Terminal")
        XCTAssertEqual(LaunchDragID(rawValue: appDragID)?.isApp, true)
        XCTAssertEqual(LaunchDragID(rawValue: folderDragID)?.itemID, .folder("folder-1"))
        XCTAssertEqual(LaunchDragID(rawValue: folderDragID)?.folderID, "folder-1")
        XCTAssertEqual(LaunchDragID(rawValue: folderDragID)?.isFolder, true)
        XCTAssertNil(LaunchDragID(rawValue: "unknown|value"))
    }

    func testGlobalAppOrderCanMoveAppBeforeAnotherApp() {
        var library = LaunchLibrary(appOrder: ["app-a", "app-b", "app-c"])

        library.moveAppInGlobalOrder("app-c", before: "app-a")

        XCTAssertEqual(library.appOrder, ["app-c", "app-a", "app-b"])
    }

    func testFavoriteOrderCanMoveAppBeforeAnotherFavorite() {
        var library = LaunchLibrary(favoriteAppIDs: ["app-a", "app-b", "app-c"])

        library.moveFavorite("app-c", before: "app-a")

        XCTAssertEqual(library.favoriteAppIDs, ["app-c", "app-a", "app-b"])
    }

    func testHiddenAppIDsPersistInLibrary() throws {
        var library = LaunchLibrary()
        library.hiddenAppIDs.insert("app-hidden")

        let data = try JSONEncoder().encode(library)
        let decoded = try JSONDecoder().decode(LaunchLibrary.self, from: data)

        XCTAssertEqual(decoded.hiddenAppIDs, Set(["app-hidden"]))
    }

    func testCategoryOrderCanMoveCategoryBeforeAnotherCategory() {
        var library = LaunchLibrary()
        let system = library.createCategory(named: "系统")
        let video = library.createCategory(named: "视频")
        let dev = library.createCategory(named: "开发")

        library.moveCategory(id: dev.id, before: system.id)

        XCTAssertEqual(library.categories.map(\.id), [dev.id, system.id, video.id])
    }

    func testDeletingCategoryRemovesUnreferencedFolders() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b"])

        library.deleteCategory(id: category.id)

        XCTAssertNil(library.category(withID: category.id))
        XCTAssertNil(library.folder(withID: folder.id))
    }

    func testRemovingFolderItemFromCategoryRemovesUnreferencedFolder() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b"])

        library.removeItem(.folder(folder.id), fromCategory: category.id)

        XCTAssertEqual(library.category(withID: category.id)?.itemIDs, [])
        XCTAssertNil(library.folder(withID: folder.id))
    }

    func testAppCanBelongToMultipleCategoriesWithoutDuplicates() {
        var library = LaunchLibrary()
        let dev = library.createCategory(named: "开发")
        let favorites = library.createCategory(named: "常用")

        library.addApp("bundle:com.apple.dt.Xcode", toCategory: dev.id)
        library.addApp("bundle:com.apple.dt.Xcode", toCategory: dev.id)
        library.addApp("bundle:com.apple.dt.Xcode", toCategory: favorites.id)

        XCTAssertEqual(library.category(withID: dev.id)?.itemIDs, [.app("bundle:com.apple.dt.Xcode")])
        XCTAssertEqual(library.category(withID: favorites.id)?.itemIDs, [.app("bundle:com.apple.dt.Xcode")])
    }

    func testFolderCreationMovesAppsOutOfCategorySurface() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        library.addApp("app-a", toCategory: category.id)
        library.addApp("app-b", toCategory: category.id)

        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b"])

        XCTAssertEqual(library.folder(withID: folder.id)?.appIDs, ["app-a", "app-b"])
        XCTAssertEqual(library.category(withID: category.id)?.itemIDs, [.folder(folder.id)])
    }

    func testAddingAppToFolderRemovesOuterDuplicateInSameCategory() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b"])
        library.addApp("app-c", toCategory: category.id)

        library.addApp("app-c", toFolder: folder.id, inCategory: category.id)

        XCTAssertEqual(library.folder(withID: folder.id)?.appIDs, ["app-a", "app-b", "app-c"])
        XCTAssertEqual(library.category(withID: category.id)?.itemIDs, [.folder(folder.id)])
    }

    func testRemovingAppFromFolderDissolvesFolderWhenOneAppRemains() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b"])

        library.removeApp("app-a", fromFolder: folder.id, inCategory: category.id)

        XCTAssertNil(library.folder(withID: folder.id))
        XCTAssertEqual(library.category(withID: category.id)?.itemIDs, [.app("app-b"), .app("app-a")])
    }

    func testAddingFolderedAppToSameCategoryMovesItBackToSurface() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b", "app-c"])

        library.addApp("app-a", toCategory: category.id)

        XCTAssertEqual(library.folder(withID: folder.id)?.appIDs, ["app-b", "app-c"])
        XCTAssertEqual(library.category(withID: category.id)?.itemIDs, [.folder(folder.id), .app("app-a")])
    }

    func testRemovingAppCompletelyFromCategoryRemovesItFromFolder() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b", "app-c"])

        library.removeAppCompletely("app-b", fromCategory: category.id)

        XCTAssertEqual(library.folder(withID: folder.id)?.appIDs, ["app-a", "app-c"])
        XCTAssertEqual(library.category(withID: category.id)?.itemIDs, [.folder(folder.id)])
    }

    func testRemovingAppCompletelyFromCategoryDissolvesFolderWhenOneAppRemains() {
        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        let folder = library.createFolder(named: "工具", inCategory: category.id, appIDs: ["app-a", "app-b"])

        library.removeAppCompletely("app-b", fromCategory: category.id)

        XCTAssertNil(library.folder(withID: folder.id))
        XCTAssertEqual(library.category(withID: category.id)?.itemIDs, [.app("app-a")])
    }

    func testRecentsAreMostRecentFirstAndLimited() {
        var library = LaunchLibrary()

        for index in 0..<14 {
            library.recordLaunch(appID: "app-\(index)", limit: 10)
        }
        library.recordLaunch(appID: "app-5", limit: 10)

        XCTAssertEqual(library.recents.first?.appID, "app-5")
        XCTAssertEqual(library.recents.count, 10)
        XCTAssertEqual(Set(library.recents.map(\.appID)).count, 10)
    }

    func testPersistenceRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var library = LaunchLibrary()
        let category = library.createCategory(named: "设计")
        library.addApp("bundle:com.figma.Desktop", toCategory: category.id)
        library.toggleFavorite(appID: "bundle:com.figma.Desktop")

        let persistence = LibraryPersistence(baseDirectory: directory)
        try persistence.save(library)

        let loaded = try persistence.load()
        XCTAssertEqual(loaded.categories.first?.name, "设计")
        XCTAssertEqual(loaded.categories.first?.itemIDs, [.app("bundle:com.figma.Desktop")])
        XCTAssertEqual(loaded.favoriteAppIDs, ["bundle:com.figma.Desktop"])
    }

    func testPersistenceCanExportImportAndBackupCurrentLibrary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var library = LaunchLibrary()
        let category = library.createCategory(named: "开发")
        library.addApp("bundle:com.apple.Terminal", toCategory: category.id)
        library.toggleFavorite(appID: "bundle:com.apple.Terminal")

        let persistence = LibraryPersistence(baseDirectory: directory)
        try persistence.save(library)

        let exportURL = directory.appendingPathComponent("export.json")
        try persistence.export(library, to: exportURL)

        let imported = try persistence.importLibrary(from: exportURL)
        XCTAssertEqual(imported, library)

        let backupURL = try XCTUnwrap(persistence.backupCurrentFile(label: "before-import"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
    }
}

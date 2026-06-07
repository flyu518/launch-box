import AppKit
import Foundation
import LaunchBoxCore

struct AppScanner {
    var directories: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
    ]

    func scan() -> [LaunchApp] {
        var appsByID: [String: LaunchApp] = [:]

        for directory in directories where FileManager.default.fileExists(atPath: directory.path) {
            for app in scan(directory: directory) {
                appsByID[app.id] = app
            }
        }

        return appsByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func scan(directory: URL) -> [LaunchApp] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .localizedNameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var apps: [LaunchApp] = []

        for case let url as URL in enumerator {
            guard url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else {
                continue
            }

            if let app = makeApp(from: url) {
                apps.append(app)
            }
            enumerator.skipDescendants()
        }

        return apps
    }

    private func makeApp(from url: URL) -> LaunchApp? {
        guard let bundle = Bundle(url: url) else {
            return nil
        }

        let fileName = localizedFileName(for: url)
        let bundleDisplayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let rawDisplayName = fileName
            ?? bundleDisplayName
            ?? bundleName
            ?? url.deletingPathExtension().lastPathComponent
        let displayName = AppDisplayNameResolver.resolve(
            rawName: rawDisplayName,
            localizedInfoPlist: localizedInfoPlist(for: url)
        )
        let alternateNames = alternateNames(
            displayName: displayName,
            candidates: [fileName, bundleDisplayName, bundleName, fallbackName]
        )

        return LaunchApp(
            name: displayName,
            bundleIdentifier: bundle.bundleIdentifier,
            path: url.path,
            alternateNames: alternateNames
        )
    }

    private func alternateNames(displayName: String, candidates: [String?]) -> [String] {
        var seen = Set([displayName.lowercased()])
        return candidates.compactMap { candidate in
            let name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else {
                return nil
            }
            return name
        }
    }

    private func localizedFileName(for url: URL) -> String? {
        guard let localizedName = try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName else {
            return nil
        }

        let name = localizedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }

        if name.lowercased().hasSuffix(".app") {
            return String(name.dropLast(4))
        }
        return name
    }

    private func localizedInfoPlist(for appURL: URL) -> [String: [String: String]]? {
        var localizedValues = localizedInfoPlistTable(for: appURL) ?? [:]

        for (localeIdentifier, strings) in localizedInfoPlistStrings(for: appURL) {
            localizedValues[localeIdentifier, default: [:]].merge(strings) { current, _ in current }
        }

        return localizedValues.isEmpty ? nil : localizedValues
    }

    private func localizedInfoPlistTable(for appURL: URL) -> [String: [String: String]]? {
        let tableURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("InfoPlist.loctable", isDirectory: false)

        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let data = try? Data(contentsOf: tableURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
              ) as? [String: Any] else {
            return nil
        }

        var localizedValues: [String: [String: String]] = [:]
        for (localeIdentifier, value) in plist {
            guard let dictionary = value as? [String: Any] else {
                continue
            }

            let strings = dictionary.compactMapValues { $0 as? String }
            if !strings.isEmpty {
                localizedValues[localeIdentifier] = strings
            }
        }

        return localizedValues.isEmpty ? nil : localizedValues
    }

    private func localizedInfoPlistStrings(for appURL: URL) -> [String: [String: String]] {
        let resourcesURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)

        guard let resourceURLs = try? FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var localizedValues: [String: [String: String]] = [:]
        for localeURL in resourceURLs where localeURL.pathExtension == "lproj" {
            let localeIdentifier = localeURL.deletingPathExtension().lastPathComponent
            let stringsURL = localeURL.appendingPathComponent("InfoPlist.strings", isDirectory: false)

            guard let strings = propertyListStrings(at: stringsURL), !strings.isEmpty else {
                continue
            }

            localizedValues[localeIdentifier] = strings
        }

        return localizedValues
    }

    private func propertyListStrings(at url: URL) -> [String: String]? {
        var format = PropertyListSerialization.PropertyListFormat.openStep
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
              ) as? [String: Any] else {
            return nil
        }

        return plist.compactMapValues { $0 as? String }
    }
}

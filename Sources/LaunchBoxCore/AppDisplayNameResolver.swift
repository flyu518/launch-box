import Foundation

public enum AppDisplayNameResolver {
    public static func resolve(
        rawName: String,
        localizedInfoPlist: [String: [String: String]]?,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let localizedInfoPlist else {
            return trimmedName
        }

        for language in preferredLanguages {
            for key in localizationCandidates(for: language) {
                if let localizedName = localizedInfoPlist[key]?["CFBundleDisplayName"]
                    ?? localizedInfoPlist[key]?["CFBundleName"],
                   !localizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return localizedName
                }
            }
        }

        return trimmedName
    }

    private static func localizationCandidates(for language: String) -> [String] {
        let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        var candidates = [trimmed]
        let normalized = language.replacingOccurrences(of: "-", with: "_")
        candidates.append(normalized)
        let lowercased = normalized.lowercased()
        let components = normalized.split(separator: "_").map(String.init)

        if components.count >= 2 {
            candidates.append("\(components[0])-\(components[1])")
            candidates.append("\(components[0])_\(components[1])")
        }

        if lowercased.hasPrefix("zh_hans") || lowercased.hasPrefix("zh_cn") {
            candidates.append("zh-Hans")
            candidates.append("zh_CN")
        } else if lowercased.hasPrefix("zh_hk") || lowercased.hasPrefix("zh_mo") {
            candidates.append("zh-Hant")
            candidates.append("zh_HK")
        } else if lowercased.hasPrefix("zh_hant") || lowercased.hasPrefix("zh_tw") {
            candidates.append("zh-Hant")
            candidates.append("zh_TW")
        }

        if let baseLanguage = components.first {
            candidates.append(String(baseLanguage))
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }
}

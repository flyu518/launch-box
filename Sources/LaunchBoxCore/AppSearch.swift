import Foundation

public enum AppSearch {
    public static func filter(_ apps: [LaunchApp], query: String) -> [LaunchApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        guard !trimmed.isEmpty else {
            return sorted
        }

        return sorted.filter { app in
            searchableTerms(for: app).contains { term in
                term.contains(normalizedSearchText(trimmed))
            }
        }
    }

    private static func searchableTerms(for app: LaunchApp) -> [String] {
        var values = [app.name, app.path]
        values.append(contentsOf: app.alternateNames)

        if let bundleIdentifier = app.bundleIdentifier {
            values.append(bundleIdentifier)
        }

        return values.flatMap(searchableTerms)
    }

    private static func searchableTerms(for value: String) -> [String] {
        let normalized = normalizedSearchText(value)
        let pinyin = normalizedPinyin(value)

        return [normalized, pinyin, pinyin.replacingOccurrences(of: " ", with: "")]
            .filter { !$0.isEmpty }
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedPinyin(_ value: String) -> String {
        guard let latin = value.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) else {
            return ""
        }

        return normalizedSearchText(latin)
    }
}

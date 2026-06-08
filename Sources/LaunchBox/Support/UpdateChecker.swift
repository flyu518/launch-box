import Foundation

struct AppUpdate: Equatable {
    var version: String
    var pageURL: URL
}

enum UpdateCheckResult: Equatable {
    case upToDate
    case available(AppUpdate)
}

enum UpdateChecker {
    static func check(currentVersion: String) async throws -> UpdateCheckResult {
        var request = URLRequest(url: AppMetadata.latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("launch-box", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName.normalizedVersion
        guard SemanticVersion(latestVersion) > SemanticVersion(currentVersion) else {
            return .upToDate
        }

        return .available(
            AppUpdate(
                version: release.tagName,
                pageURL: release.htmlURL
            )
        )
    }
}

private struct GitHubRelease: Decodable {
    var tagName: String
    var htmlURL: URL

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

private struct SemanticVersion: Comparable {
    private let components: [Int]

    init(_ version: String) {
        components = version.normalizedVersion
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

private extension String {
    var normalizedVersion: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
            .trimmingPrefix("V")
    }

    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

import Foundation

enum AppMetadata {
    static let repositoryURL = URL(string: "https://github.com/flyu518/launch-box")!
    static let releasesURL = URL(string: "https://github.com/flyu518/launch-box/releases")!
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/flyu518/launch-box/releases/latest")!

    static var displayName: String {
        bundleString(for: "CFBundleDisplayName")
            ?? bundleString(for: "CFBundleName")
            ?? "启动台"
    }

    static var version: String {
        bundleString(for: "CFBundleShortVersionString") ?? "0.0.1"
    }

    static var build: String {
        bundleString(for: "CFBundleVersion") ?? "1"
    }

    static var versionDisplay: String {
        "\(version) (\(build))"
    }

    private static func bundleString(for key: String) -> String? {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

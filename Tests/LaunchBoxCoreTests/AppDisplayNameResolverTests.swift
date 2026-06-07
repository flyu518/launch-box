import XCTest
@testable import LaunchBoxCore

final class AppDisplayNameResolverTests: XCTestCase {
    func testUsesLocalizedInfoPlistNameWhenPreferredLanguageIsChinese() {
        XCTAssertEqual(
            AppDisplayNameResolver.resolve(
                rawName: "Calculator",
                localizedInfoPlist: [
                    "zh_CN": [
                        "CFBundleDisplayName": "计算器",
                        "CFBundleName": "计算器"
                    ]
                ],
                preferredLanguages: ["zh-Hans-HT"]
            ),
            "计算器"
        )
    }

    func testUsesHyphenatedLocalizedInfoPlistNameWhenPreferredLanguageIsChinese() {
        XCTAssertEqual(
            AppDisplayNameResolver.resolve(
                rawName: "Feishu",
                localizedInfoPlist: [
                    "zh-Hans": [
                        "CFBundleDisplayName": "飞书",
                        "CFBundleName": "飞书"
                    ]
                ],
                preferredLanguages: ["zh-Hans-HT"]
            ),
            "飞书"
        )
    }

    func testKeepsRawNameWhenLocalizedInfoPlistDoesNotContainPreferredLanguage() {
        XCTAssertEqual(
            AppDisplayNameResolver.resolve(
                rawName: "Calculator",
                localizedInfoPlist: [
                    "ja": [
                        "CFBundleDisplayName": "計算機"
                    ]
                ],
                preferredLanguages: ["zh-Hans-HT"]
            ),
            "Calculator"
        )
    }

    func testKeepsRawNameWhenPreferredLanguageIsNotLocalized() {
        XCTAssertEqual(
            AppDisplayNameResolver.resolve(
                rawName: "Calculator",
                localizedInfoPlist: [
                    "zh_CN": [
                        "CFBundleDisplayName": "计算器"
                    ]
                ],
                preferredLanguages: ["en-US"]
            ),
            "Calculator"
        )
    }

    func testKeepsRawNameWhenLocalizedInfoPlistIsMissing() {
        XCTAssertEqual(
            AppDisplayNameResolver.resolve(
                rawName: "TablePlus",
                localizedInfoPlist: nil,
                preferredLanguages: ["zh-Hans-HT"]
            ),
            "TablePlus"
        )
    }
}

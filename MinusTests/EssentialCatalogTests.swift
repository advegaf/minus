import XCTest
@testable import Minus

/// v1.8: minus declares no query schemes and probes nothing, so there is no
/// plist contract left to enforce. What remains is catalog integrity plus the
/// device-verified launch URLs.
final class EssentialCatalogTests: XCTestCase {
    /// The lock on the probe removal: if `LSApplicationQueriesSchemes` ever
    /// comes back, something started asking permission to ask.
    func testNoQuerySchemesAreDeclared() {
        XCTAssertNil(
            Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes"),
            "minus does not probe, so it must not declare query schemes"
        )
    }

    func testCatalogEntriesAreWellFormed() {
        XCTAssertEqual(EssentialAppCatalog.all.count, 60, "catalog should carry the sixty")
        for app in EssentialAppCatalog.all {
            XCTAssertNotNil(app.url, "\(app.slug) has an unparseable urlString")
            XCTAssertTrue(app.urlString.hasPrefix(app.scheme), "\(app.slug): urlString should start with its scheme")
            XCTAssertFalse(app.displayName.isEmpty)
            for alt in app.altCandidates {
                XCTAssertNotNil(URL(string: alt), "\(app.slug) alt candidate '\(alt)' is unparseable")
            }
        }
    }

    /// Verified by hand on device through the DEBUG scheme lab.
    func testDeviceVerifiedSchemesArePromoted() {
        let expected: [String: String] = [
            "cashapp": "squarecash:",
            "amazon": "com.amazon.mobile.shopping:",
            "robinhood": "robinhood:",
            "chatgpt": "chatgpt:",
        ]
        for (slug, urlString) in expected {
            let app = EssentialAppCatalog.app(slug: slug)
            XCTAssertEqual(app?.urlString, urlString, slug)
            XCTAssertEqual(app?.confidence, .high, "\(slug) was confirmed on device")
        }
    }

    func testSlugsAndSchemesAreUnique() {
        let slugs = EssentialAppCatalog.all.map(\.slug)
        XCTAssertEqual(slugs.count, Set(slugs).count, "duplicate slugs")
        let schemes = EssentialAppCatalog.all.map(\.scheme)
        XCTAssertEqual(schemes.count, Set(schemes).count, "duplicate schemes")
    }

    func testEveryCategoryHasMembers() {
        for category in CatalogCategory.allCases {
            XCTAssertFalse(
                EssentialAppCatalog.apps(in: category).isEmpty,
                "category '\(category.rawValue)' is empty"
            )
        }
    }

    /// Communication apps and custom entries reach their app only through the
    /// user's shortcut. Everything else tries its universal link, then its
    /// scheme, then the shortcut.
    func testLaunchRouting() {
        for slug in ["phone", "messages", "facetime", "mail"] {
            XCTAssertEqual(
                EssentialLaunchURL.launchPlan(slug: slug, urlString: "ignored:", universalLink: nil)
                    .map(\.absoluteString),
                ["shortcuts://run-shortcut?name=minus-\(slug)"],
                slug
            )
        }
        XCTAssertEqual(EssentialLaunchURL.shortcutName(for: "custom-pilates"), "minus-pilates")
    }

    /// Every universal link parses and is https: a custom scheme here would
    /// silently break widget launches, since App Intents only open https.
    func testUniversalLinksAreWellFormed() {
        for app in EssentialAppCatalog.all {
            for link in ([app.universalLink].compactMap { $0 } + app.altLinks) {
                let url = URL(string: link)
                XCTAssertNotNil(url, "\(app.slug): '\(link)' is unparseable")
                XCTAssertEqual(url?.scheme, "https", "\(app.slug): '\(link)' must be https")
            }
        }
    }

    /// The apps the user named must reach the widget with an https target.
    func testWidgetLaunchableAppsHaveUniversalLinks() {
        for slug in ["spotify", "discord", "instagram", "youtube", "chatgpt", "amazon"] {
            let app = EssentialAppCatalog.app(slug: slug)
            XCTAssertNotNil(app?.universalLink, "\(slug) needs a universal link to launch from the widget")
            XCTAssertTrue(
                EssentialLaunchURL.widgetTarget(
                    slug: slug, urlString: app?.urlString ?? "", universalLink: app?.universalLink
                )?.absoluteString.hasPrefix("https") ?? false,
                "\(slug) widget target must be https"
            )
        }
    }
}

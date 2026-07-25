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

    /// An unverified link must never reach the widget: on device, bare
    /// homepages (t.me, robinhood.com, chatgpt.com) opened Safari. Unverified
    /// rows bounce instead, so the app's own scheme gets first refusal.
    func testUnverifiedLinksBounceRatherThanRiskSafari() {
        for app in EssentialAppCatalog.all where !app.linkVerified {
            XCTAssertEqual(
                EssentialLaunchURL.widgetTarget(
                    slug: app.slug,
                    urlString: app.urlString,
                    universalLink: app.universalLink,
                    linkVerified: app.linkVerified
                )?.absoluteString,
                "minus://open/\(app.slug)",
                "\(app.slug) is unverified and must bounce"
            )
        }
    }

    func testVerifiedLinkGoesStraightToTheApp() {
        XCTAssertEqual(
            EssentialLaunchURL.widgetTarget(
                slug: "spotify",
                urlString: "spotify:",
                universalLink: "https://open.spotify.com",
                linkVerified: true
            )?.absoluteString,
            "https://open.spotify.com"
        )
    }

    /// The scheme leads in-app: a miss is silent, a wrong link is Safari.
    func testSchemeLeadsTheInAppPlan() {
        let plan = EssentialLaunchURL.launchPlan(
            slug: "telegram", urlString: "tg:", universalLink: "https://t.me/"
        ).map(\.absoluteString)
        XCTAssertEqual(plan.first, "tg:")
        XCTAssertEqual(plan.dropFirst().first, "https://t.me/")
    }
}

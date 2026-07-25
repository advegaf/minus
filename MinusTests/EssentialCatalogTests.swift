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
    /// user's shortcut; everything else opens by scheme, with the shortcut as
    /// the second chance when a scheme opens nothing.
    func testLaunchRouting() {
        for slug in ["phone", "messages", "facetime", "mail"] {
            XCTAssertEqual(
                EssentialLaunchURL.resolve(slug: slug, urlString: "ignored:")?.absoluteString,
                "shortcuts://run-shortcut?name=minus-\(slug)"
            )
            XCTAssertNil(EssentialLaunchURL.shortcutFallback(slug: slug), "no retry of the same URL")
        }
        XCTAssertEqual(
            EssentialLaunchURL.resolve(slug: "spotify", urlString: "spotify:")?.absoluteString,
            "spotify:"
        )
        XCTAssertEqual(
            EssentialLaunchURL.shortcutFallback(slug: "spotify")?.absoluteString,
            "shortcuts://run-shortcut?name=minus-spotify"
        )
        XCTAssertEqual(EssentialLaunchURL.shortcutName(for: "custom-pilates"), "minus-pilates")
    }
}

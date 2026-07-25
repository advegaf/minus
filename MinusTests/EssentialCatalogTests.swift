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
        }
    }

    /// Identities verified against the App Store's own records.
    func testDeviceVerifiedIdentities() {
        let expected: [String: String] = [
            "spotify": "com.spotify.client",
            "telegram": "ph.telegra.Telegraph",
            "chatgpt": "com.openai.chat",
            "robinhood": "com.robinhood.release.Robinhood",
        ]
        for (slug, bundleID) in expected {
            XCTAssertEqual(EssentialAppCatalog.app(slug: slug)?.bundleID, bundleID, slug)
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
    /// user's shortcut. Everything else tries its scheme, then the shortcut,
    /// behind the identity launch that runs first.
    func testLaunchRouting() {
        for slug in ["phone", "messages", "facetime", "mail"] {
            XCTAssertEqual(
                EssentialLaunchURL.launchPlan(slug: slug, urlString: "ignored:").map(\.absoluteString),
                ["shortcuts://run-shortcut?name=minus-\(slug)"],
                slug
            )
        }
        XCTAssertEqual(EssentialLaunchURL.shortcutName(for: "custom-pilates"), "minus-pilates")
    }

    /// Identity is the whole launcher now: every catalog row needs one.
    /// Reverse-DNS is the convention, not a rule: Pinterest ships as plain
    /// "pinterest" (confirmed against the App Store's own record), so the
    /// assertion is non-empty and space-free rather than dotted.
    func testEveryCatalogRowCarriesAnIdentity() {
        for app in EssentialAppCatalog.all {
            let identity = app.bundleID ?? ""
            XCTAssertFalse(identity.isEmpty, "\(app.slug) has no bundle identifier")
            XCTAssertFalse(identity.contains(" "), "\(app.slug): '\(identity)' is not a bundle id")
        }
    }
}

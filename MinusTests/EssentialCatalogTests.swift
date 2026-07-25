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
        XCTAssertGreaterThan(EssentialAppCatalog.all.count, 200, "the catalog should cover a real phone")
        for app in EssentialAppCatalog.all {
            XCTAssertFalse(app.displayName.isEmpty, "\(app.slug) has no name")
            XCTAssertFalse(app.slug.isEmpty)
            // A scheme is optional now, but a declared one has to parse.
            if !app.urlString.isEmpty {
                XCTAssertNotNil(app.url, "\(app.slug) has an unparseable urlString")
                XCTAssertTrue(app.urlString.hasPrefix(app.scheme), "\(app.slug): urlString should start with its scheme")
            }
        }
    }

    /// Every preserved scheme must belong to a row that still exists, or the
    /// fallback map is quietly rotting against a regenerated catalog.
    func testVerifiedSchemesAllPointAtRealRows() {
        let slugs = Set(EssentialAppCatalog.all.map(\.slug))
        for slug in EssentialAppCatalog.verifiedSchemes.keys {
            XCTAssertTrue(slugs.contains(slug), "verified scheme for '\(slug)', which is not in the catalog")
        }
    }

    /// Identities verified against the App Store's own records.
    func testDeviceVerifiedIdentities() {
        let expected: [String: String] = [
            "oura": "com.ouraring.oura",
            "spotify": "com.spotify.client",
            "telegram": "ph.telegra.Telegraph",
            "chatgpt": "com.openai.chat",
            "robinhood": "com.robinhood.release.Robinhood",
        ]
        for (slug, bundleID) in expected {
            XCTAssertEqual(EssentialAppCatalog.app(slug: slug)?.bundleID, bundleID, slug)
        }
    }

    /// A duplicate slug collapses the ForEach that renders the picker, and a
    /// card stores slugs, so two rows sharing one is a real corruption. Schemes
    /// are no longer required to be unique: most rows no longer have one.
    func testSlugsAreUnique() {
        let slugs = EssentialAppCatalog.all.map(\.slug)
        XCTAssertEqual(slugs.count, Set(slugs).count, "duplicate slugs")
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
            XCTAssertFalse(app.bundleID.isEmpty, "\(app.slug) has no bundle identifier")
            XCTAssertFalse(app.bundleID.contains(" "), "\(app.slug): '\(app.bundleID)' is not a bundle id")
        }
    }

    /// The identities that were resolved to the WRONG app on the first pass and
    /// had to be pinned by hand. The store answers a name with whatever it
    /// thinks you meant, and a valid id for the wrong app is invisible at
    /// runtime, so the corrections are locked here.
    func testHandCorrectedIdentities() {
        let expected: [String: String] = [
            "word": "com.microsoft.Office.Word",      // was Wordscapes, a word game
            "gemini": "com.google.gemini",            // was Gemini, the crypto exchange
            "delta": "com.delta.iphone.ver1",         // was Delta, a game emulator
            "clear": "com.clearme.Clear",             // was Clear, a Brazilian broker
            "dominos": "com.dominos.iphone",          // was a game about dominoes
            "max": "com.wbd.stream",                  // was Max Fashion
            "onesec": "wtf.riedel.one-sec",           // was a different One-Sec
            "particle": "news.particle.app",          // was Particle, an art app
            "copilot": "com.microsoft.copilot",       // was CoPilot, the budgeting app
            "marcus": "com.marcus.ios",
            "authy": "com.authy",
        ]
        for (slug, bundleID) in expected {
            XCTAssertEqual(EssentialAppCatalog.app(slug: slug)?.bundleID, bundleID, slug)
        }
    }
}

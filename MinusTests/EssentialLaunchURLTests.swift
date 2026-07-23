import XCTest
@testable import Minus

final class EssentialLaunchURLTests: XCTestCase {
    func testCommAppsRouteThroughShortcuts() {
        for slug in ["phone", "messages", "facetime", "mail"] {
            let url = EssentialLaunchURL.resolve(slug: slug, urlString: "ignored:")
            XCTAssertEqual(
                url?.absoluteString,
                "shortcuts://run-shortcut?name=minus-\(slug)",
                slug
            )
        }
    }

    func testEverythingElseOpensByScheme() {
        let cases = [
            ("spotify", "spotify:"),
            ("notes", "mobilenotes:"),
            ("photos", "photos-redirect:"),
            ("maps", "maps:"),
        ]
        for (slug, scheme) in cases {
            XCTAssertEqual(
                EssentialLaunchURL.resolve(slug: slug, urlString: scheme)?.absoluteString,
                scheme,
                slug
            )
        }
    }

    func testCatalogCommEntriesAreCoveredBySet() {
        // The shortcut set must exactly match the catalog's communication apps.
        for slug in EssentialLaunchURL.shortcutSlugs {
            XCTAssertNotNil(EssentialAppCatalog.app(slug: slug), "unknown comm slug \(slug)")
        }
    }
}

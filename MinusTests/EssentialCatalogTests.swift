import XCTest
@testable import Minus

final class EssentialCatalogTests: XCTestCase {
    /// Every catalog scheme must be declared in LSApplicationQueriesSchemes or
    /// canOpenURL silently lies and installed apps grey out. Lockstep with
    /// project.yml, verified against the built product's Info.plist.
    func testEverySchemeIsDeclaredForCanOpenURL() throws {
        let declared = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]
        let schemes = try XCTUnwrap(declared, "LSApplicationQueriesSchemes missing from Info.plist")
        for app in EssentialAppCatalog.all {
            XCTAssertTrue(
                schemes.contains(app.scheme),
                "Catalog scheme '\(app.scheme)' (\(app.displayName)) is not in LSApplicationQueriesSchemes — add it to project.yml"
            )
        }
    }

    func testDeclaredSchemesStayUnderAppleCap() {
        let declared = (Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]) ?? []
        XCTAssertLessThanOrEqual(declared.count, 50, "Apple caps LSApplicationQueriesSchemes at 50")
    }

    func testCatalogEntriesAreWellFormed() {
        XCTAssertFalse(EssentialAppCatalog.all.isEmpty)
        for app in EssentialAppCatalog.all {
            XCTAssertNotNil(app.url, "\(app.slug) has an unparseable urlString")
            XCTAssertEqual(app.urlString.hasPrefix(app.scheme), true, "\(app.slug): urlString should start with its scheme")
            XCTAssertFalse(app.displayName.isEmpty)
        }
    }

    func testSlugsAreUnique() {
        let slugs = EssentialAppCatalog.all.map(\.slug)
        XCTAssertEqual(slugs.count, Set(slugs).count)
    }
}

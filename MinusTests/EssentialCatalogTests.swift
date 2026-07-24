import XCTest
@testable import Minus

final class EssentialCatalogTests: XCTestCase {
    private var plistSchemes: [String] {
        (Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]) ?? []
    }

    /// v1.6 inversion: not every catalog scheme is declared anymore (60 apps
    /// vs Apple's 50-scheme cap). The contract is now bidirectional over the
    /// `declared` flag: every declared row's scheme is in the plist, and every
    /// plist scheme belongs to a declared row (no orphans drifting in project.yml).
    func testDeclaredFlagMatchesPlistBothDirections() throws {
        let declared = plistSchemes
        XCTAssertFalse(declared.isEmpty, "LSApplicationQueriesSchemes missing from Info.plist")

        for app in EssentialAppCatalog.all where app.declared {
            XCTAssertTrue(
                declared.contains(app.scheme),
                "\(app.slug) is declared:true but '\(app.scheme)' is not in LSApplicationQueriesSchemes"
            )
        }
        let catalogDeclared = EssentialAppCatalog.declaredSchemes
        for scheme in declared {
            XCTAssertTrue(
                catalogDeclared.contains(scheme),
                "plist declares '\(scheme)' but no catalog row owns it — remove it or flag its row declared:true"
            )
        }
    }

    func testUndeclaredRowsAreHonestAboutIt() {
        let declared = Set(plistSchemes)
        for app in EssentialAppCatalog.all where !app.declared {
            XCTAssertFalse(
                declared.contains(app.scheme),
                "\(app.slug) is declared:false but its scheme IS in the plist — flip the flag"
            )
        }
    }

    func testDeclaredSchemesStayUnderAppleCap() {
        XCTAssertLessThanOrEqual(plistSchemes.count, 50, "Apple caps LSApplicationQueriesSchemes at 50")
    }

    /// The launcher's own machinery (comm trampoline + shortcuts) must never
    /// lose declaration to a future trim.
    func testCoreSchemesStayDeclared() {
        for scheme in EssentialAppCatalog.mustDeclare {
            XCTAssertTrue(
                EssentialAppCatalog.declaredSchemes.contains(scheme),
                "core scheme '\(scheme)' fell out of the declared set"
            )
        }
    }

    func testCatalogEntriesAreWellFormed() {
        XCTAssertEqual(EssentialAppCatalog.all.count, 60, "catalog should carry the v1.6 sixty")
        for app in EssentialAppCatalog.all {
            XCTAssertNotNil(app.url, "\(app.slug) has an unparseable urlString")
            XCTAssertTrue(app.urlString.hasPrefix(app.scheme), "\(app.slug): urlString should start with its scheme")
            XCTAssertFalse(app.displayName.isEmpty)
            for alt in app.altCandidates {
                XCTAssertNotNil(URL(string: alt), "\(app.slug) alt candidate '\(alt)' is unparseable")
            }
        }
    }

    /// Low-confidence schemes (past knowledge cutoff) never ship declared —
    /// a wrong declared scheme would dim an installed app, which is a lie.
    /// Undeclared + nil installed = worst case is a no-op tap.
    func testLowConfidenceRowsAreNeverDeclared() {
        for app in EssentialAppCatalog.all where app.confidence == .low {
            XCTAssertFalse(app.declared, "\(app.slug) is low-confidence but declared — undeclare until lab-verified")
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
}

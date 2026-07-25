import XCTest
@testable import Minus

/// v1.15: an app added by name used to wear the App Store's marketing title,
/// so the launcher read "MacroFactor - Macro Tracker" where the home screen
/// reads "MacroFactor".
final class AppNameTests: XCTestCase {
    /// Real store titles, taken from scripts/catalog-cache.json.
    func testStoreTitlesShortenToTheHomeScreenName() {
        let cases: [String: String] = [
            "MacroFactor - Macro Tracker": "MacroFactor",
            "Hevy - Workout Tracker Gym Log": "Hevy",
            "Flighty – Live Flight Tracker": "Flighty",
            "one sec | screen time + focus": "one sec",
            "1Password: Password Manager": "1Password",
            "1.1.1.1: Faster Internet": "1.1.1.1",
            "Day One: Daily Journal & Diary": "Day One",
            "GOAT – Sneakers & Apparel": "GOAT",
            "Google Health (Fitbit)": "Google Health",
            "Wells Fargo Mobile®": "Wells Fargo Mobile",
            "Empower ®": "Empower",
        ]
        for (title, expected) in cases {
            XCTAssertEqual(AppName.short(title), expected, title)
        }
    }

    /// The reason the rule only cuts at a SPACED separator: these carry
    /// hyphens and dots inside the name itself, and a naive split destroys
    /// them ("Chick-fil-A" would become "Chick").
    func testNamesWithInternalPunctuationSurvive() {
        for name in ["Chick-fil-A", "7-ELEVEN", "1.1.1.1", "Are.na", "Dunkin'",
                     "Cash App", "one sec", "Booking.com", "Domino's Pizza USA"] {
            XCTAssertEqual(AppName.short(name), name, name)
        }
    }

    /// Idempotence is what lets the bootstrap pass run on every launch without
    /// dirtying the store or eroding a name one cut at a time.
    func testShorteningIsIdempotent() {
        for title in ["MacroFactor - Macro Tracker", "Google Health (Fitbit)", "Chick-fil-A"] {
            let once = AppName.short(title)
            XCTAssertEqual(AppName.short(once), once, title)
        }
    }

    /// A title that is nothing but punctuation keeps whatever it had, rather
    /// than becoming a nameless row.
    func testDegenerateTitlesKeepTheirOriginal() {
        XCTAssertEqual(AppName.short(" - "), " - ")
        XCTAssertEqual(AppName.short(""), "")
    }
}

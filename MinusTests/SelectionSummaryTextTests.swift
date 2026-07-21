import XCTest
@testable import Minus

final class SelectionSummaryTextTests: XCTestCase {
    func testAllShapes() {
        let cases: [(apps: Int, categories: Int, expected: String)] = [
            (0, 0, "nothing yet"),
            (1, 0, "1 app"),
            (0, 1, "1 category"),
            (1, 1, "1 app · 1 category"),
            (14, 2, "14 apps · 2 categories"),
            (0, 2, "2 categories"),
            (6, 0, "6 apps"),
        ]
        for c in cases {
            XCTAssertEqual(
                SelectionSummaryText.line(apps: c.apps, categories: c.categories),
                c.expected,
                "apps: \(c.apps), categories: \(c.categories)"
            )
        }
    }
}

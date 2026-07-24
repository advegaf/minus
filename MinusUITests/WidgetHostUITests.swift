import XCTest

/// Drives Springboard itself: enters jiggle mode, opens the widget gallery,
/// adds the minus launcher to the simulator home screen, and screenshots the
/// REAL rendered widget — the strongest evidence surface short of hardware.
/// Springboard chrome is version-fragile, so every step attaches a screenshot
/// and queries fall back across element types.
final class WidgetHostUITests: XCTestCase {
    @MainActor
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tapFirst(_ queries: [XCUIElement], timeout: TimeInterval = 4) -> Bool {
        for element in queries where element.waitForExistence(timeout: timeout) {
            element.tap()
            return true
        }
        return false
    }

    @MainActor
    func testAddLauncherWidgetToHomeScreen() {
        let sb = springboard
        XCUIDevice.shared.press(.home)
        sb.activate()
        Thread.sleep(forTimeInterval: 1)

        // Long-press empty wallpaper → jiggle mode.
        sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).press(forDuration: 2.0)
        shot("01-jiggle")

        // iOS 18+: top-left Edit menu → Add Widget.
        if tapFirst([sb.buttons["Edit"], sb.otherElements["Edit"]]) {
            shot("02-edit-menu")
            _ = tapFirst([
                sb.buttons["Add Widget"],
                sb.menuItems["Add Widget"],
                sb.staticTexts["Add Widget"],
            ])
        } else {
            // Older chrome: a "+" button directly.
            _ = tapFirst([sb.buttons["+"], sb.buttons["Add"]])
        }
        shot("03-gallery")

        // Search for minus.
        let search = sb.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 6), "widget gallery search missing")
        search.tap()
        search.typeText("minus")
        shot("04-searched")

        // Tap the minus result (cell/button/text — chrome varies).
        let hit = tapFirst([
            sb.cells.containing(NSPredicate(format: "label CONTAINS[c] 'minus'")).firstMatch,
            sb.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'minus'")).firstMatch,
            sb.staticTexts["minus"].firstMatch,
        ], timeout: 6)
        XCTAssertTrue(hit, "minus not found in widget gallery")
        shot("05-family-pager")

        // v1.6: LARGE is the first (and on iOS 26 the only) family — no swipe.
        shot("06-large-family")
        XCTAssertTrue(
            tapFirst([sb.buttons["Add Widget"], sb.buttons[" Add Widget"]], timeout: 6),
            "Add Widget button missing"
        )
        Thread.sleep(forTimeInterval: 1)

        // Leave jiggle mode.
        if !tapFirst([sb.buttons["Done"]], timeout: 3) {
            XCUIDevice.shared.press(.home)
        }
        Thread.sleep(forTimeInterval: 1)
        shot("07-placed")

        // The real widget should now show launcher names from the snapshot.
        XCTAssertTrue(
            sb.staticTexts["phone"].waitForExistence(timeout: 6)
                || sb.staticTexts["messages"].exists
                || sb.staticTexts["open minus"].exists,
            "placed widget shows neither launcher names nor the empty invite"
        )
    }
}

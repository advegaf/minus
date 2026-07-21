import XCTest

/// End-to-end coverage for the Home monument: the frozen clock, the intention,
/// the essentials launcher, the live focus state, and the onboarding gate.
/// Every launch pins the clock to 09:41 and runs against the in-memory store.
final class HomeUITests: XCTestCase {

    // MARK: - Launch

    @MainActor
    private func launch(state: String, freeze: String = "09:41") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment["MINUS_STATE"] = state
        app.launchEnvironment["MINUS_FREEZE_TIME"] = freeze
        app.launch()
        return app
    }

    /// Identifier lookup that is agnostic to the resolved element type (the
    /// clock container is an `.other`, rows are `.button`s, and so on).
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - (a) HO-1 — onboarded monument

    @MainActor
    func testOnboardedHomeShowsMonument() {
        let app = launch(state: "onboarded")

        // The stacked clock reads the frozen time, one static text per line.
        XCTAssertTrue(app.staticTexts["09"].waitForExistence(timeout: 5), "hour line 09 missing")
        XCTAssertTrue(app.staticTexts["41"].exists, "minute line 41 missing")

        // The intention the user stored during onboarding.
        XCTAssertTrue(app.staticTexts["intention-line"].exists, "intention line missing")

        // The five seeded essentials, each present (installed or not).
        for slug in ["phone", "messages", "maps", "music", "photos"] {
            XCTAssertTrue(app.buttons["row-app-\(slug)"].exists, "essential row \(slug) missing")
        }

        // The ghost nav row is reachable.
        XCTAssertTrue(app.buttons["nav-focus"].isHittable)
        XCTAssertTrue(app.buttons["nav-awareness"].isHittable)
        XCTAssertTrue(app.buttons["nav-settings"].isHittable)

        attach(app, named: "HO-1")
    }

    // MARK: - (b) HO-2 — live session countdown + tap opens Focus

    @MainActor
    func testActiveSessionCountdownAndTapOpensFocus() {
        let app = launch(state: "active")

        let line = app.buttons["focus-state-line"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "focus state line missing")
        XCTAssertTrue(line.label.contains("focused ·"), "expected a live countdown, got: \(line.label)")

        attach(app, named: "HO-2")

        line.tap()

        // The Focus stub's placeholder proves we pushed, and the Home-only
        // focus line being gone proves it is the Focus screen's caption.
        XCTAssertTrue(app.staticTexts["FOCUS"].waitForExistence(timeout: 5), "Focus placeholder missing")
        XCTAssertFalse(app.buttons["focus-state-line"].exists, "still on Home after tap")
    }

    // MARK: - (c) HO-3 — nav → Settings, back returns Home

    @MainActor
    func testNavSettingsPushesAndBackReturnsHome() {
        let app = launch(state: "onboarded")

        let settings = app.buttons["nav-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        XCTAssertTrue(app.staticTexts["SETTINGS"].waitForExistence(timeout: 5), "Settings placeholder missing")
        XCTAssertFalse(element(app, "clock-display").exists, "Home clock still present after push")

        attach(app, named: "HO-3")

        // The nav bar is hidden, so pop with the interactive edge-swipe.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let finish = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: finish)

        XCTAssertTrue(element(app, "clock-display").waitForExistence(timeout: 5), "did not return Home")
    }

    // MARK: - (d) HO-6 — fresh state shows onboarding, not Home

    @MainActor
    func testFreshStateShowsOnboardingNotHome() {
        let app = launch(state: "fresh")

        // The gate holds: the Home clock never appears in a fresh install.
        XCTAssertFalse(
            element(app, "clock-display").waitForExistence(timeout: 3),
            "Home leaked past the onboarding gate"
        )

        // Onboarding is shown instead. The real flow (built concurrently)
        // exposes `step-welcome`; the interim stub exposes the ONBOARDING
        // placeholder — either proves the gate routed to onboarding.
        let welcome = element(app, "step-welcome")
        let placeholder = app.staticTexts["ONBOARDING"]
        XCTAssertTrue(welcome.exists || placeholder.exists, "onboarding root not shown")

        attach(app, named: "HO-6")
    }
}

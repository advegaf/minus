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

        // With a session running, Focus renders the active void directly.
        XCTAssertTrue(app.descendants(matching: .any)["active-session"].waitForExistence(timeout: 5), "active session screen missing")
        XCTAssertFalse(app.buttons["focus-state-line"].exists, "still on Home after tap")
    }

    // MARK: - (c) HO-3 — nav → Settings, back returns Home

    @MainActor
    func testNavSettingsPushesAndBackReturnsHome() {
        let app = launch(state: "onboarded")

        let settings = app.buttons["nav-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5), "Settings screen missing")
        XCTAssertFalse(element(app, "clock-display").exists, "Home clock still present after push")

        attach(app, named: "HO-3")

        // Hidden nav chrome disables the system edge-swipe (verified) — the
        // BackGlyph is the designed return path.
        app.buttons["nav-back"].firstMatch.tap()

        XCTAssertTrue(element(app, "clock-display").waitForExistence(timeout: 5), "did not return Home")
    }

    // MARK: - (e) CA-8 — the card pager (v1.7)

    /// Offscreen pages stay in the accessibility hierarchy (plain HStack) and
    /// SwiftUI still reports them hittable, so "which card am I on" is asserted
    /// geometrically: is the row's centre inside the window?
    @MainActor
    func testCardPagerSwipesBetweenCards() {
        let app = launch(state: "cards")
        XCTAssertTrue(app.buttons["row-app-phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(onScreen(app, app.buttons["row-app-phone"]), "card one should be showing")
        XCTAssertFalse(onScreen(app, app.buttons["row-app-slack"]), "card two must start offscreen")
        XCTAssertTrue(app.buttons["card-tab-one"].exists, "card tabs missing")
        attach(app, named: "CA-8")

        element(app, "card-pager").swipeLeft()
        XCTAssertTrue(waitOnScreen(app, app.buttons["row-app-slack"]), "swipe should reveal card two")
        XCTAssertFalse(onScreen(app, app.buttons["row-app-phone"]), "card one should have left")
        attach(app, named: "CA-8-work")

        element(app, "card-pager").swipeLeft()
        XCTAssertTrue(
            waitOnScreen(app, app.buttons["row-app-custom-pilates"]),
            "card three (custom entry) missing"
        )

        element(app, "card-pager").swipeRight()
        XCTAssertTrue(waitOnScreen(app, app.buttons["row-app-slack"]), "swipe back should return to card two")
    }

    /// Tapping a card name is the shortcut for the swipe.
    @MainActor
    func testCardTabJumpsToCard() {
        let app = launch(state: "cards")
        XCTAssertTrue(app.buttons["card-tab-weekend"].waitForExistence(timeout: 5))
        app.buttons["card-tab-weekend"].tap()
        XCTAssertTrue(
            waitOnScreen(app, app.buttons["row-app-custom-pilates"]),
            "tab tap should page to weekend"
        )
    }

    /// One card = no pager chrome at all.
    @MainActor
    func testSingleCardShowsNoTabs() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-app-phone"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "card-tabs").exists, "single card must not show pager chrome")
    }

    @MainActor
    private func onScreen(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let window = app.windows.firstMatch.frame
        let centre = CGPoint(x: element.frame.midX, y: element.frame.midY)
        return window.contains(centre)
    }

    @MainActor
    private func waitOnScreen(
        _ app: XCUIApplication,
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if onScreen(app, element) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
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

import XCTest

/// End-to-end coverage for the Home monument: the frozen clock, the intention,
/// the essentials launcher, the live focus state, and the onboarding gate.
/// Every launch pins the clock to 09:41 and runs against the in-memory store.
final class HomeUITests: XCTestCase {

    // MARK: - Launch

    @MainActor
    private func launch(
        state: String,
        freeze: String = "09:41",
        extra: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment["MINUS_STATE"] = state
        app.launchEnvironment["MINUS_FREEZE_TIME"] = freeze
        for (key, value) in extra { app.launchEnvironment[key] = value }
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
        XCTAssertTrue(element(app, "intention-line").exists, "intention line missing")

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

        // Two ways home since v1.8: the BackGlyph, and the edge swipe that
        // InteractivePopEnabler restores (covered by the swipe test below).
        app.buttons["nav-back"].firstMatch.tap()

        XCTAssertTrue(element(app, "clock-display").waitForExistence(timeout: 5), "did not return Home")
    }

    // MARK: - (e) CA-8 — the card pager (v1.7)

    /// Only the active card is built, so a card that is not showing does not
    /// A pager swipe that does not depend on XCUITest's default velocity
    /// heuristic, which under full-suite load intermittently lands short of
    /// the gesture's 24pt minimum: the pager stays put and the assertion
    /// blames the app for a flake in the harness. Still a real swipe, just
    /// with the velocity stated rather than guessed, and retried once because
    /// a dropped gesture is a harness event, not a behaviour.
    @MainActor
    private func swipePager(_ app: XCUIApplication, toLeft: Bool, until id: String) {
        for _ in 0..<3 {
            let pager = element(app, "card-pager")
            if toLeft {
                pager.swipeLeft(velocity: .fast)
            } else {
                pager.swipeRight(velocity: .fast)
            }
            if app.buttons[id].waitForExistence(timeout: 3) { return }
        }
    }

    /// exist at all. That is the point: a page can never be the wrong page.
    @MainActor
    func testCardPagerSwipesBetweenCards() {
        let app = launch(state: "cards")
        XCTAssertTrue(app.buttons["row-app-phone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["row-app-slack"].exists, "only the active card is built")
        XCTAssertTrue(app.buttons["card-tab-one"].exists, "card tabs missing")
        attach(app, named: "CA-8")

        swipePager(app, toLeft: true, until: "row-app-slack")
        XCTAssertTrue(
            app.buttons["row-app-slack"].waitForExistence(timeout: 5),
            "swipe should reveal card two"
        )
        XCTAssertFalse(app.buttons["row-app-phone"].exists, "card one should have left")
        attach(app, named: "CA-8-work")

        swipePager(app, toLeft: true, until: "row-app-custom-pilates")
        XCTAssertTrue(
            app.buttons["row-app-custom-pilates"].waitForExistence(timeout: 5),
            "card three (custom entry) missing"
        )

        swipePager(app, toLeft: false, until: "row-app-slack")
        XCTAssertTrue(
            app.buttons["row-app-slack"].waitForExistence(timeout: 5),
            "swipe back should return to card two"
        )
    }

    /// Tapping a card name is the shortcut for the swipe.
    @MainActor
    func testCardTabJumpsToCard() {
        let app = launch(state: "cards")
        XCTAssertTrue(app.buttons["card-tab-weekend"].waitForExistence(timeout: 5))
        app.buttons["card-tab-weekend"].tap()
        XCTAssertTrue(
            app.buttons["row-app-custom-pilates"].waitForExistence(timeout: 5),
            "tab tap should page to weekend"
        )
    }

    /// One card still shows its name and the "+", so the launcher's origin
    /// never moves as cards are born, and both shortcuts stay reachable.
    @MainActor
    func testSingleCardShowsItsNameAndThePlus() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-app-phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "card-tabs").exists)
        XCTAssertTrue(app.buttons["card-tab-one"].exists)
        XCTAssertTrue(app.buttons["card-tab-new"].exists)
    }

    /// v1.8: every row is live. Nothing is ever greyed out or disabled.
    @MainActor
    func testEveryLauncherRowIsTappable() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-app-phone"].waitForExistence(timeout: 5))
        for slug in ["phone", "messages", "maps", "music", "photos"] {
            let row = app.buttons["row-app-\(slug)"]
            XCTAssertTrue(row.exists, "missing row \(slug)")
            XCTAssertTrue(row.isEnabled, "row \(slug) must never be disabled")
        }
        XCTAssertFalse(app.staticTexts["not installed"].exists, "the dimming lie is gone")
    }

    /// A launch that opens nothing says what would fix it, and minus stays put.
    @MainActor
    func testFailedLaunchExplainsItselfQuietly() {
        let app = launch(state: "onboarded", extra: ["MINUS_LAUNCH": "fail"])
        let phone = app.buttons["row-app-phone"]
        XCTAssertTrue(phone.waitForExistence(timeout: 5))
        phone.tap()

        XCTAssertTrue(
            element(app, "launch-failed-phone").waitForExistence(timeout: 6),
            "a launch that opened nothing must say so"
        )
        XCTAssertEqual(app.state, .runningForeground)
        attach(app, named: "CA-9")
    }

    /// "+" makes a card and drops the user straight into its editor.
    @MainActor
    func testPlusCreatesACardAndOpensItsEditor() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["card-tab-new"].waitForExistence(timeout: 5))
        app.buttons["card-tab-new"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["settings-card-detail"].waitForExistence(timeout: 5),
            "the new card should open its own editor"
        )
        attach(app, named: "CA-10")
    }

    /// Tapping the card you are already on edits it (4 taps down to 2).
    @MainActor
    func testActiveTabOpensTheCardEditor() {
        let app = launch(state: "cards")
        XCTAssertTrue(app.buttons["card-tab-one"].waitForExistence(timeout: 5))
        app.buttons["card-tab-one"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-card-detail"].waitForExistence(timeout: 5))
    }

    /// Tapping the goal edits the goal.
    @MainActor
    func testTappingTheGoalOpensItsEditor() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(element(app, "intention-line").waitForExistence(timeout: 5))
        element(app, "intention-line").tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-intention"].waitForExistence(timeout: 5))
    }

    /// The edge swipe pops, now that the nav bar no longer has to be visible.
    @MainActor
    func testEdgeSwipeReturnsHome() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["nav-settings"].waitForExistence(timeout: 5))
        app.buttons["nav-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.004, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(
            element(app, "clock-display").waitForExistence(timeout: 5),
            "edge swipe should return Home"
        )
        attach(app, named: "NAV-1")
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

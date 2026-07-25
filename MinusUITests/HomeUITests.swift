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

import XCTest

/// End-to-end coverage of the five-step onboarding, driven entirely through the
/// mock Screen Time service. Every test launches fresh (in-memory store, clean
/// shared state) via `-UITestMode` + `MINUS_STATE=fresh`, so the onboarding gate
/// is always open. Screenshots are attached at the story beats ON-1…ON-7.
final class OnboardingUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - (a) Full happy tap-through

    @MainActor
    func testHappyPathCompletesOnboarding() {
        let app = launch()

        // Welcome — ON-1
        XCTAssertTrue(app.descendants(matching: .any)["step-welcome"].waitForExistence(timeout: 5))
        attach(app, "ON-1")
        app.buttons["cta-begin"].tap()

        // Intention — ON-2
        typeIntention(app, "an hour back each evening")
        attach(app, "ON-2")
        tapContinue(app)

        // Essentials — ON-3
        XCTAssertTrue(app.descendants(matching: .any)["step-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-phone"].tap()
        app.buttons["row-messages"].tap()
        app.buttons["row-maps"].tap()
        attach(app, "ON-3")
        tapContinue(app)

        // Permission — grant, then it auto-advances.
        XCTAssertTrue(app.buttons["cta-allow"].waitForExistence(timeout: 5))
        app.buttons["cta-allow"].tap()

        // Blocked — ON-5
        XCTAssertTrue(app.buttons["row-instagram"].waitForExistence(timeout: 6))
        app.buttons["row-instagram"].tap()
        app.buttons["row-tiktok"].tap()
        app.buttons["row-x"].tap()
        attach(app, "ON-5")
        app.buttons["cta-finish"].tap()

        // Entered the app — every onboarding step container is gone. ON-6
        XCTAssertTrue(app.descendants(matching: .any)["step-blocked"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cta-finish"].exists)
        assertNoStepContainers(app)
        attach(app, "ON-6")
    }

    // MARK: - (b) Continue is inert until there's an intention

    @MainActor
    func testContinueDisabledUntilIntentionEntered() {
        let app = launch()
        app.buttons["cta-begin"].tap()

        let field = app.textFields["field-intention"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        let cont = app.buttons["cta-continue"]
        XCTAssertTrue(cont.exists)
        XCTAssertFalse(cont.isEnabled, "CONTINUE must be disabled before any intention text")
        attach(app, "ON-2")

        field.tap()
        field.typeText("focus")
        XCTAssertTrue(cont.isEnabled, "CONTINUE must enable once the intention is non-empty")
    }

    // MARK: - (c) Denial path

    @MainActor
    func testPermissionDenialShowsRecoveryThenSkips() {
        let app = launch(extraEnv: ["MINUS_AUTH": "denied"])

        app.buttons["cta-begin"].tap()
        typeIntention(app, "quieter evenings")
        tapContinue(app)

        XCTAssertTrue(app.descendants(matching: .any)["step-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-phone"].tap()
        tapContinue(app)

        XCTAssertTrue(app.buttons["cta-allow"].waitForExistence(timeout: 5))
        app.buttons["cta-allow"].tap()

        // Denied: honest recovery copy + TRY AGAIN, no auto-advance. ON-4
        XCTAssertTrue(app.staticTexts["copy-denied"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cta-try-again"].exists)
        attach(app, "ON-4")

        // Skip carries on to the final step without shields.
        app.buttons["cta-skip-permission"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["step-blocked"].waitForExistence(timeout: 5))
    }

    // MARK: - (d) Essentials cap

    @MainActor
    func testEssentialsCapStopsAtSeven() {
        let app = launch()
        app.buttons["cta-begin"].tap()
        typeIntention(app, "room to think")
        tapContinue(app)

        XCTAssertTrue(app.descendants(matching: .any)["step-essentials"].waitForExistence(timeout: 5))

        // Fill the cap with the first seven catalog rows.
        for slug in ["phone", "messages", "facetime", "mail", "maps", "music", "photos"] {
            app.buttons["row-\(slug)"].tap()
        }
        attach(app, "ON-7")

        // The eighth row is dimmed and inert.
        let eighth = app.buttons["row-calendar"]
        XCTAssertFalse(eighth.isEnabled, "8th row must not be selectable once 7 are chosen")
        XCTAssertFalse(eighth.isSelected, "8th row must never enter the selected state at cap")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(state: String = "fresh", extraEnv: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        var env = ["MINUS_STATE": state]
        env.merge(extraEnv) { _, new in new }
        app.launchEnvironment = env
        app.launch()
        return app
    }

    @MainActor
    private func typeIntention(_ app: XCUIApplication, _ text: String) {
        let field = app.textFields["field-intention"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Trailing return resigns focus so the bottom CTA is hittable.
        field.typeText(text + "\n")
        if app.keyboards.element.exists {
            let ret = app.keyboards.buttons["return"]
            if ret.exists { ret.tap() }
        }
    }

    @MainActor
    private func tapContinue(_ app: XCUIApplication) {
        let cont = app.buttons["cta-continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 5))
        cont.tap()
    }

    @MainActor
    private func assertNoStepContainers(_ app: XCUIApplication) {
        for id in ["step-welcome", "step-intention", "step-essentials", "step-permission", "step-blocked"] {
            XCTAssertFalse(app.descendants(matching: .any)[id].exists, "\(id) should be absent after onboarding")
        }
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

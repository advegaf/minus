import XCTest

final class SettingsUITests: XCTestCase {
    @MainActor
    private func launch(state: String, extra: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        var env = ["MINUS_STATE": state, "MINUS_SCREEN": "settings", "MINUS_FREEZE_TIME": "09:41"]
        for (key, value) in extra { env[key] = value }
        app.launchEnvironment = env
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> Bool {
        app.descendants(matching: .any)[id].exists || app.staticTexts[id].exists || app.buttons[id].exists
    }

    @MainActor
    func testRootRowsAndAbout() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))
        for id in ["row-intention", "row-essentials", "row-blocked", "row-strictness", "row-permission", "row-about"] {
            XCTAssertTrue(app.buttons[id].exists, "missing \(id)")
        }
        attach(app, "SE-root")

        app.buttons["row-about"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-about"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "about-version"))
        attach(app, "SE-7")
    }

    @MainActor
    func testIntentionEditPersistsToHome() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-intention"].waitForExistence(timeout: 5))
        app.buttons["row-intention"].tap()

        let field = app.textFields["field-intention-edit"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Clear the seeded value, type a new one.
        if let existing = field.value as? String, !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count + 4))
        }
        field.typeText("walk more")
        app.buttons["cta-save-intention"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["walk more"].waitForExistence(timeout: 5))
        attach(app, "SE-1")
    }

    @MainActor
    func testStrictnessChangeAffectsActiveSession() {
        let app = launch(state: "active")
        XCTAssertTrue(app.buttons["row-strictness"].waitForExistence(timeout: 5))
        app.buttons["row-strictness"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-strictness"].waitForExistence(timeout: 5))
        app.buttons["strictness-strict"].tap()
        attach(app, "SE-5-pick")

        // Back to settings, back to home, into the active session.
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["nav-focus"].waitForExistence(timeout: 5))
        app.buttons["nav-focus"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["active-session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cta-end"].exists)
        XCTAssertTrue(app.staticTexts["strict-note"].exists)
        attach(app, "SE-5")
    }

    @MainActor
    func testPermissionRowShowsDeniedAndGrantPath() {
        let app = launch(state: "denied")
        XCTAssertTrue(app.buttons["row-permission"].waitForExistence(timeout: 5))
        app.buttons["row-permission"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-permission"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "permission-status"))
        XCTAssertTrue(app.buttons["cta-grant"].exists)
        XCTAssertTrue(app.buttons["cta-system-settings"].exists)
        attach(app, "SE-6")
    }

    @MainActor
    func testStaleBlockListShowsRecovery() {
        let app = launch(state: "onboarded", extra: ["MINUS_BLOCK": "stale"])
        XCTAssertTrue(app.buttons["row-blocked"].waitForExistence(timeout: 5))
        app.buttons["row-blocked"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-blocked"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "stale-recovery"))
        attach(app, "SE-4")

        // Re-picking clears the staleness.
        app.buttons["block-row-instagram"].tap()
        XCTAssertFalse(element(app, "stale-recovery"))
    }

    @MainActor
    func testEssentialsEditTogglesMembership() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-essentials"].waitForExistence(timeout: 5))

        // Seeded: phone, messages, maps, music, photos (5). Add calendar → 6.
        app.buttons["edit-row-calendar"].tap()
        attach(app, "SE-2")
        // Remove messages → 5.
        app.buttons["edit-row-messages"].tap()

        // Home reflects: calendar present, messages gone.
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["row-app-calendar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["row-app-messages"].exists)
    }

    @MainActor
    func testGuideShowsAllSteps() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-guide"].waitForExistence(timeout: 5))
        app.buttons["row-guide"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-guide"].waitForExistence(timeout: 5))
        for step in 1...5 {
            XCTAssertTrue(element(app, "guide-step-\(step)"), "missing guide step \(step)")
        }
        XCTAssertTrue(element(app, "guide-honesty"))
        attach(app, "SE-10")
    }

    @MainActor
    func testResetReturnsToOnboarding() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["cta-reset"].waitForExistence(timeout: 5))
        app.buttons["cta-reset"].tap()
        // Confirmation dialog buttons live in sheets/alerts space.
        let confirm = app.buttons["Reset"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["step-welcome"].waitForExistence(timeout: 5))
        attach(app, "SE-8")
    }
}

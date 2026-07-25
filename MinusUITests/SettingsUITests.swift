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
        // v1.8: the goal line is a button (tap it to edit), so assert on its label.
        let goal = app.descendants(matching: .any)["intention-line"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        XCTAssertTrue(goal.label.contains("walk more"), "goal did not persist, got: \(goal.label)")
        attach(app, "SE-1")
    }

    @MainActor
    func testIntentionPresetSavesFromEditView() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-intention"].waitForExistence(timeout: 5))
        app.buttons["row-intention"].tap()

        let preset = app.buttons["preset-one-thing"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        preset.tap()
        app.buttons["cta-save-intention"].tap()

        // Root row detail reflects the exact preset text.
        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["one thing at a time."].waitForExistence(timeout: 5))
        attach(app, "SE-1-preset")
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
    func testCardDetailTogglesMembership() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-cards"].waitForExistence(timeout: 5))
        attach(app, "SE-2-cards")

        // Card "one" (seeded: phone, messages, maps, music, photos).
        app.buttons["card-row-0"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-card-detail"].waitForExistence(timeout: 5))

        // Add calendar → 6, remove messages → 5.
        app.buttons["edit-row-calendar"].tap()
        attach(app, "SE-2")
        app.buttons["edit-row-messages"].tap()

        // Home reflects: calendar present, messages gone.
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-cards"].waitForExistence(timeout: 5))
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["row-app-calendar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["row-app-messages"].exists)
    }

    @MainActor
    func testCardsSeedStateShowsThreeCards() {
        let app = launch(state: "cards")
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-cards"].waitForExistence(timeout: 5))
        for index in 0...2 {
            XCTAssertTrue(app.buttons["card-row-\(index)"].exists, "missing card-row-\(index)")
        }
        attach(app, "CA-1")
    }

    @MainActor
    func testNewCardCreateAndDelete() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        XCTAssertTrue(app.buttons["cta-new-card"].waitForExistence(timeout: 5))
        app.buttons["cta-new-card"].tap()

        // Lands in the fresh card's detail.
        XCTAssertTrue(app.descendants(matching: .any)["settings-card-detail"].waitForExistence(timeout: 5))
        attach(app, "CA-2")

        // Delete it — confirmation, then back on the list with one card.
        app.buttons["cta-delete-card"].tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-cards"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["card-row-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["card-row-1"].exists)
        attach(app, "CA-3")
    }

    /// v1.13: the catalog covers a whole phone, so the picker has to be
    /// searchable or it is ten screens of scrolling.
    @MainActor
    func testPickerSearchFindsAndAddsAnApp() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        app.buttons["card-row-0"].tap()

        let search = app.textFields["field-app-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("oura")

        // The row the user actually came for, and the category eyebrows gone.
        let row = app.buttons["edit-row-oura"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "search did not surface oura")
        XCTAssertFalse(app.staticTexts["communication"].exists, "search should not keep browsing chrome")
        attach(app, "PK-1")
        row.tap()

        // Clearing the search returns the browse list with oura now chosen.
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        XCTAssertTrue(app.staticTexts["communication"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit-row-oura"].exists)
    }

    /// A name minus does not carry still has somewhere to go, and the typed
    /// word travels with it.
    @MainActor
    func testPickerSearchFallsThroughToAddByName() {
        let app = launch(state: "onboarded", extra: ["MINUS_SEARCH": "stub"])
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        app.buttons["card-row-0"].tap()

        let search = app.textFields["field-app-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzzqq")

        XCTAssertTrue(app.staticTexts["search-empty"].waitForExistence(timeout: 5))
        attach(app, "PK-2")
        app.buttons["cta-search-add"].tap()

        // The term carried: the add screen opens already holding it.
        let field = app.textFields["field-custom-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "zzzqq", "the typed name did not carry over")
        attach(app, "PK-3")
    }

    @MainActor
    func testCustomEntryFlow() {
        let app = launch(state: "onboarded", extra: ["MINUS_SEARCH": "stub"])
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        XCTAssertTrue(app.buttons["card-row-0"].waitForExistence(timeout: 5))
        app.buttons["card-row-0"].tap()

        XCTAssertTrue(app.buttons["cta-add-custom"].waitForExistence(timeout: 5))
        app.buttons["cta-add-custom"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-custom"].waitForExistence(timeout: 5))

        let field = app.textFields["field-custom-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Pilates")

        let match = app.buttons["app-match-com.example.pilates"]
        XCTAssertTrue(match.waitForExistence(timeout: 5), "the search never produced a match")
        attach(app, "CA-4")
        match.tap()

        // Back at the detail: the added app exists and is in the card.
        XCTAssertTrue(app.descendants(matching: .any)["settings-card-detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit-row-custom-pilates-studio"].waitForExistence(timeout: 5))
        attach(app, "CA-5")
    }

    /// A typo used to be permanent: added apps could leave a card but never
    /// the registry.
    @MainActor
    func testAddedAppCanBeRemoved() {
        let app = launch(state: "onboarded", extra: ["MINUS_SEARCH": "stub"])
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        app.buttons["card-row-0"].tap()
        XCTAssertTrue(app.buttons["cta-add-custom"].waitForExistence(timeout: 5))
        app.buttons["cta-add-custom"].tap()

        let field = app.textFields["field-custom-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Pilates")
        let match = app.buttons["app-match-com.example.pilates"]
        XCTAssertTrue(match.waitForExistence(timeout: 5))
        match.tap()

        // Back on the card: the added app is there, and so is its way out.
        let row = app.buttons["edit-row-custom-pilates-studio"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let remove = app.buttons["remove-row-custom-pilates-studio"]
        XCTAssertTrue(remove.exists, "an added app has no way out")
        attach(app, "CA-7-before")
        remove.tap()
        app.buttons["Remove"].tap()

        XCTAssertFalse(row.waitForExistence(timeout: 3), "the added app survived removal")
        attach(app, "CA-7")
    }

    /// Adding an app is the one thing in minus that needs a connection, so it
    /// is the one thing that has to say so.
    @MainActor
    func testCustomEntryOfflineCopy() {
        let app = launch(state: "onboarded", extra: ["MINUS_SEARCH": "offline"])
        XCTAssertTrue(app.buttons["row-essentials"].waitForExistence(timeout: 5))
        app.buttons["row-essentials"].tap()
        app.buttons["card-row-0"].tap()
        XCTAssertTrue(app.buttons["cta-add-custom"].waitForExistence(timeout: 5))
        app.buttons["cta-add-custom"].tap()

        let field = app.textFields["field-custom-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Pilates")

        let status = app.staticTexts["search-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("no connection"), "offline copy missing: \(status.label)")
        attach(app, "CA-6")
    }

    /// V-1: the goal can be hidden from Home and the widgets without losing it.
    @MainActor
    func testGoalVisibilityHidesIntentionOnHome() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-intention"].waitForExistence(timeout: 5))
        app.buttons["row-intention"].tap()

        XCTAssertTrue(app.buttons["intention-visibility-hidden"].waitForExistence(timeout: 5))
        app.buttons["intention-visibility-hidden"].tap()
        attach(app, "V-1")

        // Root row says "hidden"; Home drops the line but keeps the clock.
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["hidden"].waitForExistence(timeout: 5))
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["09"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["intention-line"].exists, "goal should be hidden")

        // And back on again — the text was never lost.
        app.buttons["nav-settings"].tap()
        XCTAssertTrue(app.buttons["row-intention"].waitForExistence(timeout: 5))
        app.buttons["row-intention"].tap()
        XCTAssertTrue(app.buttons["intention-visibility-shown"].waitForExistence(timeout: 5))
        app.buttons["intention-visibility-shown"].tap()
        app.buttons["nav-back"].firstMatch.tap()
        app.buttons["nav-back"].firstMatch.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["intention-line"].waitForExistence(timeout: 5),
            "goal should return"
        )
    }

    /// The seeded hidden state renders no goal anywhere on Home.
    @MainActor
    func testHiddenGoalSeedState() {
        let app = launch(state: "onboarded", extra: ["MINUS_GOAL": "hidden", "MINUS_SCREEN": ""])
        XCTAssertTrue(app.staticTexts["09"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["intention-line"].exists)
    }

    /// The shield has to mean something: mid-session the blocked list is
    /// frozen, or un-blocking an app would walk straight past the strictness
    /// gate that guards ending a session.
    @MainActor
    func testBlockedListIsLockedDuringASession() {
        let app = launch(state: "active")
        XCTAssertTrue(app.buttons["row-blocked"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["locked while focused"].exists, "the row should say so first")
        app.buttons["row-blocked"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings-blocked"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "blocked-locked"), "missing the honest lock line")
        XCTAssertFalse(app.buttons["cta-repick"].exists, "re-pick must be gone")
        XCTAssertFalse(app.buttons["block-row-instagram"].exists, "rows must not be editable")
        attach(app, "SE-14")
    }

    @MainActor
    func testGuideShowsAllSteps() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.buttons["row-guide"].waitForExistence(timeout: 5))
        app.buttons["row-guide"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-guide"].waitForExistence(timeout: 5))
        for step in 1...8 {
            XCTAssertTrue(element(app, "guide-step-\(step)"), "missing guide step \(step)")
        }
        XCTAssertTrue(element(app, "guide-honesty"))
        attach(app, "SE-10")
    }
}

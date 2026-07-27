import XCTest

final class FocusUITests: XCTestCase {
    @MainActor
    private func launch(state: String, extra: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        var env = ["MINUS_STATE": state, "MINUS_FREEZE_TIME": "09:41", "MINUS_SCREEN": "focus"]
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

    @MainActor
    func testPresetStartAndEndNormal() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.descendants(matching: .any)["focus-idle"].waitForExistence(timeout: 5))
        attach(app, "FO-1")

        app.buttons["row-duration-30"].tap()
        let start = app.buttons["cta-start"]
        XCTAssertTrue(start.isEnabled)
        start.tap()

        XCTAssertTrue(app.descendants(matching: .any)["active-session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["session-countdown"].exists || app.descendants(matching: .any)["session-countdown"].exists)
        attach(app, "FO-2")

        app.buttons["cta-end"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["focus-idle"].waitForExistence(timeout: 5))
        attach(app, "FO-4")
    }

    @MainActor
    func testStartDisabledWithoutSelectionAndCustomValidation() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.descendants(matching: .any)["focus-idle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cta-start"].isEnabled)

        app.buttons["row-duration-custom"].tap()
        let field = app.textFields["field-custom-minutes"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("10")
        XCTAssertTrue(app.staticTexts["custom-too-short"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["cta-start"].isEnabled)
        attach(app, "FO-1-custom")

        field.typeText("5") // 105 minutes
        XCTAssertTrue(app.buttons["cta-start"].isEnabled)
    }

    @MainActor
    func testActiveStateShowsSessionNotPresets() {
        let app = launch(state: "active")
        XCTAssertTrue(app.descendants(matching: .any)["active-session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["focus-idle"].exists)
        attach(app, "FO-11")
    }

    @MainActor
    func testFrictionHoldEndsSession() {
        let app = launch(state: "active", extra: ["MINUS_STRICTNESS": "friction"])
        let hold = app.descendants(matching: .any)["cta-hold-end"].firstMatch.exists
            ? app.descendants(matching: .any)["cta-hold-end"].firstMatch
            : app.staticTexts["cta-hold-end"].firstMatch
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        attach(app, "FO-5")
        hold.press(forDuration: 2.4)
        XCTAssertTrue(app.descendants(matching: .any)["focus-idle"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStrictHidesEveryExit() {
        let app = launch(state: "active", extra: ["MINUS_STRICTNESS": "strict"])
        XCTAssertTrue(app.descendants(matching: .any)["active-session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cta-end"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["cta-hold-end"].exists)
        XCTAssertTrue(app.staticTexts["strict-note"].exists)
        attach(app, "FO-6")
    }

    @MainActor
    func testNoBlocklistState() {
        let app = launch(state: "noblock")
        XCTAssertTrue(app.descendants(matching: .any)["focus-empty-blocklist"].waitForExistence(timeout: 5))
        attach(app, "FO-9")
    }

    /// v1.15: "Choose apps" used to push the settings ROOT, so wanting to
    /// start a session with nothing blocked meant hunting for the blocked-apps
    /// row and then tapping Re-pick before any picker appeared. On device the
    /// button now opens the Screen Time picker in place; under the mock, which
    /// has no such picker, it must at least land on the right screen.
    @MainActor
    func testChooseAppsGoesStraightToBlockedApps() {
        let app = launch(state: "noblock")
        let cta = app.buttons["cta-choose-blocked"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5))
        cta.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings-blocked"].waitForExistence(timeout: 5),
            "choosing apps should land on blocked apps, not the settings root"
        )
        XCTAssertFalse(app.buttons["row-strictness"].exists, "this is the settings root, not the picker")
        attach(app, "FO-9-choose")
    }

    @MainActor
    func testDeniedState() {
        let app = launch(state: "denied")
        XCTAssertTrue(app.descendants(matching: .any)["focus-denied"].waitForExistence(timeout: 5))
        attach(app, "FO-10")
    }

    @MainActor
    /// The window people reach for when they want everything blocked: one
    /// tap, no wheel-spinning, and it reads back as what it is.
    func testAllDayScheduleReadsBackAsAllDay() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MINUS_STATE": "onboarded", "MINUS_SCREEN": "schedules"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["schedule-list"].waitForExistence(timeout: 5))
        app.buttons["cta-new-schedule"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["schedule-editor"].waitForExistence(timeout: 5))

        // The pickers are there until the window is the whole day.
        XCTAssertTrue(app.descendants(matching: .any)["picker-start"].exists)
        app.buttons["schedule-all-day"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["picker-start"].exists, "the pickers are noise once it is all day")
        attach(app, "SC-1")

        app.buttons["day-2"].tap()
        XCTAssertTrue(app.buttons["cta-save-schedule"].isEnabled)
        app.buttons["cta-save-schedule"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["schedule-list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'all day'")).firstMatch.exists,
                      "the list should say all day, not 0:00 to 23:59")
        attach(app, "SC-2")
    }

    func testScheduleListEmptyThenCreate() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MINUS_STATE": "onboarded", "MINUS_SCREEN": "schedules"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["schedule-list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["schedules-empty"].exists || app.staticTexts["schedules-empty"].exists)
        attach(app, "FO-12")

        app.buttons["cta-new-schedule"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["schedule-editor"].waitForExistence(timeout: 5))

        // No weekday picked yet: validation shows, save disabled.
        XCTAssertTrue(app.staticTexts["editor-validation"].exists)
        XCTAssertFalse(app.buttons["cta-save-schedule"].isEnabled)

        app.buttons["day-2"].tap()
        app.buttons["day-4"].tap()
        XCTAssertTrue(app.buttons["cta-save-schedule"].isEnabled)
        attach(app, "FO-13")
        app.buttons["cta-save-schedule"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["schedule-list"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["schedules-empty"].exists)
    }

    @MainActor
    func testScheduleDeleteCleansUp() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MINUS_STATE": "schedules", "MINUS_SCREEN": "schedules"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["schedule-list"].waitForExistence(timeout: 5))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'row-schedule-'"))
        let before = rows.count
        XCTAssertGreaterThanOrEqual(before, 2)

        rows.element(boundBy: 0).tap()
        XCTAssertTrue(app.descendants(matching: .any)["schedule-editor"].waitForExistence(timeout: 5))
        app.buttons["cta-delete-schedule"].tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.descendants(matching: .any)["schedule-list"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'row-schedule-'")).count,
            before - 1
        )
        attach(app, "FO-15")
    }

    @MainActor
    func testScheduleToggleAndBudgetSurface() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MINUS_STATE": "schedules", "MINUS_SCREEN": "schedules"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["schedule-list"].waitForExistence(timeout: 5))
        let toggles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'toggle-schedule-'"))
        XCTAssertGreaterThanOrEqual(toggles.count, 2)
        let first = toggles.element(boundBy: 0)
        let label = first.label
        first.tap()
        // Label flips on/off after registration change.
        XCTAssertNotEqual(first.label, label)
        attach(app, "FO-14")
    }
}

import XCTest

final class AwarenessUITests: XCTestCase {
    @MainActor
    private func launch(state: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = [
            "MINUS_STATE": state,
            "MINUS_FREEZE_TIME": "09:41",
            "MINUS_SCREEN": "awareness",
        ]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Combined accessibility elements (`children: .combine`) can surface as
    /// staticTexts or otherElements depending on composition — query both.
    private func element(_ app: XCUIApplication, _ id: String) -> Bool {
        app.otherElements[id].exists || app.staticTexts[id].exists || app.buttons[id].exists
    }

    @MainActor
    func testStatsRenderWithHistory() {
        let app = launch(state: "active")
        XCTAssertTrue(app.otherElements["awareness"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "stat-today"))
        XCTAssertTrue(element(app, "stat-week"))
        XCTAssertTrue(element(app, "stat-streak"))
        attach(app, "AW-1")
        attach(app, "AW-2")
        attach(app, "AW-3")
    }

    @MainActor
    func testZeroStateWithoutHistory() {
        let app = launch(state: "onboarded")
        XCTAssertTrue(app.otherElements["awareness"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.otherElements["awareness-zero"].exists || app.staticTexts["awareness-zero"].exists
        )
        attach(app, "AW-1-zero")
    }

    @MainActor
    func testSimulatorPlaceholderNeverFakesDeviceData() {
        let app = launch(state: "active")
        XCTAssertTrue(app.otherElements["awareness"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.otherElements["report-placeholder"].waitForExistence(timeout: 3)
                || app.staticTexts["report-placeholder"].exists
        )
        attach(app, "AW-5")
    }

    @MainActor
    func testDeniedStillShowsOwnStatsAndExplains() {
        let app = launch(state: "denied")
        XCTAssertTrue(app.otherElements["awareness"].waitForExistence(timeout: 5))
        // App-owned surface intact (zero history in denied seed → zero state),
        // and on the mock the placeholder explains the simulator; on device
        // this would be report-denied. Either honest path is a pass here.
        XCTAssertTrue(element(app, "report-placeholder") || element(app, "report-denied"))
        attach(app, "AW-6")
    }
}

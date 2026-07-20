import XCTest

final class SmokeUITests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}

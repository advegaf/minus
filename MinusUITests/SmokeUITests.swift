import XCTest

final class SmokeUITests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testWidgetPreviewsRenderInGallery() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MINUS_SCREEN": "gallery", "MINUS_GALLERY_SCROLL": "widgets"]
        app.launch()

        for id in [
            "widget-preview-launcher-large",
            "widget-preview-launcher-large-small",
            "widget-preview-launcher-large-xl",
            "widget-preview-launcher-page",
            "widget-preview-launcher-page-center",
            "widget-preview-launcher-page-xl",
            "widget-preview-focus-active",
            "widget-preview-focus-next",
        ] {
            XCTAssertTrue(
                app.descendants(matching: .any)[id].waitForExistence(timeout: 5),
                "missing \(id)"
            )
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "W-1"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

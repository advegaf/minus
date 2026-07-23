import XCTest

/// The trampoline, end to end: system-initiated minus:// opens (the same URLs
/// widget Links carry), through the Springboard confirmation simctl-style
/// opens trigger, into the real bounce. Real widget taps skip the dialog —
/// this path is strictly harder than production.
final class WidgetLinkUITests: XCTestCase {
    @MainActor
    private var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    @MainActor
    private func launchOnboarded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MINUS_STATE": "onboarded", "MINUS_FREEZE_TIME": "09:41"]
        app.launch()
        return app
    }

    @MainActor
    private func openViaSystem(_ url: String) {
        XCUIDevice.shared.system.open(URL(string: url)!)
        let open = springboard.buttons["Open"]
        if open.waitForExistence(timeout: 4) {
            open.tap()
        }
    }

    @MainActor
    func testOpenEssentialTrampolinesToMessages() {
        let app = launchOnboarded()
        XCTAssertTrue(app.buttons["row-app-messages"].waitForExistence(timeout: 5))

        openViaSystem("minus://open/messages")

        let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        XCTAssertTrue(
            messages.wait(for: .runningForeground, timeout: 10),
            "trampoline should land in Messages"
        )
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "W-2"
        attachment.lifetime = .keepAlways
        add(attachment)
        messages.terminate()
    }

    @MainActor
    func testFocusLinkLandsOnFocusScreen() {
        let app = launchOnboarded()
        XCTAssertTrue(app.buttons["row-app-messages"].waitForExistence(timeout: 5))

        openViaSystem("minus://focus")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(
            app.descendants(matching: .any)["focus-idle"].waitForExistence(timeout: 5),
            "minus://focus should land on the Focus screen"
        )
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "W-7"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import XCTest

/// Captures App Store screenshots from a seeded showcase save.
/// Run explicitly (CI "screenshots" job); attachments are exported from the .xcresult.
final class ScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func tab(_ app: XCUIApplication, _ label: String) {
        let button = app.tabBars.buttons[label]
        if button.waitForExistence(timeout: 5) { button.tap() }
        else if app.buttons[label].waitForExistence(timeout: 3) { app.buttons[label].tap() }
    }

    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-showcase"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["House"].waitForExistence(timeout: 15))
        snap(app, "01-house")

        tab(app, "Me")
        snap(app, "02-me")
        if app.buttons["Wardrobe"].waitForExistence(timeout: 3) { app.buttons["Wardrobe"].tap() }
        snap(app, "03-wardrobe")

        tab(app, "Play")
        let step = app.buttons["Do Step"]
        for _ in 0..<4 where step.waitForExistence(timeout: 3) { step.tap() }
        snap(app, "04-kitchen")
        if app.buttons["Pet"].waitForExistence(timeout: 3) { app.buttons["Pet"].tap() }
        snap(app, "05-pet")
        if app.buttons["Friends"].waitForExistence(timeout: 3) { app.buttons["Friends"].tap() }
        snap(app, "06-friends")

        tab(app, "Adventures")
        snap(app, "07-adventures")
    }
}

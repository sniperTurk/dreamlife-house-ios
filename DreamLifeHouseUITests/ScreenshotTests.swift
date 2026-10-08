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

    // iPhone uses a bottom tab bar; iPadOS 26 shows a floating top tab bar whose
    // items are not always exposed as tab-bar buttons, so fall back gracefully.
    private func tab(_ app: XCUIApplication, _ label: String) {
        let candidates = [app.tabBars.buttons[label], app.buttons[label].firstMatch,
                          app.descendants(matching: .any).matching(identifier: label).firstMatch,
                          app.staticTexts[label].firstMatch]
        for element in candidates where element.waitForExistence(timeout: 2) && element.isHittable {
            element.tap(); return
        }
    }

    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-showcase"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.coins"].firstMatch.waitForExistence(timeout: 20))
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

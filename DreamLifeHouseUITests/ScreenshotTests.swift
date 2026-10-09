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
        app.launchArguments = ["--dreamlife-ui-test-showcase", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["topbar.coins"].firstMatch.waitForExistence(timeout: 20))
        snap(app, "01-house")

        // New room furniture: open the kitchen and tap the fridge so the
        // character's bilingual speech bubble is in the shot.
        let kitchenRoom = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Mutfak")).firstMatch
        if kitchenRoom.waitForExistence(timeout: 3) {
            kitchenRoom.tap()
            let fridge = app.buttons["room.furniture.kitchen.fridge"]
            if fridge.waitForExistence(timeout: 3) { fridge.tap() }
            snap(app, "01b-kitchen-room")
        }

        // Morning routine: dressing, breakfast and the farm garden.
        let start = app.buttons["routine.start"]
        if start.waitForExistence(timeout: 3) {
            start.tap()
            func tapID(_ id: String) {
                let b = app.buttons[id]
                if b.waitForExistence(timeout: 3) { b.tap() }
            }
            tapID("routine.goodMorning")
            tapID("routine.item.tshirt"); tapID("routine.item.shorts")
            sleep(1)
            snap(app, "01c-routine-dress")
            tapID("routine.item.socks"); tapID("routine.item.sneakers"); tapID("routine.item.cap")
            sleep(1)
            for food in ["egg", "bread", "cheese", "tomato"] { tapID("routine.item.\(food)") }
            sleep(1)
            snap(app, "01d-breakfast")
            tapID("routine.eat")
            _ = app.buttons["routine.garden"].waitForExistence(timeout: 15)
            tapID("routine.garden")
            tapID("farm.fruit.apple"); tapID("farm.fruit.cherry")
            tapID("farm.food.corn"); tapID("farm.animal.chicken")
            sleep(1)
            snap(app, "01e-garden")
            tapID("routine.close")
        }

        tab(app, "Ben")
        snap(app, "02-me")
        if app.buttons["Gardırop"].waitForExistence(timeout: 3) { app.buttons["Gardırop"].tap() }
        snap(app, "03-wardrobe")

        tab(app, "Oyna")
        let step = app.buttons["Adımı Yap"]
        for _ in 0..<4 where step.waitForExistence(timeout: 3) { step.tap() }
        snap(app, "04-kitchen")
        if app.buttons["Evcil Hayvan"].waitForExistence(timeout: 3) { app.buttons["Evcil Hayvan"].tap() }
        snap(app, "05-pet")
        if app.buttons["Arkadaşlar"].waitForExistence(timeout: 3) { app.buttons["Arkadaşlar"].tap() }
        snap(app, "06-friends")

        tab(app, "Maceralar")
        snap(app, "07-adventures")
    }
}

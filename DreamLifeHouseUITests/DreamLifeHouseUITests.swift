import XCTest

final class DreamLifeHouseUITests: XCTestCase {
    func testFreshPlayerCanCompleteOnboardingAndOpenHouse() {
        let app = XCUIApplication()
        app.launchArguments += ["--dreamlife-ui-test-fresh"]
        app.launch()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["Start playing"].exists)
        app.buttons["Start playing"].tap()
        XCTAssertTrue(app.tabBars.buttons["House"].waitForExistence(timeout: 10))
    }

    func testNewerSaveShowsVisibleReadOnlyWarning() {
        let app = XCUIApplication()
        app.launchArguments += ["--dreamlife-ui-test-future"]
        app.launch()

        let warning = app.descendants(matching: .any)["save.newerVersionWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        XCTAssertTrue(warning.label.contains("Changes will not be saved"))
    }

    func testExternalSessionSaveChangeShowsWarning() {
        let app = XCUIApplication()
        app.launchArguments += ["--dreamlife-ui-test-external"]
        app.launch()
        let warning = app.descendants(matching: .any)["save.externalChangeWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        XCTAssertTrue(warning.label.contains("close and reopen"))
    }

    private func openAdventures(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["Adventures"]
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
        } else {
            // iPhone may collapse the eighth tab into UIKit's More menu.
            let more = app.tabBars.buttons["More"]
            XCTAssertTrue(more.waitForExistence(timeout: 10))
            more.tap()
            let adventures = app.staticTexts["Adventures"]
            XCTAssertTrue(adventures.waitForExistence(timeout: 10))
            adventures.tap()
        }
    }

    func testLockedAdventureCannotBeClaimed() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-task-ready"]
        app.launch()
        openAdventures(in: app)
        let outfit = app.buttons["adventures.claim.outfit"]
        XCTAssertTrue(outfit.waitForExistence(timeout: 10))
        XCTAssertFalse(outfit.isEnabled)
        XCTAssertTrue(outfit.label.contains("locked"))
        XCTAssertTrue(app.descendants(matching: .any)["topbar.coins"].label.contains("500 coins"))
    }

    func testAdventureRewardClaimsOnceAndPersistsAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-task-ready"]
        app.launch()
        openAdventures(in: app)
        let claim = app.buttons["adventures.claim.dance"]
        XCTAssertTrue(claim.waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(claim.isEnabled)
        claim.tap()
        XCTAssertTrue(claim.label.contains("claimed"))
        XCTAssertFalse(claim.isEnabled)
        let coins = app.descendants(matching: .any)["topbar.coins"]
        XCTAssertTrue(coins.label.contains("620 coins"))

        app.terminate()
        app.launchArguments = ["--dreamlife-ui-test-resume"]
        app.launch()
        openAdventures(in: app)
        let persisted = app.buttons["adventures.claim.dance"]
        XCTAssertTrue(persisted.waitForExistence(timeout: 10))
        XCTAssertTrue(persisted.label.contains("claimed"))
        XCTAssertFalse(persisted.isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["topbar.coins"].label.contains("620 coins"))
    }

    func testSideSlotDecorationRewardIsReachableAndPersists() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-decor-side"]
        app.launch()
        openAdventures(in: app)
        let reward = app.buttons["adventures.claim.decorate"]
        XCTAssertTrue(reward.waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(reward.isEnabled)
        reward.tap()
        XCTAssertTrue(reward.label.contains("claimed"))
        XCTAssertTrue(app.descendants(matching: .any)["topbar.coins"].label.contains("460 coins"))
        app.terminate()
        app.launchArguments = ["--dreamlife-ui-test-resume"]
        app.launch()
        openAdventures(in: app)
        let persisted = app.buttons["adventures.claim.decorate"]
        XCTAssertTrue(persisted.waitForExistence(timeout: 10))
        XCTAssertFalse(persisted.isEnabled)
        XCTAssertTrue(persisted.label.contains("claimed"))
        XCTAssertTrue(app.descendants(matching: .any)["topbar.coins"].label.contains("460 coins"))
    }
    func testExtremeRestoredSaveStillAllowsAdventuresNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-extreme-save"]
        app.launch()
        let coins = app.descendants(matching: .any)["topbar.coins"]
        XCTAssertTrue(coins.waitForExistence(timeout: 10))
        XCTAssertTrue(coins.label.contains("1000000000 coins"))
        openAdventures(in: app)
        let next = app.buttons["adventures.nextPhase"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        XCTAssertTrue(app.staticTexts["House Adventures"].exists)
    }
    func testAmbiguousSaveConflictShowsReadOnlyWarning() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-ambiguous-save"]
        app.launch()
        let warning = app.descendants(matching: .any)["save.ambiguousRecoveryWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        XCTAssertTrue(warning.label.contains("All copies are preserved"))
        XCTAssertTrue(warning.label.contains("will not be saved"))
    }
    func testAmbiguousSaveOffersParentRecoveryExportInSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-ambiguous-save"]
        app.launch()
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let export = app.buttons["settings.exportRecovery"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        XCTAssertTrue(export.isEnabled)
        XCTAssertTrue(export.label.contains("Export preserved save copies"))
        // Do not open the system Files exporter in automation; it requires
        // user choice and must never silently share local progress.
    }

    func testTerminalSequenceSaveShowsReadOnlyWarning() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-sequence-limit"]
        app.launch()
        let warning = app.descendants(matching: .any)["save.sequenceLimitWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        XCTAssertTrue(warning.label.contains("cannot be saved"))
    }

    func testV247RecoveryExportExplainsIntegrityAndPrivacyLimits() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-ambiguous-save"]
        app.launch()
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "not encrypted or tamper-proof")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings.exportRecovery"].exists)
    }

    func testV248RecoveryPreviewListsConflictingCopySummaries() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-ambiguous-save"]
        app.launch()
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let primary = app.descendants(matching: .any)["settings.recoveryPreview.primary"]
        let backup = app.descendants(matching: .any)["settings.recoveryPreview.backup"]
        let pending = app.descendants(matching: .any)["settings.recoveryPreview.pending"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertTrue(backup.exists)
        XCTAssertTrue(pending.exists)
        XCTAssertTrue(primary.label.contains("No copy present"))
        XCTAssertTrue(backup.label.contains("880 coins"))
        XCTAssertTrue(pending.label.contains("640 coins"))
        XCTAssertTrue(app.buttons["settings.exportRecovery"].exists)
        // Read-only inspection must not trigger the Files exporter or a restore.
    }

    func testV250EqualPrimaryPendingConflictPreservesJournalInParentPreview() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-equal-primary-pending"]
        app.launch()
        let warning = app.descendants(matching: .any)["save.ambiguousRecoveryWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let primary = app.descendants(matching: .any)["settings.recoveryPreview.primary"]
        let backup = app.descendants(matching: .any)["settings.recoveryPreview.backup"]
        let pending = app.descendants(matching: .any)["settings.recoveryPreview.pending"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertTrue(backup.exists)
        XCTAssertTrue(pending.exists)
        XCTAssertTrue(primary.label.contains("880 coins"))
        XCTAssertTrue(backup.label.contains("No copy present"))
        XCTAssertTrue(pending.label.contains("640 coins"))
        XCTAssertTrue(app.buttons["settings.exportRecovery"].exists)
    }

    func testV249EqualPrimaryBackupWithoutJournalShowsReadOnlyRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-equal-primary-backup"]
        app.launch()
        let warning = app.descendants(matching: .any)["save.ambiguousRecoveryWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let primary = app.descendants(matching: .any)["settings.recoveryPreview.primary"]
        let backup = app.descendants(matching: .any)["settings.recoveryPreview.backup"]
        let pending = app.descendants(matching: .any)["settings.recoveryPreview.pending"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertTrue(backup.exists)
        XCTAssertTrue(pending.exists)
        XCTAssertTrue(primary.label.contains("880 coins"))
        XCTAssertTrue(backup.label.contains("640 coins"))
        XCTAssertTrue(pending.label.contains("No copy present"))
        XCTAssertTrue(app.buttons["settings.exportRecovery"].exists)
    }


    func testV251ThreeWayRecoveryConflictKeepsAllCopiesVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-equal-backup-with-pending"]
        app.launch()
        let warning = app.descendants(matching: .any)["save.ambiguousRecoveryWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let primary = app.descendants(matching: .any)["settings.recoveryPreview.primary"]
        let backup = app.descendants(matching: .any)["settings.recoveryPreview.backup"]
        let pending = app.descendants(matching: .any)["settings.recoveryPreview.pending"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertTrue(backup.exists)
        XCTAssertTrue(pending.exists)
        XCTAssertTrue(primary.label.contains("880 coins"))
        XCTAssertTrue(backup.label.contains("640 coins"))
        XCTAssertTrue(pending.label.contains("510 coins"))
        XCTAssertTrue(app.buttons["settings.exportRecovery"].exists)
    }

    func testV252RecoveryInspectionCanBeRefreshed() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-equal-backup-with-pending"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["save.ambiguousRecoveryWarning"]
            .waitForExistence(timeout: 10))
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let refresh = app.buttons["settings.refreshRecoveryInspection"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings.exportRecovery"].isEnabled)
        refresh.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.recoveryPreview.primary"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.recoveryPreview.backup"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.recoveryPreview.pending"].exists)
        XCTAssertTrue(app.buttons["settings.exportRecovery"].isEnabled)
    }

    func testV253ParentPreviewDistinguishesExactCopies() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-matching-copies"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["save.ambiguousRecoveryWarning"]
            .waitForExistence(timeout: 10))
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let primary = app.descendants(matching: .any)["settings.recoveryPreview.primary"]
        let backup = app.descendants(matching: .any)["settings.recoveryPreview.backup"]
        let pending = app.descendants(matching: .any)["settings.recoveryPreview.pending"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertTrue(backup.exists)
        XCTAssertTrue(pending.exists)
        XCTAssertTrue(primary.label.contains("No other copy has identical bytes"))
        XCTAssertTrue(backup.label.contains("Exact bytes match Pending copy"))
        XCTAssertTrue(pending.label.contains("Exact bytes match Backup copy"))
        XCTAssertTrue(app.buttons["settings.exportRecovery"].isEnabled)
    }


    func testV254ParentRecoveryOverviewAndPrivateExportConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--dreamlife-ui-test-matching-copies"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["save.ambiguousRecoveryWarning"]
            .waitForExistence(timeout: 10))
        let more = app.tabBars.buttons["More"]
        if more.waitForExistence(timeout: 3) {
            more.tap()
            let settings = app.staticTexts["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        } else {
            let settings = app.tabBars.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 10))
            settings.tap()
        }
        let summary = app.descendants(matching: .any)["settings.recoverySummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("3 of 3 copies present"))
        XCTAssertTrue(summary.label.contains("2 distinct byte versions"))
        let export = app.buttons["settings.exportRecovery"]
        XCTAssertTrue(export.isEnabled)
        export.tap()
        let confirmation = app.buttons["settings.confirmRecoveryExport"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "not encrypted")).firstMatch.exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(export.isEnabled)
        XCTAssertFalse(confirmation.exists)
    }

}

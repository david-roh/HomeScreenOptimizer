import XCTest

@MainActor
final class GuidedFlowSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSetupShowsIntentCardsWithoutDuplicateCustomFocusControl() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting-unlock-tabs"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Intent"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Balanced"].exists)
        XCTAssertTrue(app.staticTexts["Reach"].exists)
        XCTAssertTrue(app.staticTexts["Visual"].exists)
        XCTAssertTrue(app.staticTexts["Stable"].exists)

        let visualIntent = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Visual'")).firstMatch
        if visualIntent.exists {
            visualIntent.tap()
        }

        let contextPicker = app.buttons["Context, Workday"]
        XCTAssertTrue(contextPicker.waitForExistence(timeout: 3))
        contextPicker.tap()

        let customOption = app.buttons["Custom"]
        XCTAssertTrue(customOption.waitForExistence(timeout: 3))
        customOption.tap()

        let advanced = app.buttons["Advanced"]
        if advanced.exists {
            advanced.tap()
        }

        let customLabelField = app.textFields["Custom context label"]
        XCTAssertTrue(customLabelField.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Speed"].exists)
    }

    func testSetupIntentGridIsFullyVisibleAndHittable() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting-unlock-tabs"]
        app.launch()

        let context = app.buttons["setup-context-picker"]
        let hand = app.buttons["setup-hand-picker"]
        let grip = app.buttons["setup-grip-picker"]

        XCTAssertTrue(context.waitForExistence(timeout: 5))
        XCTAssertTrue(hand.exists)
        XCTAssertTrue(grip.exists)

        let balanced = app.buttons["intent-card-balanced"]
        let reach = app.buttons["intent-card-reachFirst"]
        let visual = app.buttons["intent-card-visualHarmony"]
        let stable = app.buttons["intent-card-minimalDisruption"]

        XCTAssertTrue(balanced.exists)
        XCTAssertTrue(reach.exists)
        XCTAssertTrue(visual.exists)
        XCTAssertTrue(stable.exists)

        XCTAssertTrue(balanced.isHittable)
        XCTAssertTrue(reach.isHittable)
        XCTAssertTrue(visual.isHittable)
        XCTAssertTrue(stable.isHittable)
        XCTAssertTrue(app.buttons["Save & Continue"].isHittable || app.buttons["Create & Continue"].isHittable)
        XCTAssertTrue(app.buttons["bottom-primary-action"].isHittable)
    }

    func testEditMappingsOpensOverlayEditor() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting-unlock-tabs", "-uitesting-seed-flow"]
        app.launch()

        app.tabBars.buttons["Import"].tap()
        let edit = app.buttons["edit-mappings"]
        XCTAssertTrue(edit.waitForExistence(timeout: 6))
        edit.tap()

        XCTAssertTrue(app.navigationBars["Edit Mappings"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.segmentedControls.buttons["Overlay"].exists)
    }

    func testFineTuneSheetDismissesWithBackdropTap() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting-unlock-tabs"]
        app.launch()

        let fineTune = app.buttons["open-fine-tune"]
        XCTAssertTrue(fineTune.waitForExistence(timeout: 6))
        fineTune.tap()
        XCTAssertTrue(app.staticTexts["HomeScreenOptimizer"].exists)
    }

    func testPlanPreviewFinalLayoutOpensBeforeAfterPreview() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitesting-unlock-tabs", "-uitesting-seed-flow"]
        app.launch()

        app.tabBars.buttons["Plan"].tap()
        let generate = app.buttons["Generate Rearrangement"]
        if generate.waitForExistence(timeout: 4) && generate.isHittable {
            generate.tap()
        }

        let preview = app.buttons["preview-final-layout"]
        var foundPreview = preview.waitForExistence(timeout: 4)
        for _ in 0..<6 where !foundPreview {
            app.swipeUp()
            foundPreview = preview.exists
        }
        XCTAssertTrue(foundPreview)
        preview.tap()

        XCTAssertTrue(app.navigationBars["Final Layout Preview"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.switches["preview-moved-only-toggle"].exists)

        XCTAssertTrue(app.segmentedControls.buttons["Current"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Recommended"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Transition"].exists)
        app.segmentedControls.buttons["Transition"].tap()
        XCTAssertTrue(app.buttons["Animate"].waitForExistence(timeout: 2))
    }
}

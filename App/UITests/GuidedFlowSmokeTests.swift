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

        let customLabelField = app.textFields["Custom context label"]
        XCTAssertTrue(customLabelField.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Speed"].exists)
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
    }
}

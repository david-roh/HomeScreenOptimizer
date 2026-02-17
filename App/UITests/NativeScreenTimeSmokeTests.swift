import XCTest

@MainActor
final class NativeScreenTimeSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRecommendationSectionShowsScreenTimeControls() {
        let app = XCUIApplication()
        app.launchArguments.append("-uitesting-unlock-tabs")
        app.launch()

        XCTAssertTrue(app.buttons["bottom-primary-action"].waitForExistence(timeout: 8))

        let planStage = app.buttons["Plan"].firstMatch
        if planStage.waitForExistence(timeout: 3) {
            planStage.tap()
        } else {
            for _ in 0..<3 where app.buttons["bottom-primary-action"].isHittable {
                app.buttons["bottom-primary-action"].tap()
            }
        }

        let connectButton = app.buttons["Connect Screen Time"]
        let refreshButton = app.buttons["Refresh Access"]
        let manualUsageToggle = app.switches["manual-usage-toggle"]

        var foundControls = connectButton.exists || refreshButton.exists
        var foundToggle = manualUsageToggle.exists

        for _ in 0..<4 where !foundControls || !foundToggle {
            app.swipeUp()
            foundControls = connectButton.exists || refreshButton.exists
            foundToggle = manualUsageToggle.exists
        }

        XCTAssertTrue(foundControls, "Expected native Screen Time connect/refresh control in Recommendation Guide.")
        XCTAssertTrue(foundToggle, "Expected manual usage toggle in Recommendation Guide.")
    }
}

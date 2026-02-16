import XCTest

@MainActor
final class NativeScreenTimeSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRecommendationSectionShowsScreenTimeControls() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["HomeScreenOptimizer"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Plan"].tap()

        let connectButton = app.buttons["Connect Screen Time"]
        let refreshButton = app.buttons["Refresh Access"]
        let manualUsageToggle = app.switches["Use manual usage input"]

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

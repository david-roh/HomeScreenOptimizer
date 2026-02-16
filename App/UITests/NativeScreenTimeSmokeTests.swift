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

        let connectButton = app.buttons["Connect Screen Time"]
        let refreshButton = app.buttons["Refresh Screen Time Access"]
        let manualUsageToggle = app.switches["Use manual usage input"]

        var foundControls = connectButton.exists || refreshButton.exists
        var foundToggle = manualUsageToggle.exists
        var attempts = 0

        while (!foundControls || !foundToggle) && attempts < 12 {
            app.swipeUp()
            foundControls = connectButton.exists || refreshButton.exists
            foundToggle = manualUsageToggle.exists
            attempts += 1
        }

        XCTAssertTrue(foundControls, "Expected native Screen Time connect/refresh control in Recommendation Guide.")
        XCTAssertTrue(foundToggle, "Expected manual usage toggle in Recommendation Guide.")
    }
}

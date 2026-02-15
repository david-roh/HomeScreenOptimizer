import Core
import XCTest

final class HomeScreenOptimizeriOSTests: XCTestCase {
    func testGoalWeightsDefaultSumsToOne() {
        let sum = GoalWeights.default.utility
            + GoalWeights.default.flow
            + GoalWeights.default.aesthetics
            + GoalWeights.default.moveCost

        XCTAssertEqual(sum, 1.0, accuracy: 0.0001)
    }
}

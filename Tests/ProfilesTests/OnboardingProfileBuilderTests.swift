import Core
import Profiles
import XCTest

final class OnboardingProfileBuilderTests: XCTestCase {
    func testBuildProfileUsesDefaultsWhenNameEmptyAndNormalizesWeights() {
        let builder = OnboardingProfileBuilder()

        let profile = builder.buildProfile(from: OnboardingAnswers(
            preferredName: "   ",
            context: .weekend,
            handedness: .left,
            gripMode: .oneHand,
            goalWeights: GoalWeights(utility: 2, flow: 2, aesthetics: 2, moveCost: 2)
        ))

        XCTAssertEqual(profile.name, "Weekend")
        XCTAssertEqual(profile.handedness, .left)
        XCTAssertEqual(profile.gripMode, .oneHand)

        let sum = profile.goalWeights.utility
            + profile.goalWeights.flow
            + profile.goalWeights.aesthetics
            + profile.goalWeights.moveCost
        XCTAssertEqual(sum, 1.0, accuracy: 0.0001)
    }
}

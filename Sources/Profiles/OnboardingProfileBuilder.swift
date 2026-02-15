import Core
import Foundation

public struct OnboardingAnswers: Sendable {
    public var preferredName: String
    public var context: ProfileContext
    public var handedness: Handedness
    public var gripMode: GripMode
    public var goalWeights: GoalWeights

    public init(
        preferredName: String,
        context: ProfileContext,
        handedness: Handedness,
        gripMode: GripMode,
        goalWeights: GoalWeights = .default
    ) {
        self.preferredName = preferredName
        self.context = context
        self.handedness = handedness
        self.gripMode = gripMode
        self.goalWeights = goalWeights
    }
}

public protocol ProfileBuilding: Sendable {
    func buildProfile(from answers: OnboardingAnswers) -> Profile
}

public struct OnboardingProfileBuilder: ProfileBuilding {
    public init() {}

    public func buildProfile(from answers: OnboardingAnswers) -> Profile {
        let trimmedName = answers.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? defaultName(for: answers.context) : trimmedName

        return Profile(
            name: resolvedName,
            context: answers.context,
            handedness: answers.handedness,
            gripMode: answers.gripMode,
            goalWeights: normalize(weights: answers.goalWeights)
        )
    }

    private func defaultName(for context: ProfileContext) -> String {
        switch context {
        case .workday:
            return "Workday"
        case .weekend:
            return "Weekend"
        case .custom:
            return "My Profile"
        }
    }

    private func normalize(weights: GoalWeights) -> GoalWeights {
        let sum = max(weights.utility + weights.flow + weights.aesthetics + weights.moveCost, 0.0001)

        return GoalWeights(
            utility: weights.utility / sum,
            flow: weights.flow / sum,
            aesthetics: weights.aesthetics / sum,
            moveCost: weights.moveCost / sum
        )
    }
}

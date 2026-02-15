import Core
import Foundation

public struct LayoutScoringContext: Sendable {
    public var usageByApp: [UUID: Double]
    public var reachabilityBySlot: [Slot: Double]

    public init(usageByApp: [UUID: Double], reachabilityBySlot: [Slot: Double]) {
        self.usageByApp = usageByApp
        self.reachabilityBySlot = reachabilityBySlot
    }
}

public struct LayoutScorer {
    public init() {}

    public func score(assignments: [LayoutAssignment], weights: GoalWeights, context: LayoutScoringContext) -> ScoreBreakdown {
        var utility = 0.0
        for assignment in assignments {
            let usage = context.usageByApp[assignment.appID] ?? 0.0
            let reach = context.reachabilityBySlot[assignment.slot] ?? 0.0
            utility += usage * reach
        }

        return ScoreBreakdown(
            utilityScore: utility * weights.utility,
            flowScore: 0 * weights.flow,
            aestheticScore: 0 * weights.aesthetics,
            moveCostPenalty: 0 * weights.moveCost
        )
    }
}

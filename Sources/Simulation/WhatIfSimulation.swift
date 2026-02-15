import Core
import Foundation

public struct SimulationSummary: Codable, Hashable, Sendable {
    public var aggregateScoreDelta: Double
    public var moveCount: Int

    public init(aggregateScoreDelta: Double, moveCount: Int) {
        self.aggregateScoreDelta = aggregateScoreDelta
        self.moveCount = moveCount
    }
}

public struct WhatIfSimulation {
    public init() {}

    public func compare(currentScore: ScoreBreakdown, candidateScore: ScoreBreakdown, moveCount: Int) -> SimulationSummary {
        SimulationSummary(
            aggregateScoreDelta: candidateScore.aggregateScore - currentScore.aggregateScore,
            moveCount: moveCount
        )
    }
}

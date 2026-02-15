import Foundation

public struct LayoutAssignment: Codable, Hashable, Sendable {
    public var appID: UUID
    public var slot: Slot

    public init(appID: UUID, slot: Slot) {
        self.appID = appID
        self.slot = slot
    }
}

public struct ScoreBreakdown: Codable, Hashable, Sendable {
    public var utilityScore: Double
    public var flowScore: Double
    public var aestheticScore: Double
    public var moveCostPenalty: Double

    public init(utilityScore: Double, flowScore: Double, aestheticScore: Double, moveCostPenalty: Double) {
        self.utilityScore = utilityScore
        self.flowScore = flowScore
        self.aestheticScore = aestheticScore
        self.moveCostPenalty = moveCostPenalty
    }

    public var aggregateScore: Double {
        utilityScore + flowScore + aestheticScore - moveCostPenalty
    }
}

public struct LayoutPlan: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public var assignments: [LayoutAssignment]
    public var scoreBreakdown: ScoreBreakdown
    public var generatedAt: Date

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        assignments: [LayoutAssignment],
        scoreBreakdown: ScoreBreakdown,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.profileID = profileID
        self.assignments = assignments
        self.scoreBreakdown = scoreBreakdown
        self.generatedAt = generatedAt
    }
}

public struct MoveStep: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var appID: UUID
    public var fromSlot: Slot
    public var toSlot: Slot
    public var dependsOnStepID: UUID?

    public init(
        id: UUID = UUID(),
        appID: UUID,
        fromSlot: Slot,
        toSlot: Slot,
        dependsOnStepID: UUID? = nil
    ) {
        self.id = id
        self.appID = appID
        self.fromSlot = fromSlot
        self.toSlot = toSlot
        self.dependsOnStepID = dependsOnStepID
    }
}

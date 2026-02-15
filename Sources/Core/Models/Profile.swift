import Foundation

public enum Handedness: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case alternating
}

public enum GripMode: String, Codable, CaseIterable, Sendable {
    case oneHand
    case twoHand
}

public enum ProfileContext: String, Codable, CaseIterable, Sendable {
    case workday
    case weekend
    case custom
}

public struct GoalWeights: Codable, Hashable, Sendable {
    public var utility: Double
    public var flow: Double
    public var aesthetics: Double
    public var moveCost: Double

    public init(utility: Double, flow: Double, aesthetics: Double, moveCost: Double) {
        self.utility = utility
        self.flow = flow
        self.aesthetics = aesthetics
        self.moveCost = moveCost
    }

    public static let `default` = GoalWeights(utility: 0.45, flow: 0.20, aesthetics: 0.20, moveCost: 0.15)
}

public struct ReachabilityMap: Codable, Hashable, Sendable {
    public var slotWeights: [Slot: Double]

    public init(slotWeights: [Slot: Double] = [:]) {
        self.slotWeights = slotWeights
    }
}

public struct Profile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var context: ProfileContext
    public var handedness: Handedness
    public var gripMode: GripMode
    public var goalWeights: GoalWeights
    public var reachabilityMap: ReachabilityMap
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        context: ProfileContext,
        handedness: Handedness,
        gripMode: GripMode,
        goalWeights: GoalWeights = .default,
        reachabilityMap: ReachabilityMap = ReachabilityMap(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.context = context
        self.handedness = handedness
        self.gripMode = gripMode
        self.goalWeights = goalWeights
        self.reachabilityMap = reachabilityMap
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

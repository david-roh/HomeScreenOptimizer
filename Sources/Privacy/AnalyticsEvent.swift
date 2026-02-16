import Foundation

public enum AnalyticsEventName: String, Codable, Hashable, Sendable {
    case guideGenerated = "guide_generated"
    case guidedApplyStarted = "guided_apply_started"
    case guidedApplyStepCompleted = "guided_apply_step_completed"
    case guidedApplyReset = "guided_apply_reset"
    case guidedApplyCompleted = "guided_apply_completed"
    case historyCompared = "history_compared"
}

public struct AnalyticsEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: AnalyticsEventName
    public var profileID: UUID?
    public var planID: UUID?
    public var stepID: UUID?
    public var payload: [String: String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: AnalyticsEventName,
        profileID: UUID? = nil,
        planID: UUID? = nil,
        stepID: UUID? = nil,
        payload: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.profileID = profileID
        self.planID = planID
        self.stepID = stepID
        self.payload = payload
        self.createdAt = createdAt
    }
}

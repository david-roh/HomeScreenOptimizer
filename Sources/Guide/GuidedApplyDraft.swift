import Core
import Foundation

public struct GuidedApplyDraft: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var planID: UUID
    public var currentAssignments: [LayoutAssignment]
    public var recommendedAssignments: [LayoutAssignment]
    public var moveSteps: [MoveStep]
    public var appNamesByID: [UUID: String]
    public var completedStepIDs: Set<UUID>
    public var updatedAt: Date

    public init(
        profileID: UUID,
        planID: UUID,
        currentAssignments: [LayoutAssignment],
        recommendedAssignments: [LayoutAssignment],
        moveSteps: [MoveStep],
        appNamesByID: [UUID: String],
        completedStepIDs: Set<UUID> = [],
        updatedAt: Date = Date()
    ) {
        id = profileID
        self.planID = planID
        self.currentAssignments = currentAssignments
        self.recommendedAssignments = recommendedAssignments
        self.moveSteps = moveSteps
        self.appNamesByID = appNamesByID
        self.completedStepIDs = completedStepIDs
        self.updatedAt = updatedAt
    }

    public var profileID: UUID {
        id
    }
}

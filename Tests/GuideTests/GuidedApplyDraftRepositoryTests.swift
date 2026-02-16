import Core
import Foundation
import Guide
import XCTest

final class GuidedApplyDraftRepositoryTests: XCTestCase {
    func testCRUDByProfileID() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("guided-apply-drafts-\(UUID().uuidString).json")
        let repository = FileGuidedApplyDraftRepository(fileURL: fileURL)

        let profileID = UUID()
        let appID = UUID()
        let step = MoveStep(
            appID: appID,
            fromSlot: Slot(page: 0, row: 0, column: 0),
            toSlot: Slot(page: 0, row: 5, column: 3)
        )

        var draft = GuidedApplyDraft(
            profileID: profileID,
            planID: UUID(),
            currentAssignments: [LayoutAssignment(appID: appID, slot: step.fromSlot)],
            recommendedAssignments: [LayoutAssignment(appID: appID, slot: step.toSlot)],
            moveSteps: [step],
            appNamesByID: [appID: "Maps"]
        )

        try repository.upsert(draft)
        let fetched = try repository.fetch(profileID: profileID)
        XCTAssertEqual(fetched?.moveSteps.count, 1)

        draft.completedStepIDs = [step.id]
        try repository.upsert(draft)
        let fetchedAfterUpdate = try repository.fetch(profileID: profileID)
        XCTAssertEqual(fetchedAfterUpdate?.completedStepIDs.contains(step.id), true)

        try repository.delete(profileID: profileID)
        XCTAssertNil(try repository.fetch(profileID: profileID))
    }
}

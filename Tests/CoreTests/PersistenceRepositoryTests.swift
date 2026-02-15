import Core
import Foundation
import XCTest

final class PersistenceRepositoryTests: XCTestCase {
    func testFileProfileRepositoryCRUD() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("profiles-\(UUID().uuidString).json")

        let repository = FileProfileRepository(fileURL: fileURL)
        let profile = Profile(name: "Workday", context: .workday, handedness: .right, gripMode: .oneHand)

        try repository.upsert(profile)

        let fetched = try repository.fetch(id: profile.id)
        XCTAssertEqual(fetched?.id, profile.id)

        var updated = profile
        updated.name = "Weekend"
        try repository.upsert(updated)

        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Weekend")

        try repository.delete(id: profile.id)
        let empty = try repository.fetchAll()
        XCTAssertTrue(empty.isEmpty)
    }

    func testFileLayoutPlanRepositoryCRUD() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("plans-\(UUID().uuidString).json")

        let repository = FileLayoutPlanRepository(fileURL: fileURL)
        let profileID = UUID()
        let appID = UUID()

        let plan = LayoutPlan(
            profileID: profileID,
            assignments: [LayoutAssignment(appID: appID, slot: Slot(page: 0, row: 0, column: 0))],
            scoreBreakdown: ScoreBreakdown(utilityScore: 1, flowScore: 0, aestheticScore: 0, moveCostPenalty: 0)
        )

        try repository.upsert(plan)

        let fetched = try repository.fetch(id: plan.id)
        XCTAssertEqual(fetched?.id, plan.id)

        let filtered = try repository.fetchAll(for: profileID)
        XCTAssertEqual(filtered.count, 1)

        try repository.delete(id: plan.id)
        XCTAssertTrue(try repository.fetchAll(for: nil).isEmpty)
    }
}

import Privacy
import XCTest

final class AnalyticsEventRepositoryTests: XCTestCase {
    func testAppendFetchLimitAndDeleteAll() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("analytics-events-\(UUID().uuidString).json")
        let repository = FileAnalyticsEventRepository(fileURL: fileURL)

        let first = AnalyticsEvent(
            name: .guideGenerated,
            profileID: UUID(),
            planID: UUID(),
            payload: ["move_count": "4"],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let second = AnalyticsEvent(
            name: .guidedApplyCompleted,
            profileID: first.profileID,
            planID: first.planID,
            payload: ["completed_count": "4"],
            createdAt: Date(timeIntervalSince1970: 2)
        )

        try repository.append(first)
        try repository.append(second)

        let all = try repository.fetchAll(limit: nil)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.name, .guidedApplyCompleted)

        let limited = try repository.fetchAll(limit: 1)
        XCTAssertEqual(limited.count, 1)
        XCTAssertEqual(limited.first?.id, second.id)

        try repository.deleteAll()
        XCTAssertTrue(try repository.fetchAll(limit: nil).isEmpty)
    }
}

import Core
import Foundation
import XCTest

final class ModelRoundTripTests: XCTestCase {
    func testAppItemRoundTripPreservesValues() throws {
        let item = AppItem(
            id: UUID(),
            bundleIdentifier: "com.example.app",
            displayName: "Example",
            category: "Social",
            dominantColorHex: "#FF00AA",
            usageScore: 0.82
        )

        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(AppItem.self, from: encoded)

        XCTAssertEqual(decoded, item)
    }

    func testLayoutPlanRoundTripPreservesAssignments() throws {
        let appID = UUID()
        let plan = LayoutPlan(
            profileID: UUID(),
            assignments: [LayoutAssignment(appID: appID, slot: Slot(page: 0, row: 3, column: 2))],
            scoreBreakdown: ScoreBreakdown(utilityScore: 0.5, flowScore: 0.2, aestheticScore: 0.1, moveCostPenalty: 0.05)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoded = try encoder.encode(plan)
        let decoded = try decoder.decode(LayoutPlan.self, from: encoded)

        XCTAssertEqual(decoded.assignments.count, 1)
        XCTAssertEqual(decoded.scoreBreakdown.aggregateScore, plan.scoreBreakdown.aggregateScore, accuracy: 0.0001)
    }
}

import Core
import Optimizer
import XCTest

final class ReachabilityAwareLayoutPlannerTests: XCTestCase {
    func testGenerateAssignsHighestUsageToMostReachableSlotForRightOneHand() {
        let planner = ReachabilityAwareLayoutPlanner()
        let profile = Profile(
            name: "Right One-Hand",
            context: .workday,
            handedness: .right,
            gripMode: .oneHand
        )

        let topLeft = Slot(page: 0, row: 0, column: 0)
        let bottomRight = Slot(page: 0, row: 5, column: 3)

        let highUse = AppItem(displayName: "Messages", usageScore: 0.95)
        let lowUse = AppItem(displayName: "Calendar", usageScore: 0.10)

        let current = [
            LayoutAssignment(appID: highUse.id, slot: topLeft),
            LayoutAssignment(appID: lowUse.id, slot: bottomRight)
        ]

        let result = planner.generate(profile: profile, apps: [highUse, lowUse], currentAssignments: current)
        let assignedSlot = result.recommendedPlan.assignments.first { $0.appID == highUse.id }?.slot

        XCTAssertEqual(assignedSlot, bottomRight)
    }

    func testGenerateUsesCalibrationMapWhenAvailable() {
        let planner = ReachabilityAwareLayoutPlanner()
        let calibratedSlot = Slot(page: 0, row: 0, column: 0)
        let lowWeightSlot = Slot(page: 0, row: 5, column: 3)

        let profile = Profile(
            name: "Calibrated",
            context: .workday,
            handedness: .right,
            gripMode: .oneHand,
            reachabilityMap: ReachabilityMap(slotWeights: [
                calibratedSlot: 1.0,
                lowWeightSlot: 0.1
            ])
        )

        let highUse = AppItem(displayName: "Mail", usageScore: 1.0)
        let lowUse = AppItem(displayName: "Clock", usageScore: 0.05)

        let current = [
            LayoutAssignment(appID: highUse.id, slot: lowWeightSlot),
            LayoutAssignment(appID: lowUse.id, slot: calibratedSlot)
        ]

        let result = planner.generate(profile: profile, apps: [highUse, lowUse], currentAssignments: current)
        let assignedSlot = result.recommendedPlan.assignments.first { $0.appID == highUse.id }?.slot

        XCTAssertEqual(assignedSlot, calibratedSlot)
    }

    func testGenerateImprovesOrPreservesAggregateScore() {
        let planner = ReachabilityAwareLayoutPlanner()
        let profile = Profile(
            name: "Scoring",
            context: .workday,
            handedness: .right,
            gripMode: .oneHand
        )

        let slots = [
            Slot(page: 0, row: 0, column: 0),
            Slot(page: 0, row: 5, column: 3),
            Slot(page: 0, row: 4, column: 2)
        ]

        let apps = [
            AppItem(displayName: "A", usageScore: 0.9),
            AppItem(displayName: "B", usageScore: 0.6),
            AppItem(displayName: "C", usageScore: 0.2)
        ]

        let current = zip(apps, slots).map { app, slot in
            LayoutAssignment(appID: app.id, slot: slot)
        }

        let result = planner.generate(profile: profile, apps: apps, currentAssignments: current)

        XCTAssertGreaterThanOrEqual(
            result.recommendedPlan.scoreBreakdown.aggregateScore,
            result.currentScore.aggregateScore
        )
    }
}

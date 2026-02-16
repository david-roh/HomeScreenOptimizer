import Core
@testable import HomeScreenOptimizeriOS
import XCTest

final class GuidedFlowModelsTests: XCTestCase {
    func testProfileNameResolverGeneratesWorkdayDefaultAndDedupes() {
        let resolver = ProfileNameResolver(
            existingNames: [
                "Workday · Right · One-Hand",
                "Workday · Right · One-Hand #2"
            ]
        )

        let resolved = resolver.resolve(
            typedName: "",
            context: .workday,
            customContextLabel: "",
            handedness: .right,
            gripMode: .oneHand
        )

        XCTAssertEqual(resolved, "Workday · Right · One-Hand #3")
    }

    func testProfileNameResolverUsesCustomLabelOrFallback() {
        let resolver = ProfileNameResolver(existingNames: [])

        let labeled = resolver.resolve(
            typedName: "",
            context: .custom,
            customContextLabel: "Commute",
            handedness: .left,
            gripMode: .twoHand
        )
        let fallback = resolver.resolve(
            typedName: "",
            context: .custom,
            customContextLabel: "  ",
            handedness: .left,
            gripMode: .twoHand
        )

        XCTAssertEqual(labeled, "Commute · Left · Two-Hand")
        XCTAssertEqual(fallback, "Custom · Left · Two-Hand")
    }

    func testProfileNameResolverClampsLongTypedName() {
        let resolver = ProfileNameResolver(existingNames: [])
        let resolved = resolver.resolve(
            typedName: String(repeating: "A", count: 120),
            context: .weekend,
            customContextLabel: "",
            handedness: .right,
            gripMode: .oneHand
        )

        XCTAssertEqual(resolved.count, 80)
    }

    func testProfileNameResolverMiddleTruncation() {
        let text = "Custom-9EE28A67-01AE-4069-952C-40D997ED79"
        let result = ProfileNameResolver.middleTruncated(text, maxCharacters: 16)

        XCTAssertTrue(result.contains("…"))
        XCTAssertEqual(result.count, 16)
    }

    func testPreviewLayoutModelTracksMovedAppsAndFiltersByPhase() {
        let appA = UUID()
        let appB = UUID()

        let current = [
            LayoutAssignment(appID: appA, slot: Slot(page: 0, row: 0, column: 0)),
            LayoutAssignment(appID: appB, slot: Slot(page: 0, row: 1, column: 1))
        ]
        let recommended = [
            LayoutAssignment(appID: appA, slot: Slot(page: 0, row: 2, column: 2)),
            LayoutAssignment(appID: appB, slot: Slot(page: 0, row: 1, column: 1))
        ]
        let model = PreviewLayoutModel(currentAssignments: current, recommendedAssignments: recommended)

        XCTAssertEqual(model.pageIndices, [0])
        XCTAssertEqual(model.movedAppIDs, [appA])

        let movedCurrent = model.assignments(on: 0, phase: .current, movedOnly: true)
        let movedRecommended = model.assignments(on: 0, phase: .recommended, movedOnly: true)

        XCTAssertEqual(movedCurrent.map(\.appID), [appA])
        XCTAssertEqual(movedRecommended.map(\.appID), [appA])
    }

    func testMappingGridGeometryMapsCornersAndCenter() {
        let geometry = MappingGridGeometry(rows: 6, columns: 4)
        let rect = CGRect(x: 0, y: 0, width: 400, height: 600)

        let topLeft = geometry.slot(for: CGPoint(x: 1, y: 1), in: rect, page: 0)
        let center = geometry.slot(for: CGPoint(x: 150, y: 250), in: rect, page: 0)
        let bottomRight = geometry.slot(for: CGPoint(x: 399, y: 599), in: rect, page: 0)
        let centerPoint = geometry.markerPoint(for: Slot(page: 0, row: 2, column: 1), in: rect)

        XCTAssertEqual(topLeft, Slot(page: 0, row: 0, column: 0))
        XCTAssertEqual(center, Slot(page: 0, row: 2, column: 1))
        XCTAssertEqual(bottomRight, Slot(page: 0, row: 5, column: 3))
        XCTAssertEqual(centerPoint.x, 150, accuracy: 0.0001)
        XCTAssertEqual(centerPoint.y, 250, accuracy: 0.0001)
    }
}

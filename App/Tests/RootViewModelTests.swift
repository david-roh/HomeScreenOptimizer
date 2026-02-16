import Core
import Ingestion
import SwiftUI
@testable import HomeScreenOptimizeriOS
import XCTest

@MainActor
final class RootViewModelTests: XCTestCase {
    func testAdjustDetectedSlotClampsToSupportedBounds() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.importSession = ScreenshotImportSession(
            pages: [
                ScreenshotPage(filePath: "/tmp/page-1.png", pageIndex: 0),
                ScreenshotPage(filePath: "/tmp/page-2.png", pageIndex: 1)
            ]
        )
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: Slot(page: 0, row: 0, column: 0))
        ]

        model.adjustDetectedSlot(index: 0, pageDelta: 9, rowDelta: -5, columnDelta: 9)

        XCTAssertEqual(model.detectedSlots[0].slot.page, 1)
        XCTAssertEqual(model.detectedSlots[0].slot.row, 0)
        XCTAssertEqual(model.detectedSlots[0].slot.column, 3)
    }

    func testHasSlotConflictsTrueWhenDuplicateSlotsPresent() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        let sharedSlot = Slot(page: 0, row: 2, column: 1)
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: sharedSlot),
            DetectedAppSlot(appName: "Mail", confidence: 0.8, slot: sharedSlot)
        ]

        XCTAssertTrue(model.hasSlotConflicts)
    }

    func testBindingForDetectedAppNameTrimsWhitespace() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: Slot(page: 0, row: 1, column: 1))
        ]

        let binding = model.bindingForDetectedAppName(index: 0)
        binding.wrappedValue = "  Google Maps  "

        XCTAssertEqual(model.detectedSlots[0].appName, "Google Maps")
    }
}

private struct StubLayoutExtractor: LayoutOCRExtracting {
    func extractAppLabels(from imagePath: String) async throws -> [OCRLabelCandidate] {
        []
    }
}

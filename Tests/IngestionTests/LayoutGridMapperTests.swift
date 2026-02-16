import Ingestion
import XCTest

final class LayoutGridMapperTests: XCTestCase {
    func testMapConvertsLocatedCandidatesToExpectedSlots() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(text: "Maps", confidence: 0.9, centerX: 0.10, centerY: 0.90),
            LocatedOCRLabelCandidate(text: "Mail", confidence: 0.8, centerX: 0.60, centerY: 0.90),
            LocatedOCRLabelCandidate(text: "Camera", confidence: 0.95, centerX: 0.60, centerY: 0.20)
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 3)

        let maps = detection.apps.first { $0.appName == "Maps" }
        XCTAssertEqual(maps?.slot.row, 0)
        XCTAssertEqual(maps?.slot.column, 0)

        let mail = detection.apps.first { $0.appName == "Mail" }
        XCTAssertEqual(mail?.slot.row, 0)
        XCTAssertEqual(mail?.slot.column, 2)

        let camera = detection.apps.first { $0.appName == "Camera" }
        XCTAssertEqual(camera?.slot.row, 4)
        XCTAssertEqual(camera?.slot.column, 2)
    }

    func testMapKeepsHighestConfidencePerSlot() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(text: "One", confidence: 0.30, centerX: 0.1, centerY: 0.8),
            LocatedOCRLabelCandidate(text: "Two", confidence: 0.90, centerX: 0.11, centerY: 0.79)
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 1)
        XCTAssertEqual(detection.apps.first?.appName, "Two")
        XCTAssertEqual(detection.apps.first?.confidence ?? 0, 0.90, accuracy: 0.0001)
    }

    func testMapFiltersLikelyWidgetNoise() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "No Events Today",
                confidence: 0.98,
                centerX: 0.22,
                centerY: 0.86,
                boxWidth: 0.48,
                boxHeight: 0.12
            ),
            LocatedOCRLabelCandidate(
                text: "SUNDAY",
                confidence: 0.95,
                centerX: 0.26,
                centerY: 0.87
            ),
            LocatedOCRLabelCandidate(
                text: "Maps",
                confidence: 0.86,
                centerX: 0.25,
                centerY: 0.79,
                boxWidth: 0.12,
                boxHeight: 0.03
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 1)
        XCTAssertEqual(detection.apps.first?.appName, "Maps")
    }
}

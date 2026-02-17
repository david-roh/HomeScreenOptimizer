import Core
import Ingestion
import XCTest

final class LayoutGridMapperTests: XCTestCase {
    func testMapConvertsLocatedCandidatesToExpectedSlots() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(text: "Maps", confidence: 0.9, centerX: 0.10, centerY: 0.75),
            LocatedOCRLabelCandidate(text: "Mail", confidence: 0.8, centerX: 0.60, centerY: 0.75),
            LocatedOCRLabelCandidate(text: "Camera", confidence: 0.95, centerX: 0.60, centerY: 0.35)
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 3)

        let maps = detection.apps.first { $0.appName == "Maps" }
        XCTAssertEqual(maps?.slot.row, 0)
        XCTAssertEqual(maps?.slot.column, 0)
        XCTAssertEqual(maps?.slot.type, .app)
        XCTAssertEqual(maps?.labelCenterX ?? 0, 0.10, accuracy: 0.0001)
        XCTAssertEqual(maps?.labelCenterY ?? 0, 0.75, accuracy: 0.0001)

        let mail = detection.apps.first { $0.appName == "Mail" }
        XCTAssertEqual(mail?.slot.row, 0)
        XCTAssertEqual(mail?.slot.column, 2)
        XCTAssertEqual(mail?.slot.type, .app)

        let camera = detection.apps.first { $0.appName == "Camera" }
        XCTAssertEqual(camera?.slot.row, 4)
        XCTAssertEqual(camera?.slot.column, 2)
        XCTAssertEqual(camera?.slot.type, .app)
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

    func testMapFiltersDayAbbreviationNoise() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "Sun",
                confidence: 0.95,
                centerX: 0.27,
                centerY: 0.84,
                boxWidth: 0.08,
                boxHeight: 0.03
            ),
            LocatedOCRLabelCandidate(
                text: "Health",
                confidence: 0.87,
                centerX: 0.50,
                centerY: 0.72,
                boxWidth: 0.11,
                boxHeight: 0.03
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 1)
        XCTAssertEqual(detection.apps.first?.appName, "Health")
    }

    func testMapCreatesDockSlotForBottomLabels() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "Messages",
                confidence: 0.88,
                centerX: 0.68,
                centerY: 0.05,
                boxWidth: 0.14,
                boxHeight: 0.03
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 1, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 1)
        XCTAssertEqual(detection.apps[0].slot, Slot(page: 1, row: 0, column: 2, type: .dock))
    }

    func testMapDedupesLikelyWidgetDuplicateAppLabel() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "Maps",
                confidence: 0.93,
                centerX: 0.26,
                centerY: 0.70,
                boxWidth: 0.11,
                boxHeight: 0.03
            ),
            LocatedOCRLabelCandidate(
                text: "Maps",
                confidence: 0.91,
                centerX: 0.28,
                centerY: 0.46,
                boxWidth: 0.11,
                boxHeight: 0.03
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 1)
        XCTAssertEqual(detection.apps[0].appName, "Maps")
        XCTAssertGreaterThanOrEqual(detection.apps[0].slot.row, 3)
        XCTAssertTrue(detection.widgetLockedSlots.contains(where: { $0.row <= 1 && $0.column == 1 }))
    }

    func testMapInfersWidgetLockedSlotsFromWideWidgetText() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "No Events Today",
                confidence: 0.98,
                centerX: 0.72,
                centerY: 0.82,
                boxWidth: 0.42,
                boxHeight: 0.11
            ),
            LocatedOCRLabelCandidate(
                text: "Photos",
                confidence: 0.88,
                centerX: 0.32,
                centerY: 0.48,
                boxWidth: 0.10,
                boxHeight: 0.03
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)

        XCTAssertEqual(detection.apps.count, 1)
        XCTAssertEqual(detection.apps[0].appName, "Photos")
        XCTAssertFalse(detection.widgetLockedSlots.isEmpty)
    }

    func testMapCalendarWidgetSignalLocksTwoByTwoArea() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "SUNDAY",
                confidence: 0.96,
                centerX: 0.20,
                centerY: 0.83,
                boxWidth: 0.16,
                boxHeight: 0.05
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)
        let expected = Set([
            Slot(page: 0, row: 0, column: 0, type: .widgetLocked),
            Slot(page: 0, row: 0, column: 1, type: .widgetLocked),
            Slot(page: 0, row: 1, column: 0, type: .widgetLocked),
            Slot(page: 0, row: 1, column: 1, type: .widgetLocked)
        ])

        XCTAssertTrue(expected.isSubset(of: Set(detection.widgetLockedSlots)))
    }

    func testMapLocksTopRowsWhenDualWidgetSignalsSpanScreenWidth() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "No Events Today",
                confidence: 0.98,
                centerX: 0.24,
                centerY: 0.84,
                boxWidth: 0.34,
                boxHeight: 0.10
            ),
            LocatedOCRLabelCandidate(
                text: "SUN",
                confidence: 0.92,
                centerX: 0.74,
                centerY: 0.84,
                boxWidth: 0.18,
                boxHeight: 0.07
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)
        let locked = Set(detection.widgetLockedSlots)

        for row in 0..<2 {
            for column in 0..<4 {
                XCTAssertTrue(
                    locked.contains(Slot(page: 0, row: row, column: column, type: .widgetLocked)),
                    "Expected widget lock at row \(row) column \(column)"
                )
            }
        }
    }

    func testMapKeepsSingleWordLabelsWithShortBoundingHeight() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "Fitness",
                confidence: 0.97,
                centerX: 0.15,
                centerY: 0.81,
                boxWidth: 0.104,
                boxHeight: 0.013
            ),
            LocatedOCRLabelCandidate(
                text: "Contacts",
                confidence: 0.97,
                centerX: 0.61,
                centerY: 0.81,
                boxWidth: 0.132,
                boxHeight: 0.013
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)
        let names = Set(detection.apps.map(\.appName))

        XCTAssertTrue(names.contains("Fitness"))
        XCTAssertTrue(names.contains("Contacts"))
    }

    func testMapFiltersSearchPillVariants() {
        let mapper = HomeScreenGridMapper()
        let input = [
            LocatedOCRLabelCandidate(
                text: "Q Search",
                confidence: 0.98,
                centerX: 0.50,
                centerY: 0.18,
                boxWidth: 0.14,
                boxHeight: 0.02
            ),
            LocatedOCRLabelCandidate(
                text: "Files",
                confidence: 0.95,
                centerX: 0.84,
                centerY: 0.81,
                boxWidth: 0.08,
                boxHeight: 0.02
            )
        ]

        let detection = mapper.map(locatedCandidates: input, page: 0, rows: 6, columns: 4)
        XCTAssertEqual(detection.apps.count, 1)
        XCTAssertEqual(detection.apps.first?.appName, "Files")
    }
}

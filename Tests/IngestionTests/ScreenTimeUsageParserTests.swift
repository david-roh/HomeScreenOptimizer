import Ingestion
import XCTest

final class ScreenTimeUsageParserTests: XCTestCase {
    func testParseFromLocatedCandidatesByRows() {
        let parser = ScreenTimeUsageParser()
        let input: [LocatedOCRLabelCandidate] = [
            LocatedOCRLabelCandidate(text: "Instagram", confidence: 0.9, centerX: 0.15, centerY: 0.82),
            LocatedOCRLabelCandidate(text: "1h 20m", confidence: 0.88, centerX: 0.84, centerY: 0.82),
            LocatedOCRLabelCandidate(text: "Maps", confidence: 0.92, centerX: 0.18, centerY: 0.74),
            LocatedOCRLabelCandidate(text: "45m", confidence: 0.87, centerX: 0.85, centerY: 0.74)
        ]

        let output = parser.parse(from: input)

        XCTAssertEqual(output.count, 2)
        XCTAssertEqual(output.first?.appName, "Instagram")
        XCTAssertEqual(output.first?.minutesPerDay ?? 0, 80, accuracy: 0.001)
        XCTAssertEqual(output.last?.appName, "Maps")
        XCTAssertEqual(output.last?.minutesPerDay ?? 0, 45, accuracy: 0.001)
    }

    func testParseSupportsInlineEntries() {
        let parser = ScreenTimeUsageParser()
        let input: [LocatedOCRLabelCandidate] = [
            LocatedOCRLabelCandidate(text: "YouTube 2h 5m", confidence: 0.9, centerX: 0.2, centerY: 0.7),
            LocatedOCRLabelCandidate(text: "Messages 35m", confidence: 0.88, centerX: 0.2, centerY: 0.65)
        ]

        let output = parser.parse(from: input)
        XCTAssertEqual(output.count, 2)
        XCTAssertEqual(output.first?.appName, "YouTube")
        XCTAssertEqual(output.first?.minutesPerDay ?? 0, 125, accuracy: 0.001)
        XCTAssertEqual(output.last?.appName, "Messages")
        XCTAssertEqual(output.last?.minutesPerDay ?? 0, 35, accuracy: 0.001)
    }

    func testParseIgnoresHeadersAndKeepsBestDuplicate() {
        let parser = ScreenTimeUsageParser()
        let input: [LocatedOCRLabelCandidate] = [
            LocatedOCRLabelCandidate(text: "Most Used", confidence: 0.99, centerX: 0.2, centerY: 0.95),
            LocatedOCRLabelCandidate(text: "Mail", confidence: 0.70, centerX: 0.2, centerY: 0.7),
            LocatedOCRLabelCandidate(text: "30m", confidence: 0.70, centerX: 0.8, centerY: 0.7),
            LocatedOCRLabelCandidate(text: "Mail", confidence: 0.92, centerX: 0.2, centerY: 0.6),
            LocatedOCRLabelCandidate(text: "35m", confidence: 0.93, centerX: 0.8, centerY: 0.6)
        ]

        let output = parser.parse(from: input)
        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(output.first?.appName, "Mail")
        XCTAssertEqual(output.first?.minutesPerDay ?? 0, 35, accuracy: 0.001)
    }

    func testParseFromPlainCandidatesSupportsInlineRows() {
        let parser = ScreenTimeUsageParser()
        let input = [
            OCRLabelCandidate(text: "YouTube 1h 10m", confidence: 0.9),
            OCRLabelCandidate(text: "Maps 25m", confidence: 0.8)
        ]

        let output = parser.parse(from: input)
        XCTAssertEqual(output.count, 2)
        XCTAssertEqual(output.first?.appName, "YouTube")
        XCTAssertEqual(output.first?.minutesPerDay ?? 0, 70, accuracy: 0.001)
    }

    func testParseSupportsLocalizedHourMinutePatterns() {
        let parser = ScreenTimeUsageParser()
        let input = [
            OCRLabelCandidate(text: "TikTok 1 h 20 min", confidence: 0.91),
            OCRLabelCandidate(text: "Reddit 2,5 h", confidence: 0.89),
            OCRLabelCandidate(text: "Safari 1.30", confidence: 0.85)
        ]

        let output = parser.parse(from: input)
        XCTAssertEqual(output.count, 3)
        XCTAssertEqual(output.first?.appName, "Reddit")
        XCTAssertEqual(output.first?.minutesPerDay ?? 0, 150, accuracy: 0.001)
        XCTAssertEqual(output[1].appName, "Safari")
        XCTAssertEqual(output[1].minutesPerDay, 90, accuracy: 0.001)
        XCTAssertEqual(output.last?.appName, "TikTok")
        XCTAssertEqual(output.last?.minutesPerDay ?? 0, 80, accuracy: 0.001)
    }

    func testParseNormalizesWrappedAppNamePunctuation() {
        let parser = ScreenTimeUsageParser()
        let input = [
            OCRLabelCandidate(text: "• Instagram • 35m", confidence: 0.90)
        ]

        let output = parser.parse(from: input)
        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(output.first?.appName, "Instagram")
        XCTAssertEqual(output.first?.minutesPerDay ?? 0, 35, accuracy: 0.001)
    }
}

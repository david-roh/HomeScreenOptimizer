import Ingestion
import XCTest

final class OCRPostProcessorTests: XCTestCase {
    func testProcessFiltersNoiseAndKeepsHighestConfidenceDuplicate() {
        let processor = OCRPostProcessor()
        let input: [OCRLabelCandidate] = [
            OCRLabelCandidate(text: "Instagram", confidence: 0.70),
            OCRLabelCandidate(text: "instagram", confidence: 0.89),
            OCRLabelCandidate(text: "Search", confidence: 0.99),
            OCRLabelCandidate(text: "12345", confidence: 0.93),
            OCRLabelCandidate(text: "Maps", confidence: 0.82)
        ]

        let output = processor.process(input)

        XCTAssertEqual(output.count, 2)
        XCTAssertEqual(output[0].text, "instagram")
        XCTAssertEqual(output[0].confidence, 0.89, accuracy: 0.0001)
        XCTAssertEqual(output[1].text, "Maps")
    }

    func testEstimateImportQualityUsesCountAndConfidence() {
        let processor = OCRPostProcessor()

        let high = (0..<12).map { index in
            OCRLabelCandidate(text: "App\(index)", confidence: 0.8)
        }
        XCTAssertEqual(processor.estimateImportQuality(from: high), .high)

        let medium = (0..<7).map { index in
            OCRLabelCandidate(text: "Item\(index)", confidence: 0.6)
        }
        XCTAssertEqual(processor.estimateImportQuality(from: medium), .medium)

        let low = [
            OCRLabelCandidate(text: "Maps", confidence: 0.5),
            OCRLabelCandidate(text: "Mail", confidence: 0.45)
        ]
        XCTAssertEqual(processor.estimateImportQuality(from: low), .low)
    }
}

import Usage
import XCTest

final class UsageNormalizerTests: XCTestCase {
    func testNormalizeScalesToOneAndDropsInvalidEntries() {
        let normalizer = UsageNormalizer()
        let normalized = normalizer.normalize(minutesByName: [
            "  Maps ": 30,
            "Mail": 120,
            "": 50,
            "Calendar": 0
        ])

        XCTAssertEqual(normalized.count, 2)
        XCTAssertEqual(normalized["mail"] ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(normalized["maps"] ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertNil(normalized["calendar"])
    }

    func testCanonicalNameCollapsesWhitespaceAndLowercases() {
        let normalizer = UsageNormalizer()
        XCTAssertEqual(normalizer.canonicalName("  Google   Maps  "), "google maps")
    }
}

import Usage
import XCTest

final class AppNameMatcherTests: XCTestCase {
    func testBestMatchHandlesAliasesAndTypos() {
        let matcher = AppNameMatcher()

        XCTAssertEqual(
            matcher.bestMatch(for: "Google Maps", against: ["Maps", "Mail"]),
            "Maps"
        )

        XCTAssertEqual(
            matcher.bestMatch(for: "Instagrarn", against: ["Instagram", "Photos"]),
            "Instagram"
        )
    }

    func testCanonicalizeToKnownAppNormalizesCommonOCRNoise() {
        let matcher = AppNameMatcher()

        XCTAssertEqual(matcher.canonicalizeToKnownApp("Rem1nders"), "Reminders")
        XCTAssertEqual(matcher.canonicalizeToKnownApp("No Events Today"), "No Events Today")
    }

    func testSimilarityPrefersCloserNames() {
        let matcher = AppNameMatcher()

        let close = matcher.similarity("instagram", "instagrarn")
        let far = matcher.similarity("instagram", "calendar")

        XCTAssertGreaterThan(close, far)
    }
}

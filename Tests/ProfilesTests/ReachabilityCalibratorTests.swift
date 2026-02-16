import Core
import Profiles
import XCTest

final class ReachabilityCalibratorTests: XCTestCase {
    func testBuildReachabilityMapWeightsFasterSamplesHigher() {
        let calibrator = ReachabilityCalibrator()
        let fast = Slot(page: 0, row: 5, column: 3)
        let slow = Slot(page: 0, row: 0, column: 0)

        let map = calibrator.buildReachabilityMap(from: [
            CalibrationSample(slot: fast, responseTimeMs: 120),
            CalibrationSample(slot: slow, responseTimeMs: 900)
        ])

        XCTAssertEqual(map.slotWeights.count, 2)
        XCTAssertGreaterThan(map.slotWeights[fast] ?? 0, map.slotWeights[slow] ?? 0)
    }

    func testBuildReachabilityMapEmptyInputReturnsEmptyMap() {
        let calibrator = ReachabilityCalibrator()
        let map = calibrator.buildReachabilityMap(from: [])
        XCTAssertTrue(map.slotWeights.isEmpty)
    }
}

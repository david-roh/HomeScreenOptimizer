import Core
import Foundation

public struct CalibrationSample: Sendable {
    public let slot: Slot
    public let responseTimeMs: Double

    public init(slot: Slot, responseTimeMs: Double) {
        self.slot = slot
        self.responseTimeMs = responseTimeMs
    }
}

public struct ReachabilityCalibrator {
    public init() {}

    public func buildReachabilityMap(from samples: [CalibrationSample]) -> ReachabilityMap {
        guard !samples.isEmpty else {
            return ReachabilityMap()
        }

        let maxTime = max(samples.map(\ .responseTimeMs).max() ?? 1.0, 1.0)
        let mapped = Dictionary(uniqueKeysWithValues: samples.map { sample in
            let normalized = max(0, 1.0 - (sample.responseTimeMs / maxTime))
            return (sample.slot, normalized)
        })

        return ReachabilityMap(slotWeights: mapped)
    }
}

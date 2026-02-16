import Core
import Foundation

public struct DetectedAppSlot: Codable, Hashable, Sendable {
    public var appName: String
    public var confidence: Double
    public var slot: Slot

    public init(appName: String, confidence: Double, slot: Slot) {
        self.appName = appName
        self.confidence = confidence
        self.slot = slot
    }
}

public struct LayoutGridDetection: Codable, Hashable, Sendable {
    public var rows: Int
    public var columns: Int
    public var apps: [DetectedAppSlot]

    public init(rows: Int, columns: Int, apps: [DetectedAppSlot]) {
        self.rows = rows
        self.columns = columns
        self.apps = apps
    }
}

public struct HomeScreenGridMapper: Sendable {
    public init() {}

    public func map(
        locatedCandidates: [LocatedOCRLabelCandidate],
        page: Int,
        rows: Int = 6,
        columns: Int = 4
    ) -> LayoutGridDetection {
        guard rows > 0, columns > 0 else {
            return LayoutGridDetection(rows: max(0, rows), columns: max(0, columns), apps: [])
        }

        var bestBySlot: [Slot: DetectedAppSlot] = [:]

        for candidate in locatedCandidates {
            let x = min(max(candidate.centerX, 0), 0.9999)
            let y = min(max(candidate.centerY, 0), 0.9999)

            let rowFromTop = min(rows - 1, max(0, Int((1.0 - y) * Double(rows))))
            let column = min(columns - 1, max(0, Int(x * Double(columns))))
            let slot = Slot(page: page, row: rowFromTop, column: column)

            let mapped = DetectedAppSlot(appName: candidate.text, confidence: candidate.confidence, slot: slot)
            if let existing = bestBySlot[slot], existing.confidence >= mapped.confidence {
                continue
            }

            bestBySlot[slot] = mapped
        }

        let sorted = bestBySlot.values.sorted { lhs, rhs in
            if lhs.slot.page != rhs.slot.page {
                return lhs.slot.page < rhs.slot.page
            }
            if lhs.slot.row != rhs.slot.row {
                return lhs.slot.row < rhs.slot.row
            }
            if lhs.slot.column != rhs.slot.column {
                return lhs.slot.column < rhs.slot.column
            }

            return lhs.appName < rhs.appName
        }

        return LayoutGridDetection(rows: rows, columns: columns, apps: sorted)
    }
}

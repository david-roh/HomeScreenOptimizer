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
    private let ignoredExactTerms: Set<String>
    private let ignoredSubstrings: [String]

    public init(
        ignoredExactTerms: Set<String> = [
            "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
            "today", "tomorrow", "yesterday", "no events today", "no events",
            "search", "edit", "done", "cancel"
        ],
        ignoredSubstrings: [String] = [
            "no events", "weather", "battery", "calendar widget", "screen time"
        ]
    ) {
        self.ignoredExactTerms = ignoredExactTerms
        self.ignoredSubstrings = ignoredSubstrings
    }

    public func map(
        locatedCandidates: [LocatedOCRLabelCandidate],
        page: Int,
        rows: Int = 6,
        columns: Int = 4
    ) -> LayoutGridDetection {
        guard rows > 0, columns > 0 else {
            return LayoutGridDetection(rows: max(0, rows), columns: max(0, columns), apps: [])
        }

        var bestBySlot: [Slot: (detected: DetectedAppSlot, score: Double)] = [:]

        for candidate in locatedCandidates {
            guard isLikelyHomeScreenAppLabel(candidate) else {
                continue
            }

            let x = min(max(candidate.centerX, 0), 0.9999)
            let y = min(max(candidate.centerY, 0), 0.9999)

            let rowFromTop = min(rows - 1, max(0, Int((1.0 - y) * Double(rows))))
            let column = min(columns - 1, max(0, Int(x * Double(columns))))
            let slot = Slot(page: page, row: rowFromTop, column: column)

            let mapped = DetectedAppSlot(appName: candidate.text, confidence: candidate.confidence, slot: slot)
            let candidateScore = slotLabelFitnessScore(candidate, row: rowFromTop, rows: rows)
            if let existing = bestBySlot[slot], existing.score >= candidateScore {
                continue
            }

            bestBySlot[slot] = (mapped, candidateScore)
        }

        let sorted = bestBySlot.values.map(\.detected).sorted { lhs, rhs in
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

    private func isLikelyHomeScreenAppLabel(_ candidate: LocatedOCRLabelCandidate) -> Bool {
        let lowered = candidate.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !lowered.isEmpty else {
            return false
        }
        guard !ignoredExactTerms.contains(lowered) else {
            return false
        }
        guard !ignoredSubstrings.contains(where: { lowered.contains($0) }) else {
            return false
        }
        guard lowered.range(of: #"^\d{1,2}$"#, options: .regularExpression) == nil else {
            return false
        }
        guard lowered.components(separatedBy: " ").count <= 3 else {
            return false
        }

        if candidate.boxWidth > 0, candidate.boxWidth > 0.34 {
            return false
        }

        if candidate.boxHeight > 0, candidate.boxHeight > 0.11 {
            return false
        }

        if candidate.boxWidth > 0, candidate.boxHeight > 0 {
            let aspect = candidate.boxWidth / max(candidate.boxHeight, 0.0001)
            if aspect > 7.5 {
                return false
            }
        }

        return true
    }

    private func slotLabelFitnessScore(_ candidate: LocatedOCRLabelCandidate, row: Int, rows: Int) -> Double {
        guard rows > 0 else {
            return candidate.confidence
        }

        let yFromTop = 1.0 - min(max(candidate.centerY, 0), 1)
        let rowHeight = 1.0 / Double(rows)
        let rowStart = Double(row) * rowHeight
        let local = min(max((yFromTop - rowStart) / rowHeight, 0), 1)

        let preferredLabelBand = 0.72
        let sigma = 0.24
        let bandScore = exp(-pow(local - preferredLabelBand, 2) / (2 * sigma * sigma))

        return candidate.confidence * (0.70 + (0.30 * bandScore))
    }
}

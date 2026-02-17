import Core
import Foundation

public struct DetectedAppSlot: Codable, Hashable, Sendable {
    public var appName: String
    public var confidence: Double
    public var slot: Slot
    public var labelCenterX: Double?
    public var labelCenterY: Double?
    public var labelBoxWidth: Double?
    public var labelBoxHeight: Double?

    public init(
        appName: String,
        confidence: Double,
        slot: Slot,
        labelCenterX: Double? = nil,
        labelCenterY: Double? = nil,
        labelBoxWidth: Double? = nil,
        labelBoxHeight: Double? = nil
    ) {
        self.appName = appName
        self.confidence = confidence
        self.slot = slot
        self.labelCenterX = labelCenterX
        self.labelCenterY = labelCenterY
        self.labelBoxWidth = labelBoxWidth
        self.labelBoxHeight = labelBoxHeight
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
    private let appGridTopY: Double
    private let appGridBottomY: Double
    private let dockTopY: Double
    private let dockBottomY: Double

    public init(
        ignoredExactTerms: Set<String> = [
            "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
            "sun", "mon", "tue", "wed", "thu", "fri", "sat",
            "today", "tomorrow", "yesterday", "no events today", "no events",
            "search", "edit", "done", "cancel"
        ],
        ignoredSubstrings: [String] = [
            "no events", "weather", "battery", "calendar widget", "screen time"
        ],
        appGridTopY: Double = 0.15,
        appGridBottomY: Double = 0.80,
        dockTopY: Double = 0.84,
        dockBottomY: Double = 0.98
    ) {
        self.ignoredExactTerms = ignoredExactTerms
        self.ignoredSubstrings = ignoredSubstrings
        self.appGridTopY = appGridTopY
        self.appGridBottomY = appGridBottomY
        self.dockTopY = dockTopY
        self.dockBottomY = dockBottomY
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
            let yFromTop = 1.0 - min(max(candidate.centerY, 0), 1)
            guard isLikelyHomeScreenAppLabel(candidate, yFromTop: yFromTop) else {
                continue
            }

            let x = min(max(candidate.centerX, 0), 0.9999)
            let column = min(columns - 1, max(0, Int(x * Double(columns))))
            let slot: Slot
            if (dockTopY...dockBottomY).contains(yFromTop) {
                slot = Slot(page: page, row: 0, column: column, type: .dock)
            } else {
                guard let rowFromTop = mappedAppRow(for: yFromTop, rows: rows) else {
                    continue
                }
                slot = Slot(page: page, row: rowFromTop, column: column, type: .app)
            }

            let mapped = DetectedAppSlot(
                appName: candidate.text,
                confidence: candidate.confidence,
                slot: slot,
                labelCenterX: candidate.centerX,
                labelCenterY: candidate.centerY,
                labelBoxWidth: candidate.boxWidth > 0 ? candidate.boxWidth : nil,
                labelBoxHeight: candidate.boxHeight > 0 ? candidate.boxHeight : nil
            )
            let candidateScore = slotLabelFitnessScore(candidate, slot: slot, rows: rows, yFromTop: yFromTop)
            if let existing = bestBySlot[slot], existing.score >= candidateScore {
                continue
            }

            bestBySlot[slot] = (mapped, candidateScore)
        }

        let sorted = bestBySlot.values.map(\.detected).sorted { lhs, rhs in
            if lhs.slot.page != rhs.slot.page {
                return lhs.slot.page < rhs.slot.page
            }
            if lhs.slot.type != rhs.slot.type {
                return slotTypeOrder(lhs.slot.type) < slotTypeOrder(rhs.slot.type)
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

    private func slotTypeOrder(_ type: SlotType) -> Int {
        switch type {
        case .app:
            return 0
        case .dock:
            return 1
        case .folder:
            return 2
        case .widgetLocked:
            return 3
        case .holding:
            return 4
        }
    }

    private func isLikelyHomeScreenAppLabel(_ candidate: LocatedOCRLabelCandidate, yFromTop: Double) -> Bool {
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

        let wordCount = lowered.split(whereSeparator: \.isWhitespace).count
        if wordCount >= 2, candidate.boxWidth > 0.22 {
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

        if yFromTop < 0.08 || yFromTop > 0.99 {
            return false
        }

        if yFromTop < appGridTopY - 0.05, candidate.boxWidth > 0.14 {
            return false
        }

        if yFromTop > appGridBottomY, yFromTop < dockTopY {
            return false
        }

        return true
    }

    private func mappedAppRow(for yFromTop: Double, rows: Int) -> Int? {
        guard rows > 0 else {
            return nil
        }
        guard yFromTop >= appGridTopY - 0.02, yFromTop <= appGridBottomY else {
            return nil
        }

        let normalized = (yFromTop - appGridTopY) / max(appGridBottomY - appGridTopY, 0.0001)
        let mapped = Int(normalized * Double(rows))
        return min(rows - 1, max(0, mapped))
    }

    private func slotLabelFitnessScore(
        _ candidate: LocatedOCRLabelCandidate,
        slot: Slot,
        rows: Int,
        yFromTop: Double
    ) -> Double {
        if slot.type == .dock {
            return candidate.confidence * 0.92
        }

        guard rows > 0 else {
            return candidate.confidence
        }

        let yWithinGrid = min(max((yFromTop - appGridTopY) / max(appGridBottomY - appGridTopY, 0.0001), 0), 1)
        let rowHeight = 1.0 / Double(rows)
        let rowStart = Double(slot.row) * rowHeight
        let local = min(max((yWithinGrid - rowStart) / rowHeight, 0), 1)

        let preferredLabelBand = 0.72
        let sigma = 0.24
        let bandScore = exp(-pow(local - preferredLabelBand, 2) / (2 * sigma * sigma))

        return candidate.confidence * (0.70 + (0.30 * bandScore))
    }
}

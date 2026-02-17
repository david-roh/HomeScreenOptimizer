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
    public var widgetLockedSlots: [Slot]

    public init(rows: Int, columns: Int, apps: [DetectedAppSlot], widgetLockedSlots: [Slot] = []) {
        self.rows = rows
        self.columns = columns
        self.apps = apps
        self.widgetLockedSlots = widgetLockedSlots
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
            return LayoutGridDetection(rows: max(0, rows), columns: max(0, columns), apps: [], widgetLockedSlots: [])
        }

        let inferredWidgetSlots = inferWidgetLockedSlots(
            from: locatedCandidates,
            page: page,
            rows: rows,
            columns: columns
        )
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
                if inferredWidgetSlots.contains(slot) {
                    continue
                }
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

        let deduped = resolveLikelyWidgetDuplicates(
            mappedBySlot: bestBySlot,
            page: page
        )
        var combinedWidgetSlots = inferredWidgetSlots
        combinedWidgetSlots.formUnion(deduped.widgetSlots)

        let sorted = deduped.apps.sorted { lhs, rhs in
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
        let sortedWidgetSlots = combinedWidgetSlots
            .map { Slot(page: page, row: $0.row, column: $0.column, type: .widgetLocked) }
            .sorted { lhs, rhs in
                if lhs.page != rhs.page { return lhs.page < rhs.page }
                if lhs.row != rhs.row { return lhs.row < rhs.row }
                return lhs.column < rhs.column
            }

        return LayoutGridDetection(rows: rows, columns: columns, apps: sorted, widgetLockedSlots: sortedWidgetSlots)
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
        if lowered.contains("search") {
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
            if aspect > 13.5 {
                return false
            }
            if aspect > 11.5, candidate.boxWidth > 0.16 {
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

    private func inferWidgetLockedSlots(
        from candidates: [LocatedOCRLabelCandidate],
        page: Int,
        rows: Int,
        columns: Int
    ) -> Set<Slot> {
        var locked: Set<Slot> = []
        let appGridHeight = max(appGridBottomY - appGridTopY, 0.0001)
        let cellHeight = appGridHeight / Double(rows)
        let ignoredWeekdays: Set<String> = [
            "sun", "mon", "tue", "wed", "thu", "fri", "sat",
            "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"
        ]
        var topWidgetSignals: [LocatedOCRLabelCandidate] = []

        for candidate in candidates {
            let lowered = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !lowered.isEmpty else {
                continue
            }
            let yFromTop = 1.0 - min(max(candidate.centerY, 0), 1)
            guard yFromTop >= appGridTopY, yFromTop <= appGridBottomY else {
                continue
            }

            let wordCount = lowered.split(whereSeparator: \.isWhitespace).count
            let largeLabel = candidate.boxWidth > 0.24 || candidate.boxHeight > 0.07
            let phraseLabel = wordCount >= 2 && (candidate.boxWidth > 0.14 || candidate.boxHeight > 0.035)
            let calendarText = ignoredWeekdays.contains(lowered)
                || lowered.contains("no events")
                || lowered.contains("today")
                || lowered.contains("weather")
                || lowered.contains("widget")
            let strongCalendarSignal = calendarText && (candidate.boxWidth > 0.10 || candidate.boxHeight > 0.03)
            if ignoredWeekdays.contains(lowered), candidate.boxWidth < 0.08, candidate.boxHeight < 0.03 {
                continue
            }
            guard largeLabel || phraseLabel || strongCalendarSignal else {
                continue
            }
            if strongCalendarSignal || (largeLabel && yFromTop <= appGridTopY + (cellHeight * 2.4)) {
                topWidgetSignals.append(candidate)
            }

            guard let anchorRow = mappedAppRow(for: yFromTop, rows: rows) else {
                continue
            }
            if anchorRow > 2 {
                continue
            }
            let x = min(max(candidate.centerX, 0), 0.9999)
            let anchorColumn = min(columns - 1, max(0, Int(x * Double(columns))))

            let spanColumns = min(
                columns,
                max(
                    1,
                    Int(round(candidate.boxWidth * Double(columns))) + (phraseLabel ? 1 : 0)
                )
            )
            let normalizedHeight = candidate.boxHeight > 0 ? candidate.boxHeight / appGridHeight : 0
            let spanRows = min(
                rows,
                max(
                    1,
                    Int(round(normalizedHeight * Double(rows))) + (largeLabel ? 1 : 0)
                )
            )
            var effectiveSpanColumns = spanColumns
            var effectiveSpanRows = spanRows

            if strongCalendarSignal {
                effectiveSpanColumns = max(effectiveSpanColumns, 2)
                effectiveSpanRows = max(effectiveSpanRows, 2)
            }

            if largeLabel, candidate.boxWidth > 0.30 {
                effectiveSpanColumns = max(effectiveSpanColumns, 2)
            }

            if anchorRow <= 1, (strongCalendarSignal || phraseLabel) {
                effectiveSpanRows = max(effectiveSpanRows, 2)
            }

            effectiveSpanColumns = min(columns, max(1, effectiveSpanColumns))
            effectiveSpanRows = min(rows, max(1, effectiveSpanRows))

            let rowStart = max(0, min(rows - effectiveSpanRows, anchorRow - (effectiveSpanRows / 2)))
            let colStart = max(0, min(columns - effectiveSpanColumns, anchorColumn - (effectiveSpanColumns / 2)))

            for row in rowStart..<(rowStart + effectiveSpanRows) {
                for column in colStart..<(colStart + effectiveSpanColumns) {
                    locked.insert(Slot(page: page, row: row, column: column, type: .app))
                }
            }
        }

        if shouldLockTopTwoRowsAcrossColumns(from: topWidgetSignals, rows: rows, columns: columns) {
            let lockRows = min(2, rows)
            for row in 0..<lockRows {
                for column in 0..<columns {
                    locked.insert(Slot(page: page, row: row, column: column, type: .app))
                }
            }
        }

        return locked
    }

    private func shouldLockTopTwoRowsAcrossColumns(
        from signals: [LocatedOCRLabelCandidate],
        rows: Int,
        columns: Int
    ) -> Bool {
        guard rows >= 2, columns > 0 else {
            return false
        }

        let topRowsLimit = appGridTopY + ((appGridBottomY - appGridTopY) * 0.43)
        let topSignals = signals.filter { candidate in
            let yFromTop = 1.0 - min(max(candidate.centerY, 0), 1)
            return yFromTop >= appGridTopY - 0.01 && yFromTop <= topRowsLimit
        }
        guard topSignals.count >= 2 else {
            return false
        }

        let minX = topSignals.map(\.centerX).min() ?? 0
        let maxX = topSignals.map(\.centerX).max() ?? 0
        let spread = maxX - minX
        let strongWideSignals = topSignals.filter { candidate in
            let key = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return candidate.boxWidth >= 0.28
                || key.contains("no events")
                || key.contains("today")
                || key.contains("weather")
        }

        if strongWideSignals.count >= 2, spread >= 0.33 {
            return true
        }
        if spread >= 0.58 {
            return true
        }
        if strongWideSignals.count >= 1, spread >= 0.48 {
            return true
        }
        if strongWideSignals.count >= 1,
           topSignals.count >= 3,
           spread >= 0.42 {
            return true
        }

        return false
    }

    private func resolveLikelyWidgetDuplicates(
        mappedBySlot: [Slot: (detected: DetectedAppSlot, score: Double)],
        page: Int
    ) -> (apps: [DetectedAppSlot], widgetSlots: Set<Slot>) {
        let all = mappedBySlot.values.map { (slot: $0.detected.slot, detected: $0.detected, score: $0.score) }
        var grouped: [String: [(slot: Slot, detected: DetectedAppSlot, score: Double)]] = [:]

        for item in all where item.slot.type == .app {
            let key = normalizedText(item.detected.appName)
            guard !key.isEmpty else {
                continue
            }
            grouped["\(item.slot.page)::\(key)", default: []].append(item)
        }

        var winners: Set<Slot> = Set(all.map(\.slot))
        var widgetSlots: Set<Slot> = []

        for (_, entries) in grouped where entries.count > 1 {
            let sorted = entries.sorted { lhs, rhs in
                let lhsRank = lhs.score + (Double(lhs.slot.row) * 0.04)
                let rhsRank = rhs.score + (Double(rhs.slot.row) * 0.04)
                if lhsRank != rhsRank {
                    return lhsRank > rhsRank
                }
                return lhs.detected.confidence > rhs.detected.confidence
            }

            guard let winner = sorted.first else {
                continue
            }

            for candidate in sorted.dropFirst() {
                winners.remove(candidate.slot)
                if candidate.slot.page == page, candidate.slot.row <= winner.slot.row {
                    widgetSlots.insert(Slot(page: page, row: candidate.slot.row, column: candidate.slot.column, type: .app))
                }
            }
        }

        let filtered = all
            .filter { winners.contains($0.slot) }
            .map(\.detected)

        return (filtered, widgetSlots)
    }

    private func normalizedText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
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

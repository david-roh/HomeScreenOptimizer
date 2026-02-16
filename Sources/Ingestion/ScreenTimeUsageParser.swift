import Foundation

public struct ScreenTimeUsageEntry: Codable, Hashable, Sendable {
    public var appName: String
    public var minutesPerDay: Double
    public var confidence: Double

    public init(appName: String, minutesPerDay: Double, confidence: Double) {
        self.appName = appName
        self.minutesPerDay = minutesPerDay
        self.confidence = confidence
    }
}

public struct ScreenTimeUsageParser: Sendable {
    public init() {}

    public func parse(from locatedCandidates: [LocatedOCRLabelCandidate]) -> [ScreenTimeUsageEntry] {
        let rows = groupByRow(locatedCandidates)
        var entries: [ScreenTimeUsageEntry] = []

        for row in rows {
            if let inline = parseInlineRow(row) {
                entries.append(inline)
                continue
            }

            if let split = parseSplitRow(row) {
                entries.append(split)
            }
        }

        return dedupe(entries)
    }

    public func parse(from candidates: [OCRLabelCandidate]) -> [ScreenTimeUsageEntry] {
        let entries = candidates.compactMap { candidate in
            parseInline(
                text: candidate.text,
                confidence: candidate.confidence
            )
        }

        return dedupe(entries)
    }

    private func dedupe(_ entries: [ScreenTimeUsageEntry]) -> [ScreenTimeUsageEntry] {
        var bestByApp: [String: ScreenTimeUsageEntry] = [:]

        for entry in entries {
            let key = canonicalAppName(entry.appName)
            guard !key.isEmpty else {
                continue
            }

            if let existing = bestByApp[key], existing.confidence >= entry.confidence {
                continue
            }

            bestByApp[key] = entry
        }

        return bestByApp.values.sorted { lhs, rhs in
            if lhs.minutesPerDay != rhs.minutesPerDay {
                return lhs.minutesPerDay > rhs.minutesPerDay
            }
            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }
    }

    private func groupByRow(_ candidates: [LocatedOCRLabelCandidate]) -> [[LocatedOCRLabelCandidate]] {
        let sorted = candidates.sorted { lhs, rhs in
            if abs(lhs.centerY - rhs.centerY) > 0.0001 {
                return lhs.centerY > rhs.centerY
            }
            return lhs.centerX < rhs.centerX
        }

        var groups: [[LocatedOCRLabelCandidate]] = []
        let yThreshold = 0.025

        for candidate in sorted {
            guard isLikelyScreenTimeToken(candidate.text) else {
                continue
            }

            if var last = groups.last,
               let anchorY = last.first?.centerY,
               abs(anchorY - candidate.centerY) <= yThreshold {
                last.append(candidate)
                groups[groups.count - 1] = last
            } else {
                groups.append([candidate])
            }
        }

        return groups.map { row in
            row.sorted { $0.centerX < $1.centerX }
        }
    }

    private func parseInlineRow(_ row: [LocatedOCRLabelCandidate]) -> ScreenTimeUsageEntry? {
        let lineText = row.map(\.text).joined(separator: " ")
        return parseInline(text: lineText, confidence: averageConfidence(row))
    }

    private func parseSplitRow(_ row: [LocatedOCRLabelCandidate]) -> ScreenTimeUsageEntry? {
        guard row.count >= 2 else {
            return nil
        }

        let durations = row.compactMap { candidate -> (minutes: Double, candidate: LocatedOCRLabelCandidate)? in
            guard let minutes = parseMinutes(from: candidate.text) else {
                return nil
            }
            return (minutes, candidate)
        }

        guard let bestDuration = durations.max(by: { $0.minutes < $1.minutes }) else {
            return nil
        }

        let nameParts = row
            .filter { $0 != bestDuration.candidate }
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard isLikelyAppName(nameParts) else {
            return nil
        }

        return ScreenTimeUsageEntry(
            appName: nameParts,
            minutesPerDay: bestDuration.minutes,
            confidence: averageConfidence(row)
        )
    }

    private func parseInline(text: String, confidence: Double) -> ScreenTimeUsageEntry? {
        let cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return nil
        }

        let tokens = cleaned.components(separatedBy: " ")
        for start in tokens.indices {
            let suffix = tokens[start...].joined(separator: " ")
            guard let minutes = parseMinutes(from: suffix) else {
                continue
            }

            let appName = tokens[..<start]
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard isLikelyAppName(appName) else {
                continue
            }

            return ScreenTimeUsageEntry(appName: appName, minutesPerDay: minutes, confidence: confidence)
        }

        return nil
    }

    private func parseMinutes(from rawText: String) -> Double? {
        let text = rawText
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            return nil
        }

        if let match = firstMatch(
            pattern: #"(?:(\d{1,2})\s*h(?:our|ours|r|rs)?)?\s*(?:(\d{1,2})\s*m(?:in|ins|inute|inutes)?)$"#,
            in: text
        ) {
            let hours = match[1].flatMap(Int.init) ?? 0
            let minutes = match[2].flatMap(Int.init) ?? 0
            let total = (hours * 60) + minutes
            return total > 0 ? Double(total) : nil
        }

        if let match = firstMatch(pattern: #"^(\d{1,2}):(\d{1,2})$"#, in: text),
           let hours = match[1].flatMap(Int.init),
           let minutes = match[2].flatMap(Int.init) {
            let total = (hours * 60) + minutes
            return total > 0 ? Double(total) : nil
        }

        if let match = firstMatch(pattern: #"^(\d{1,4})\s*m$"#, in: text),
           let minutes = match[1].flatMap(Int.init) {
            return minutes > 0 ? Double(minutes) : nil
        }

        if let match = firstMatch(pattern: #"^(\d{1,3})\s*h$"#, in: text),
           let hours = match[1].flatMap(Int.init) {
            return hours > 0 ? Double(hours * 60) : nil
        }

        return nil
    }

    private func firstMatch(pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
                return nil
            }
            return String(text[swiftRange])
        }
    }

    private func averageConfidence(_ row: [LocatedOCRLabelCandidate]) -> Double {
        guard !row.isEmpty else {
            return 0
        }

        return row.map(\.confidence).reduce(0, +) / Double(row.count)
    }

    private func canonicalAppName(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isLikelyScreenTimeToken(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let lowered = trimmed.lowercased()
        if ignoredTerms.contains(lowered) {
            return false
        }

        return true
    }

    private func isLikelyAppName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...32).contains(trimmed.count) else {
            return false
        }

        let lowered = trimmed.lowercased()
        if ignoredTerms.contains(lowered) {
            return false
        }

        if parseMinutes(from: lowered) != nil {
            return false
        }

        if lowered.range(of: #"^\d+$"#, options: .regularExpression) != nil {
            return false
        }

        return true
    }

    private let ignoredTerms: Set<String> = [
        "daily average",
        "most used",
        "show categories",
        "show apps",
        "see all activity",
        "notifications",
        "pickups",
        "last 7 days",
        "today",
        "week"
    ]
}

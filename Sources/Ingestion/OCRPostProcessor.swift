import Foundation

public struct OCRPostProcessor: Sendable {
    private let ignoredTerms: Set<String>

    public init() {
        ignoredTerms = Self.defaultIgnoredTerms
    }

    public init(ignoredTerms: Set<String>) {
        self.ignoredTerms = ignoredTerms
    }

    public func process(_ candidates: [OCRLabelCandidate]) -> [OCRLabelCandidate] {
        var bestByKey: [String: OCRLabelCandidate] = [:]

        for candidate in candidates {
            guard let normalizedCandidate = normalize(candidate) else {
                continue
            }

            let key = normalizedCandidate.text.lowercased()

            if let existing = bestByKey[key], existing.confidence >= normalizedCandidate.confidence {
                continue
            }

            bestByKey[key] = normalizedCandidate
        }

        return bestByKey.values.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return lhs.text < rhs.text
            }

            return lhs.confidence > rhs.confidence
        }
    }

    public func normalize(_ candidate: OCRLabelCandidate) -> OCRLabelCandidate? {
        let cleaned = normalizeDisplayText(candidate.text)
        guard isLikelyAppLabel(cleaned) else {
            return nil
        }

        return OCRLabelCandidate(text: cleaned, confidence: candidate.confidence)
    }

    public func estimateImportQuality(from candidates: [OCRLabelCandidate]) -> ImportQuality {
        let processed = process(candidates)
        guard !processed.isEmpty else {
            return .low
        }

        let averageConfidence = processed.map(\ .confidence).reduce(0, +) / Double(processed.count)

        if processed.count >= 12, averageConfidence >= 0.75 {
            return .high
        }

        if processed.count >= 6, averageConfidence >= 0.55 {
            return .medium
        }

        return .low
    }

    private func normalizeDisplayText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isLikelyAppLabel(_ text: String) -> Bool {
        guard (2...24).contains(text.count) else {
            return false
        }

        let lowered = text.lowercased()
        guard !ignoredTerms.contains(lowered) else {
            return false
        }

        if lowered.range(of: #"^\d+$"#, options: .regularExpression) != nil {
            return false
        }

        if lowered.components(separatedBy: " ").count > 4 {
            return false
        }

        let allowedSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._+-&'"))
        return text.unicodeScalars.allSatisfy { allowedSet.contains($0) }
    }

    private static let defaultIgnoredTerms: Set<String> = [
        "search",
        "edit",
        "done",
        "cancel",
        "settings",
        "screen time",
        "app library",
        "today",
        "yesterday",
        "battery"
    ]
}

import Foundation

public struct AppNameMatcher: Sendable {
    private let aliases: [String: String]
    private let knownApps: [String]

    public init(
        aliases: [String: String] = Self.defaultAliases,
        knownApps: [String] = Self.defaultKnownApps
    ) {
        self.aliases = aliases
        self.knownApps = knownApps
    }

    public func canonicalName(_ text: String) -> String {
        let folded = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: " ", options: .regularExpression)
            // Normalize common OCR digit confusions only when surrounded by letters.
            .replacingOccurrences(of: #"(?<=[a-z])0(?=[a-z])"#, with: "o", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=[a-z])1(?=[a-z])"#, with: "i", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=[a-z])5(?=[a-z])"#, with: "s", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let alias = aliases[folded] {
            return alias
        }

        return folded
    }

    public func bestMatch(for candidate: String, against options: [String], minimumScore: Double = 0.74) -> String? {
        let canonicalCandidate = canonicalName(candidate)
        guard !canonicalCandidate.isEmpty else {
            return nil
        }

        var bestOption: String?
        var bestScore = 0.0

        for option in options {
            let score = similarity(canonicalCandidate, canonicalName(option))
            if score > bestScore {
                bestScore = score
                bestOption = option
            }
        }

        guard bestScore >= minimumScore else {
            return nil
        }

        return bestOption
    }

    public func canonicalizeToKnownApp(_ candidate: String, minimumScore: Double = 0.87) -> String {
        guard let best = bestMatch(for: candidate, against: knownApps, minimumScore: minimumScore) else {
            return candidate
        }

        return best
    }

    public func similarity(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else {
            return 0
        }

        if lhs == rhs {
            return 1
        }

        let edit = editSimilarity(lhs, rhs)
        let token = tokenOverlap(lhs, rhs)
        let containment = (lhs.contains(rhs) || rhs.contains(lhs)) ? 1.0 : 0.0
        let prefix = commonPrefixSimilarity(lhs, rhs)
        let editDominant = (0.90 * edit) + (0.10 * prefix)
        let weighted = (0.50 * edit) + (0.30 * token) + (0.20 * containment)

        return max(weighted, editDominant)
    }

    private func tokenOverlap(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))

        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else {
            return 0
        }

        if lhsTokens.count == 1, rhsTokens.count == 1 {
            return editSimilarity(lhs, rhs)
        }

        let intersection = lhsTokens.intersection(rhsTokens).count
        let union = lhsTokens.union(rhsTokens).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    private func commonPrefixSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let limit = min(lhsChars.count, rhsChars.count)
        guard limit > 0 else {
            return 0
        }

        var count = 0
        for index in 0..<limit {
            guard lhsChars[index] == rhsChars[index] else {
                break
            }
            count += 1
        }

        return Double(count) / Double(max(lhsChars.count, rhsChars.count))
    }

    private func editSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let distance = levenshtein(lhs, rhs)
        let denominator = max(lhs.count, rhs.count)
        guard denominator > 0 else {
            return 0
        }

        return max(0, 1 - (Double(distance) / Double(denominator)))
    }

    private func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        guard !lhsChars.isEmpty else { return rhsChars.count }
        guard !rhsChars.isEmpty else { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1

            for (j, rhsChar) in rhsChars.enumerated() {
                let cost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + cost
                )
            }

            swap(&previous, &current)
        }

        return previous[rhsChars.count]
    }

    public static let defaultAliases: [String: String] = [
        "google maps": "maps",
        "apple maps": "maps",
        "g maps": "maps",
        "instagram app": "instagram",
        "you tube": "youtube",
        "i message": "messages",
        "message": "messages",
        "mail app": "mail",
        "calendar app": "calendar",
        "photo": "photos"
    ]

    public static let defaultKnownApps: [String] = [
        "App Store", "Books", "Calendar", "Camera", "Clock", "Contacts", "FaceTime", "Files",
        "Find My", "Fitness", "Freeform", "Health", "Home", "Journal", "Mail", "Maps", "Measure",
        "Messages", "Music", "News", "Notes", "Phone", "Photos", "Podcasts", "Reminders",
        "Safari", "Settings", "Shortcuts", "Stocks", "Translate", "TV", "Voice Memos", "Wallet",
        "Weather", "WhatsApp", "X", "YouTube", "Instagram", "TikTok", "Reddit", "Discord",
        "Spotify", "Gmail", "Slack", "Notion", "Google", "Google Drive", "Google Meet", "Zoom"
    ]
}

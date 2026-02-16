import Foundation

public struct UsageSnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var appMinutesByNormalizedName: [String: Double]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        profileID: UUID,
        appMinutesByNormalizedName: [String: Double] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        id = profileID
        self.appMinutesByNormalizedName = appMinutesByNormalizedName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var profileID: UUID {
        id
    }
}

public struct UsageNormalizer {
    public init() {}

    public func normalize(minutesByName: [String: Double]) -> [String: Double] {
        let cleaned = Dictionary(uniqueKeysWithValues: minutesByName.compactMap { entry -> (String, Double)? in
            guard entry.value > 0 else {
                return nil
            }

            let normalizedKey = canonicalName(entry.key)
            guard !normalizedKey.isEmpty else {
                return nil
            }

            return (normalizedKey, entry.value)
        })

        guard let maxValue = cleaned.values.max(), maxValue > 0 else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: cleaned.map { key, value in
            (key, value / maxValue)
        })
    }

    public func canonicalName(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

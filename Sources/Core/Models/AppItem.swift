import Foundation

public struct AppItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var bundleIdentifier: String?
    public var displayName: String
    public var category: String?
    public var dominantColorHex: String?
    public var usageScore: Double?

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String? = nil,
        displayName: String,
        category: String? = nil,
        dominantColorHex: String? = nil,
        usageScore: Double? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.category = category
        self.dominantColorHex = dominantColorHex
        self.usageScore = usageScore
    }
}

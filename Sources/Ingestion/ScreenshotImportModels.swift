import Core
import Foundation

public enum ImportQuality: String, Codable, Sendable {
    case high
    case medium
    case low
}

public struct ScreenshotPage: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var filePath: String
    public var pageIndex: Int

    public init(id: UUID = UUID(), filePath: String, pageIndex: Int) {
        self.id = id
        self.filePath = filePath
        self.pageIndex = pageIndex
    }
}

public struct ScreenshotImportSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var pages: [ScreenshotPage]
    public var quality: ImportQuality

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        pages: [ScreenshotPage] = [],
        quality: ImportQuality = .medium
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pages = pages
        self.quality = quality
    }
}

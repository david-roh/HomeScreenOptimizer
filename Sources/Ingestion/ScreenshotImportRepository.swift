import Foundation

public protocol ScreenshotImportSessionRepository: Sendable {
    func upsert(_ session: ScreenshotImportSession) throws
    func fetch(id: UUID) throws -> ScreenshotImportSession?
    func fetchAll() throws -> [ScreenshotImportSession]
    func delete(id: UUID) throws
}

public final class FileScreenshotImportSessionRepository: ScreenshotImportSessionRepository {
    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func upsert(_ session: ScreenshotImportSession) throws {
        var sessions = try loadAll()
        sessions[session.id] = session
        try saveAll(sessions)
    }

    public func fetch(id: UUID) throws -> ScreenshotImportSession? {
        try loadAll()[id]
    }

    public func fetchAll() throws -> [ScreenshotImportSession] {
        Array(try loadAll().values)
    }

    public func delete(id: UUID) throws {
        var sessions = try loadAll()
        sessions.removeValue(forKey: id)
        try saveAll(sessions)
    }

    private func loadAll() throws -> [UUID: ScreenshotImportSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([UUID: ScreenshotImportSession].self, from: data)
    }

    private func saveAll(_ sessions: [UUID: ScreenshotImportSession]) throws {
        let folderURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(sessions)
        try data.write(to: fileURL, options: .atomic)
    }
}

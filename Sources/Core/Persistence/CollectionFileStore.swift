import Foundation

public final class CollectionFileStore<Element: Identifiable & Codable & Sendable>: @unchecked Sendable where Element.ID == UUID {
    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let lock = NSLock()
    private let migrationDecoder: ((Data) throws -> [Element])?

    public init(fileURL: URL, migrationDecoder: ((Data) throws -> [Element])? = nil) {
        self.fileURL = fileURL
        self.migrationDecoder = migrationDecoder

        decoder = JSONDecoder()
        ISO8601DateCoding.configure(decoder)

        encoder = JSONEncoder()
        ISO8601DateCoding.configure(encoder)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func fetchAll() throws -> [Element] {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)

        if let envelope = try? decoder.decode(PersistedEnvelope<[Element]>.self, from: data),
           envelope.schemaVersion == SchemaVersion.current.rawValue {
            return envelope.payload
        }

        if let migrationDecoder {
            return try migrationDecoder(data)
        }

        throw PersistenceError.failedToDecode
    }

    public func saveAll(_ elements: [Element]) throws {
        lock.lock()
        defer { lock.unlock() }

        let folderURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let envelope = PersistedEnvelope(payload: elements)
        guard let data = try? encoder.encode(envelope) else {
            throw PersistenceError.failedToEncode
        }

        try data.write(to: fileURL, options: .atomic)
    }
}

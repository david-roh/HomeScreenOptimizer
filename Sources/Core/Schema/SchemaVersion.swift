import Foundation

public enum SchemaVersion: Int, Codable, CaseIterable, Sendable {
    case v1 = 1

    public static let current: SchemaVersion = .v1
}

public protocol VersionedEntity: Codable {
    static var schemaVersion: SchemaVersion { get }
}

public struct PersistedEnvelope<Payload: Codable>: Codable {
    public let schemaVersion: Int
    public let persistedAt: Date
    public let payload: Payload

    public init(schemaVersion: Int = SchemaVersion.current.rawValue, persistedAt: Date = Date(), payload: Payload) {
        self.schemaVersion = schemaVersion
        self.persistedAt = persistedAt
        self.payload = payload
    }
}

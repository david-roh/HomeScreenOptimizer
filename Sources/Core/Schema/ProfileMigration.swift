import Foundation

private struct LegacyProfileV0: Codable {
    let id: UUID
    let name: String
    let context: String
    let dominantHand: String
    let createdAt: Date
    let updatedAt: Date
}

public enum ProfileMigrationError: Error {
    case unsupportedSchema(Int)
    case invalidLegacyData
}

public struct ProfileSchemaMigrator {
    public init() {}

    public func decodeProfiles(from data: Data) throws -> [Profile] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let envelope = try? decoder.decode(PersistedEnvelope<[Profile]>.self, from: data),
           envelope.schemaVersion == SchemaVersion.current.rawValue {
            return envelope.payload
        }

        if let envelope = try? decoder.decode(PersistedEnvelope<[LegacyProfileV0]>.self, from: data), envelope.schemaVersion == 0 {
            return envelope.payload.map(Self.convertLegacyProfile(_:))
        }

        if let legacy = try? decoder.decode([LegacyProfileV0].self, from: data) {
            return legacy.map(Self.convertLegacyProfile(_:))
        }

        throw ProfileMigrationError.invalidLegacyData
    }

    private static func convertLegacyProfile(_ legacy: LegacyProfileV0) -> Profile {
        let handedness: Handedness
        switch legacy.dominantHand.lowercased() {
        case "left":
            handedness = .left
        case "right":
            handedness = .right
        default:
            handedness = .alternating
        }

        let context = ProfileContext(rawValue: legacy.context) ?? .custom

        return Profile(
            id: legacy.id,
            name: legacy.name,
            context: context,
            handedness: handedness,
            gripMode: .oneHand,
            goalWeights: .default,
            reachabilityMap: ReachabilityMap(),
            createdAt: legacy.createdAt,
            updatedAt: legacy.updatedAt
        )
    }
}

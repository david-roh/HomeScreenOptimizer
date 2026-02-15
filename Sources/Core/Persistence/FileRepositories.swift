import Foundation

public final class FileProfileRepository: ProfileRepository {
    private let store: CollectionFileStore<Profile>

    public init(fileURL: URL) {
        let migrator = ProfileSchemaMigrator()
        store = CollectionFileStore(fileURL: fileURL, migrationDecoder: { data in
            try migrator.decodeProfiles(from: data)
        })
    }

    public func upsert(_ profile: Profile) throws {
        var profiles = try store.fetchAll()

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }

        try store.saveAll(profiles)
    }

    public func fetch(id: UUID) throws -> Profile? {
        try store.fetchAll().first { $0.id == id }
    }

    public func fetchAll() throws -> [Profile] {
        try store.fetchAll()
    }

    public func delete(id: UUID) throws {
        var profiles = try store.fetchAll()
        profiles.removeAll { $0.id == id }
        try store.saveAll(profiles)
    }
}

public final class FileLayoutPlanRepository: LayoutPlanRepository {
    private let store: CollectionFileStore<LayoutPlan>

    public init(fileURL: URL) {
        store = CollectionFileStore(fileURL: fileURL)
    }

    public func upsert(_ plan: LayoutPlan) throws {
        var plans = try store.fetchAll()

        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }

        try store.saveAll(plans)
    }

    public func fetch(id: UUID) throws -> LayoutPlan? {
        try store.fetchAll().first { $0.id == id }
    }

    public func fetchAll(for profileID: UUID? = nil) throws -> [LayoutPlan] {
        let plans = try store.fetchAll()
        guard let profileID else {
            return plans
        }

        return plans.filter { $0.profileID == profileID }
    }

    public func delete(id: UUID) throws {
        var plans = try store.fetchAll()
        plans.removeAll { $0.id == id }
        try store.saveAll(plans)
    }
}

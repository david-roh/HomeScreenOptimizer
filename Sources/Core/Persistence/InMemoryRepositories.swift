import Foundation

public final class InMemoryProfileRepository: @unchecked Sendable, ProfileRepository {
    private var storage: [UUID: Profile]

    public init(seed: [Profile] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func upsert(_ profile: Profile) {
        storage[profile.id] = profile
    }

    public func fetch(id: UUID) -> Profile? {
        storage[id]
    }

    public func fetchAll() -> [Profile] {
        storage.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func delete(id: UUID) {
        storage[id] = nil
    }
}

public final class InMemoryLayoutPlanRepository: @unchecked Sendable, LayoutPlanRepository {
    private var storage: [UUID: LayoutPlan]

    public init(seed: [LayoutPlan] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func upsert(_ plan: LayoutPlan) {
        storage[plan.id] = plan
    }

    public func fetch(id: UUID) -> LayoutPlan? {
        storage[id]
    }

    public func fetchAll(for profileID: UUID? = nil) -> [LayoutPlan] {
        let values = storage.values
        if let profileID {
            return values.filter { $0.profileID == profileID }.sorted { $0.generatedAt < $1.generatedAt }
        }

        return values.sorted { $0.generatedAt < $1.generatedAt }
    }

    public func delete(id: UUID) {
        storage[id] = nil
    }
}

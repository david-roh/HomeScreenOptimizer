import Foundation

public protocol ProfileRepository: Sendable {
    func upsert(_ profile: Profile) throws
    func fetch(id: UUID) throws -> Profile?
    func fetchAll() throws -> [Profile]
    func delete(id: UUID) throws
}

public protocol LayoutPlanRepository: Sendable {
    func upsert(_ plan: LayoutPlan) throws
    func fetch(id: UUID) throws -> LayoutPlan?
    func fetchAll(for profileID: UUID?) throws -> [LayoutPlan]
    func delete(id: UUID) throws
}

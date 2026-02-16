import Core
import Foundation

public protocol AnalyticsEventRepository: Sendable {
    func append(_ event: AnalyticsEvent) throws
    func fetchAll(limit: Int?) throws -> [AnalyticsEvent]
    func deleteAll() throws
}

public final class FileAnalyticsEventRepository: AnalyticsEventRepository {
    private let store: CollectionFileStore<AnalyticsEvent>

    public init(fileURL: URL) {
        store = CollectionFileStore(fileURL: fileURL)
    }

    public func append(_ event: AnalyticsEvent) throws {
        var events = try store.fetchAll()
        events.append(event)
        try store.saveAll(events)
    }

    public func fetchAll(limit: Int? = nil) throws -> [AnalyticsEvent] {
        let sorted = try store.fetchAll().sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }

        guard let limit else {
            return sorted
        }

        return Array(sorted.prefix(max(limit, 0)))
    }

    public func deleteAll() throws {
        try store.saveAll([])
    }
}

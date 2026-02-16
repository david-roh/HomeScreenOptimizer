import Core
import Foundation

public protocol UsageSnapshotRepository: Sendable {
    func upsert(_ snapshot: UsageSnapshot) throws
    func fetch(profileID: UUID) throws -> UsageSnapshot?
    func fetchAll() throws -> [UsageSnapshot]
    func delete(profileID: UUID) throws
}

public final class FileUsageSnapshotRepository: UsageSnapshotRepository {
    private let store: CollectionFileStore<UsageSnapshot>

    public init(fileURL: URL) {
        store = CollectionFileStore(fileURL: fileURL)
    }

    public func upsert(_ snapshot: UsageSnapshot) throws {
        var snapshots = try store.fetchAll()

        if let index = snapshots.firstIndex(where: { $0.profileID == snapshot.profileID }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }

        try store.saveAll(snapshots)
    }

    public func fetch(profileID: UUID) throws -> UsageSnapshot? {
        try store.fetchAll().first { $0.profileID == profileID }
    }

    public func fetchAll() throws -> [UsageSnapshot] {
        try store.fetchAll()
    }

    public func delete(profileID: UUID) throws {
        var snapshots = try store.fetchAll()
        snapshots.removeAll { $0.profileID == profileID }
        try store.saveAll(snapshots)
    }
}

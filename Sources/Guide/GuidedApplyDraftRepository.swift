import Core
import Foundation

public protocol GuidedApplyDraftRepository: Sendable {
    func upsert(_ draft: GuidedApplyDraft) throws
    func fetch(profileID: UUID) throws -> GuidedApplyDraft?
    func fetchAll() throws -> [GuidedApplyDraft]
    func delete(profileID: UUID) throws
}

public final class FileGuidedApplyDraftRepository: GuidedApplyDraftRepository {
    private let store: CollectionFileStore<GuidedApplyDraft>

    public init(fileURL: URL) {
        store = CollectionFileStore(fileURL: fileURL)
    }

    public func upsert(_ draft: GuidedApplyDraft) throws {
        var drafts = try store.fetchAll()

        if let index = drafts.firstIndex(where: { $0.profileID == draft.profileID }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }

        try store.saveAll(drafts)
    }

    public func fetch(profileID: UUID) throws -> GuidedApplyDraft? {
        try store.fetchAll().first { $0.profileID == profileID }
    }

    public func fetchAll() throws -> [GuidedApplyDraft] {
        try store.fetchAll()
    }

    public func delete(profileID: UUID) throws {
        var drafts = try store.fetchAll()
        drafts.removeAll { $0.profileID == profileID }
        try store.saveAll(drafts)
    }
}

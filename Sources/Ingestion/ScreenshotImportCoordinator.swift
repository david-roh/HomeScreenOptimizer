import Foundation

public enum ScreenshotImportError: Error {
    case invalidIndex
    case sessionNotFound
}

public final class ScreenshotImportCoordinator {
    private let repository: ScreenshotImportSessionRepository

    public init(repository: ScreenshotImportSessionRepository) {
        self.repository = repository
    }

    public func startSession() throws -> ScreenshotImportSession {
        let session = ScreenshotImportSession()
        try repository.upsert(session)
        return session
    }

    public func addPage(sessionID: UUID, filePath: String) throws -> ScreenshotImportSession {
        var session = try currentSession(id: sessionID)
        let page = ScreenshotPage(filePath: filePath, pageIndex: session.pages.count)
        session.pages.append(page)
        session.updatedAt = Date()
        try repository.upsert(session)
        return session
    }

    public func removePage(sessionID: UUID, pageID: UUID) throws -> ScreenshotImportSession {
        var session = try currentSession(id: sessionID)
        session.pages.removeAll { $0.id == pageID }
        session.pages = reindexPages(session.pages)
        session.updatedAt = Date()
        try repository.upsert(session)
        return session
    }

    public func reorderPages(sessionID: UUID, fromIndex: Int, toIndex: Int) throws -> ScreenshotImportSession {
        var session = try currentSession(id: sessionID)

        guard session.pages.indices.contains(fromIndex), session.pages.indices.contains(toIndex) else {
            throw ScreenshotImportError.invalidIndex
        }

        let page = session.pages.remove(at: fromIndex)
        session.pages.insert(page, at: toIndex)
        session.pages = reindexPages(session.pages)
        session.updatedAt = Date()

        try repository.upsert(session)
        return session
    }

    public func resumeSession(sessionID: UUID) throws -> ScreenshotImportSession {
        try currentSession(id: sessionID)
    }

    private func currentSession(id: UUID) throws -> ScreenshotImportSession {
        guard let session = try repository.fetch(id: id) else {
            throw ScreenshotImportError.sessionNotFound
        }

        return session
    }

    private func reindexPages(_ pages: [ScreenshotPage]) -> [ScreenshotPage] {
        pages.enumerated().map { index, page in
            var mutable = page
            mutable.pageIndex = index
            return mutable
        }
    }
}

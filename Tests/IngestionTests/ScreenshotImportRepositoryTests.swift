import Foundation
import Ingestion
import XCTest

final class ScreenshotImportRepositoryTests: XCTestCase {
    func testUpsertFetchPreservesFractionalSecondTimestamps() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-session-repository-\(UUID().uuidString).json")

        let repository = FileScreenshotImportSessionRepository(fileURL: fileURL)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000.123)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_010.789)

        let session = ScreenshotImportSession(createdAt: createdAt, updatedAt: updatedAt)
        try repository.upsert(session)

        let fetched = try repository.fetch(id: session.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.createdAt.timeIntervalSince1970 ?? 0, createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(fetched?.updatedAt.timeIntervalSince1970 ?? 0, updatedAt.timeIntervalSince1970, accuracy: 0.001)
    }
}

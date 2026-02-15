import Foundation
import Ingestion
import XCTest

final class ScreenshotImportCoordinatorTests: XCTestCase {
    func testAddReorderRemoveAndResume() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-session-\(UUID().uuidString).json")

        let repository = FileScreenshotImportSessionRepository(fileURL: fileURL)
        let coordinator = ScreenshotImportCoordinator(repository: repository)

        let session = try coordinator.startSession()
        let s1 = try coordinator.addPage(sessionID: session.id, filePath: "/tmp/page1.png")
        let s2 = try coordinator.addPage(sessionID: session.id, filePath: "/tmp/page2.png")

        XCTAssertEqual(s2.pages.count, 2)
        XCTAssertEqual(s2.pages[0].pageIndex, 0)
        XCTAssertEqual(s2.pages[1].pageIndex, 1)

        let reordered = try coordinator.reorderPages(sessionID: session.id, fromIndex: 0, toIndex: 1)
        XCTAssertEqual(reordered.pages[0].filePath, "/tmp/page2.png")
        XCTAssertEqual(reordered.pages[1].filePath, "/tmp/page1.png")

        let removed = try coordinator.removePage(sessionID: session.id, pageID: s1.pages[0].id)
        XCTAssertEqual(removed.pages.count, 1)

        let resumed = try coordinator.resumeSession(sessionID: session.id)
        XCTAssertEqual(resumed.pages.count, 1)
    }

    func testLatestSessionReturnsMostRecentlyUpdatedSession() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-session-latest-\(UUID().uuidString).json")

        let repository = FileScreenshotImportSessionRepository(fileURL: fileURL)
        let coordinator = ScreenshotImportCoordinator(repository: repository)

        let first = try coordinator.startSession()
        _ = try coordinator.addPage(sessionID: first.id, filePath: "/tmp/a.png")

        let second = try coordinator.startSession()
        _ = try coordinator.addPage(sessionID: second.id, filePath: "/tmp/b.png")
        _ = try coordinator.addPage(sessionID: second.id, filePath: "/tmp/c.png")

        let latest = try coordinator.latestSession()

        XCTAssertEqual(latest?.id, second.id)
        XCTAssertEqual(latest?.pages.count, 2)
    }
}

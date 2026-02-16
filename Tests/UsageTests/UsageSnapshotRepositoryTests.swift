import Foundation
import Usage
import XCTest

final class UsageSnapshotRepositoryTests: XCTestCase {
    func testCRUDByProfileID() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("usage-snapshots-\(UUID().uuidString).json")
        let repository = FileUsageSnapshotRepository(fileURL: fileURL)

        let profileID = UUID()
        var snapshot = UsageSnapshot(profileID: profileID, appMinutesByNormalizedName: ["maps": 30])
        try repository.upsert(snapshot)

        let fetched = try repository.fetch(profileID: profileID)
        XCTAssertEqual(fetched?.appMinutesByNormalizedName["maps"], 30)

        snapshot.appMinutesByNormalizedName["maps"] = 45
        try repository.upsert(snapshot)

        let fetchedAfterUpdate = try repository.fetch(profileID: profileID)
        XCTAssertEqual(fetchedAfterUpdate?.appMinutesByNormalizedName["maps"], 45)

        try repository.delete(profileID: profileID)
        XCTAssertNil(try repository.fetch(profileID: profileID))
    }
}

import Core
import Foundation
import XCTest

final class ProfileMigrationTests: XCTestCase {
    func testLegacyProfileV0MigratesToCurrentSchema() throws {
        let legacyID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        let updatedAt = Date(timeIntervalSince1970: 2000)

        let json = """
        [
          {
            "id": "\(legacyID.uuidString)",
            "name": "Legacy",
            "context": "workday",
            "dominantHand": "left",
            "createdAt": "1970-01-01T00:16:40Z",
            "updatedAt": "1970-01-01T00:33:20Z"
          }
        ]
        """

        let data = Data(json.utf8)
        let migrator = ProfileSchemaMigrator()
        let profiles = try migrator.decodeProfiles(from: data)

        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].id, legacyID)
        XCTAssertEqual(profiles[0].name, "Legacy")
        XCTAssertEqual(profiles[0].context, .workday)
        XCTAssertEqual(profiles[0].handedness, .left)
        XCTAssertEqual(profiles[0].createdAt, createdAt)
        XCTAssertEqual(profiles[0].updatedAt, updatedAt)
    }
}

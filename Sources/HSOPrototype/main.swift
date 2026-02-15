import Core
import Foundation
import Ingestion
import Profiles

let builder = OnboardingProfileBuilder()
let profile = builder.buildProfile(from: OnboardingAnswers(
    preferredName: "",
    context: .workday,
    handedness: .right,
    gripMode: .oneHand
))

print("Created profile: \(profile.name) (\(profile.handedness.rawValue), \(profile.gripMode.rawValue))")

let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("hso-import-session.json")
let importRepo = FileScreenshotImportSessionRepository(fileURL: tempFile)
let coordinator = ScreenshotImportCoordinator(repository: importRepo)
let session = try coordinator.startSession()
let updated = try coordinator.addPage(sessionID: session.id, filePath: "/tmp/home-page-1.png")

print("Import session pages: \(updated.pages.count)")

import Core
import Foundation
import Ingestion
import Profiles

let arguments = Array(CommandLine.arguments.dropFirst())

if let analyzeIndex = arguments.firstIndex(of: "--analyze-screenshot"),
   arguments.indices.contains(analyzeIndex + 1) {
    let screenshotPath = arguments[analyzeIndex + 1]
    let verbose = arguments.contains("--verbose")
    let mapper = HomeScreenGridMapper()
    let extractor = VisionLayoutOCRExtractor()

    do {
        let located = try await extractor.extractLocatedAppLabels(from: screenshotPath)
        let detection = mapper.map(locatedCandidates: located, page: 0, rows: 6, columns: 4)
        print("Detected labels: \(located.count)")
        if verbose {
            print("Raw labels:")
            for candidate in located.sorted(by: { $0.confidence > $1.confidence }) {
                let x = String(format: "%.3f", candidate.centerX)
                let y = String(format: "%.3f", candidate.centerY)
                let w = String(format: "%.3f", candidate.boxWidth)
                let h = String(format: "%.3f", candidate.boxHeight)
                print("- \(candidate.text) conf=\(String(format: "%.2f", candidate.confidence)) x=\(x) y=\(y) w=\(w) h=\(h)")
            }
        }
        print("Mapped apps: \(detection.apps.count)")
        print("Widget locked slots: \(detection.widgetLockedSlots.count)")
        for app in detection.apps {
            let zone = app.slot.type == .dock ? "dock" : "grid"
            print("- \(app.appName) [\(zone)] p\(app.slot.page + 1) r\(app.slot.row + 1) c\(app.slot.column + 1) conf=\(String(format: "%.2f", app.confidence))")
        }
        if !detection.widgetLockedSlots.isEmpty {
            print("Widget slots:")
            for slot in detection.widgetLockedSlots {
                print("- p\(slot.page + 1) r\(slot.row + 1) c\(slot.column + 1)")
            }
        }
    } catch {
        print("Mapping analysis failed: \(error.localizedDescription)")
    }

    exit(0)
}

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

do {
    let session = try coordinator.startSession()
    let updated = try coordinator.addPage(sessionID: session.id, filePath: "/tmp/home-page-1.png")
    print("Import session pages: \(updated.pages.count)")
} catch {
    print("Prototype flow failed: \(error.localizedDescription)")
}

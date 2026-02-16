import Core
import Ingestion
import SwiftUI
@testable import HomeScreenOptimizeriOS
import XCTest

@MainActor
final class RootViewModelTests: XCTestCase {
    func testCanSubmitProfileFalseWhenAllWeightsZero() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.utilityWeight = 0
        model.flowWeight = 0
        model.aestheticsWeight = 0
        model.moveCostWeight = 0

        XCTAssertFalse(model.canSubmitProfile)
    }

    func testApplyContextBaselineUsesExpectedWeights() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())

        model.applyContextBaseline(for: .workday)
        XCTAssertEqual(model.utilityWeight, 0.58, accuracy: 0.0001)
        XCTAssertEqual(model.flowWeight, 0.18, accuracy: 0.0001)
        XCTAssertEqual(model.aestheticsWeight, 0.09, accuracy: 0.0001)
        XCTAssertEqual(model.moveCostWeight, 0.15, accuracy: 0.0001)

        model.applyContextBaseline(for: .weekend)
        XCTAssertEqual(model.utilityWeight, 0.45, accuracy: 0.0001)
        XCTAssertEqual(model.flowWeight, 0.20, accuracy: 0.0001)
        XCTAssertEqual(model.aestheticsWeight, 0.20, accuracy: 0.0001)
        XCTAssertEqual(model.moveCostWeight, 0.15, accuracy: 0.0001)

        model.visualModeEnabled = true
        model.applyContextBaseline(for: .custom)
        XCTAssertEqual(model.utilityWeight, 0.45, accuracy: 0.0001)
        XCTAssertEqual(model.flowWeight, 0.20, accuracy: 0.0001)
        XCTAssertEqual(model.aestheticsWeight, 0.20, accuracy: 0.0001)
        XCTAssertEqual(model.moveCostWeight, 0.15, accuracy: 0.0001)
        XCTAssertFalse(model.visualModeEnabled)
    }

    func testSaveProfilePreservesManualIntentOverrideAfterContextBaseline() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.context = .weekend
        model.applyContextBaseline(for: .weekend)

        model.utilityWeight = 0.28
        model.flowWeight = 0.14
        model.aestheticsWeight = 0.08
        model.moveCostWeight = 0.50
        model.profileName = "Stable Override"

        model.saveProfile()

        guard let saved = model.savedProfiles.first(where: { $0.name == "Stable Override" }) else {
            XCTFail("Expected saved profile")
            return
        }
        XCTAssertEqual(saved.goalWeights.utility, 0.28, accuracy: 0.0001)
        XCTAssertEqual(saved.goalWeights.flow, 0.14, accuracy: 0.0001)
        XCTAssertEqual(saved.goalWeights.aesthetics, 0.08, accuracy: 0.0001)
        XCTAssertEqual(saved.goalWeights.moveCost, 0.50, accuracy: 0.0001)
    }

    func testAdjustDetectedSlotClampsToSupportedBounds() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.importSession = ScreenshotImportSession(
            pages: [
                ScreenshotPage(filePath: "/tmp/page-1.png", pageIndex: 0),
                ScreenshotPage(filePath: "/tmp/page-2.png", pageIndex: 1)
            ]
        )
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: Slot(page: 0, row: 0, column: 0))
        ]

        model.adjustDetectedSlot(index: 0, pageDelta: 9, rowDelta: -5, columnDelta: 9)

        XCTAssertEqual(model.detectedSlots[0].slot.page, 1)
        XCTAssertEqual(model.detectedSlots[0].slot.row, 0)
        XCTAssertEqual(model.detectedSlots[0].slot.column, 3)
    }

    func testHasSlotConflictsTrueWhenDuplicateSlotsPresent() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        let sharedSlot = Slot(page: 0, row: 2, column: 1)
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: sharedSlot),
            DetectedAppSlot(appName: "Mail", confidence: 0.8, slot: sharedSlot)
        ]

        XCTAssertTrue(model.hasSlotConflicts)
    }

    func testBindingForDetectedAppNameTrimsWhitespace() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: Slot(page: 0, row: 1, column: 1))
        ]

        let binding = model.bindingForDetectedAppName(index: 0)
        binding.wrappedValue = "  Google Maps  "

        XCTAssertEqual(model.detectedSlots[0].appName, "Google Maps")
    }

    func testManualUsageOverridesConfidenceWhenGeneratingGuide() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        let profile = Profile(
            name: "Tester",
            context: .workday,
            handedness: .right,
            gripMode: .oneHand
        )

        let easySlot = Slot(page: 0, row: 5, column: 3)
        let hardSlot = Slot(page: 0, row: 0, column: 0)

        model.savedProfiles = [profile]
        model.selectedProfileID = profile.id
        model.detectedSlots = [
            DetectedAppSlot(appName: "Alpha", confidence: 0.10, slot: hardSlot),
            DetectedAppSlot(appName: "Beta", confidence: 0.95, slot: easySlot)
        ]
        model.manualUsageEnabled = true
        model.bindingForUsageMinutes(appName: "Alpha").wrappedValue = "120"
        model.bindingForUsageMinutes(appName: "Beta").wrappedValue = "15"

        model.generateRecommendationGuide()

        let alphaSlot = model.recommendedLayoutAssignments
            .first(where: { model.displayName(for: $0.appID) == "Alpha" })?
            .slot

        XCTAssertEqual(alphaSlot, easySlot)
    }

    func testVisualPatternColorBandsReordersAssignmentsByStyle() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        let profile = Profile(
            name: "Visual",
            context: .workday,
            handedness: .right,
            gripMode: .oneHand
        )

        let easySlot = Slot(page: 0, row: 5, column: 3)
        let hardSlot = Slot(page: 0, row: 0, column: 0)

        model.savedProfiles = [profile]
        model.selectedProfileID = profile.id
        model.detectedSlots = [
            DetectedAppSlot(appName: "Calendar", confidence: 0.10, slot: hardSlot),
            DetectedAppSlot(appName: "Maps", confidence: 0.95, slot: easySlot)
        ]
        model.manualUsageEnabled = true
        model.bindingForUsageMinutes(appName: "Calendar").wrappedValue = "5"
        model.bindingForUsageMinutes(appName: "Maps").wrappedValue = "120"
        model.visualModeEnabled = true
        model.visualPatternMode = .colorBands

        model.generateRecommendationGuide()

        let calendarSlot = model.recommendedLayoutAssignments
            .first(where: { model.displayName(for: $0.appID) == "Calendar" })?
            .slot
        let mapsSlot = model.recommendedLayoutAssignments
            .first(where: { model.displayName(for: $0.appID) == "Maps" })?
            .slot

        XCTAssertEqual(calendarSlot, easySlot)
        XCTAssertEqual(mapsSlot, hardSlot)
    }

    func testSaveProfilePersistsCustomContextLabelOnlyForCustomContext() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        let nameSeed = UUID().uuidString

        model.profileName = "Custom-\(nameSeed)"
        model.context = .custom
        model.customContextLabel = "Commute"
        model.saveProfile()

        let customProfile = model.savedProfiles.first { $0.name == "Custom-\(nameSeed)" }
        XCTAssertEqual(customProfile?.context, .custom)
        XCTAssertEqual(customProfile?.customContextLabel, "Commute")

        model.profileName = "Workday-\(nameSeed)"
        model.context = .workday
        model.customContextLabel = "Should Clear"
        model.saveProfile()

        let workdayProfile = model.savedProfiles.first { $0.name == "Workday-\(nameSeed)" }
        XCTAssertEqual(workdayProfile?.context, .workday)
        XCTAssertNil(workdayProfile?.customContextLabel)
    }

    func testSaveProfileAutoNamesAndDeduplicates() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.profileName = ""
        model.context = .workday
        model.handedness = .right
        model.gripMode = .oneHand

        model.saveProfile()
        model.profileName = ""
        model.saveProfile()

        let names = model.savedProfiles.map(\.name)
        XCTAssertTrue(names.contains("Workday · Right · One-Hand"))
        XCTAssertTrue(names.contains("Workday · Right · One-Hand #2"))
    }

    func testSaveProfileAutoNameUsesCustomContextLabel() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.profileName = ""
        model.context = .custom
        model.customContextLabel = "Commute"
        model.handedness = .left
        model.gripMode = .twoHand

        model.saveProfile()

        XCTAssertTrue(model.savedProfiles.map(\.name).contains("Commute · Left · Two-Hand"))
    }

    func testSaveProfileClampsLongNameToEightyCharacters() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.profileName = String(repeating: "A", count: 120)

        model.saveProfile()

        let saved = model.savedProfiles.first { $0.name.hasPrefix("A") }
        XCTAssertEqual(saved?.name.count, 80)
    }

    func testSetDetectedSlotMovesIconPreviewToUpdatedSlot() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        let original = Slot(page: 0, row: 0, column: 0)
        let expected = Slot(page: 0, row: 4, column: 2)
        let marker = Data([0xCA, 0xFE])

        model.importSession = ScreenshotImportSession(
            pages: [ScreenshotPage(filePath: "/tmp/page.png", pageIndex: 0)]
        )
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: original)
        ]
        model.detectedIconPreviewDataBySlot = [original: marker]

        model.setDetectedSlot(index: 0, row: 4, column: 2)

        XCTAssertEqual(model.detectedSlots[0].slot, expected)
        XCTAssertNil(model.detectedIconPreviewDataBySlot[original])
        XCTAssertEqual(model.detectedIconPreviewDataBySlot[expected], marker)
    }

    func testPreviewIconDataResolvesByCanonicalDisplayName() throws {
        let model = configuredModelWithGeneratedGuide()
        let alphaID = try XCTUnwrap(
            model.currentLayoutAssignments
                .first(where: { model.displayName(for: $0.appID) == "Alpha" })?
                .appID
        )
        let alphaSlot = try XCTUnwrap(
            model.detectedSlots.first(where: { $0.appName == "Alpha" })?.slot
        )
        let iconData = Data([0x01, 0x02, 0x03])
        model.detectedIconPreviewDataBySlot = [alphaSlot: iconData]

        XCTAssertEqual(model.previewIconData(for: alphaID), iconData)
    }

    func testUsageEditorAppNamesDeduplicatesByCanonicalName() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        model.detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.9, slot: Slot(page: 0, row: 0, column: 0)),
            DetectedAppSlot(appName: " maps ", confidence: 0.7, slot: Slot(page: 0, row: 0, column: 1)),
            DetectedAppSlot(appName: "Mail", confidence: 0.8, slot: Slot(page: 0, row: 0, column: 2))
        ]

        XCTAssertEqual(model.usageEditorAppNames, ["Mail", "Maps"])
    }

    func testMarkNextMoveStepCompleteAdvancesProgress() {
        let model = configuredModelWithGeneratedGuide()
        XCTAssertFalse(model.moveSteps.isEmpty)
        XCTAssertEqual(model.completedMoveCount, 0)

        model.markNextMoveStepComplete()

        XCTAssertEqual(model.completedMoveCount, 1)
    }

    func testMarkNextMoveStepCompleteNoOpWhenNoSteps() {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())

        model.markNextMoveStepComplete()

        XCTAssertEqual(model.completedMoveCount, 0)
    }

    func testToggleMoveStepCompletionCanUncheck() throws {
        let model = configuredModelWithGeneratedGuide()
        let stepID = try XCTUnwrap(model.moveSteps.first?.id)

        model.toggleMoveStepCompletion(stepID)
        XCTAssertTrue(model.completedMoveStepIDs.contains(stepID))

        model.toggleMoveStepCompletion(stepID)
        XCTAssertFalse(model.completedMoveStepIDs.contains(stepID))
    }

    func testSecondGenerationStoresHistoryAndBuildsRerunComparison() {
        let model = configuredModelWithGeneratedGuide()
        XCTAssertEqual(model.recommendationHistory.count, 1)
        XCTAssertTrue(model.historyComparisonMessage.isEmpty)

        model.generateRecommendationGuide()

        XCTAssertEqual(model.recommendationHistory.count, 2)
        XCTAssertFalse(model.historyComparisonMessage.isEmpty)
    }

    func testCompareAgainstHistoryBuildsComparisonMessage() throws {
        let model = configuredModelWithGeneratedGuide()
        model.generateRecommendationGuide()
        XCTAssertEqual(model.recommendationHistory.count, 2)

        let baselineID = try XCTUnwrap(
            model.recommendationHistory
                .first(where: { $0.id != model.activeRecommendationPlanID })?
                .id
        )
        model.compareAgainstHistory(planID: baselineID)

        XCTAssertFalse(model.historyComparisonMessage.isEmpty)
        XCTAssertTrue(model.historyComparisonMessage.contains("Vs "))
    }

    func testCompareAgainstHistoryWithCurrentPlanClearsComparisonMessage() throws {
        let model = configuredModelWithGeneratedGuide()
        model.generateRecommendationGuide()
        model.historyComparisonMessage = "Previously set"

        let currentPlanID = try XCTUnwrap(model.activeRecommendationPlanID)
        model.compareAgainstHistory(planID: currentPlanID)

        XCTAssertTrue(model.historyComparisonMessage.isEmpty)
    }

    func testHandleProfileSelectionChangeClearsChecklistWhenNoDraftForSelectedProfile() {
        let model = configuredModelWithGeneratedGuide()
        let otherProfile = Profile(
            name: "Other",
            context: .weekend,
            handedness: .left,
            gripMode: .twoHand
        )

        model.savedProfiles.append(otherProfile)
        XCTAssertFalse(model.moveSteps.isEmpty)

        model.selectedProfileID = otherProfile.id
        model.handleProfileSelectionChange()

        XCTAssertTrue(model.moveSteps.isEmpty)
        XCTAssertTrue(model.completedMoveStepIDs.isEmpty)
    }

    func testHandleProfileSelectionChangeRestoresPersistedChecklistForProfile() {
        let model = configuredModelWithGeneratedGuide()
        let profileID = model.selectedProfileID
        XCTAssertEqual(model.completedMoveCount, 0)

        model.markNextMoveStepComplete()
        let completedCount = model.completedMoveCount
        XCTAssertGreaterThan(completedCount, 0)

        let otherProfile = Profile(
            name: "Other",
            context: .weekend,
            handedness: .left,
            gripMode: .twoHand
        )
        model.savedProfiles.append(otherProfile)
        model.selectedProfileID = otherProfile.id
        model.handleProfileSelectionChange()
        XCTAssertEqual(model.completedMoveCount, 0)
        XCTAssertTrue(model.moveSteps.isEmpty)

        model.selectedProfileID = profileID
        model.handleProfileSelectionChange()

        XCTAssertEqual(model.completedMoveCount, completedCount)
        XCTAssertFalse(model.moveSteps.isEmpty)
    }

    func testAllMovesCompletedTrueWhenEveryStepIsChecked() {
        let model = configuredModelWithGeneratedGuide()
        XCTAssertFalse(model.moveSteps.isEmpty)

        model.moveSteps.forEach { model.toggleMoveStepCompletion($0.id) }

        XCTAssertTrue(model.allMovesCompleted)
    }

    private func configuredModelWithGeneratedGuide() -> RootViewModel {
        let model = RootViewModel(ocrExtractor: StubLayoutExtractor())
        let profile = Profile(
            name: "Tester",
            context: .workday,
            handedness: .right,
            gripMode: .oneHand
        )

        model.savedProfiles = [profile]
        model.selectedProfileID = profile.id
        model.detectedSlots = [
            DetectedAppSlot(appName: "Alpha", confidence: 0.10, slot: Slot(page: 0, row: 0, column: 0)),
            DetectedAppSlot(appName: "Beta", confidence: 0.95, slot: Slot(page: 0, row: 5, column: 3))
        ]
        model.manualUsageEnabled = true
        model.bindingForUsageMinutes(appName: "Alpha").wrappedValue = "120"
        model.bindingForUsageMinutes(appName: "Beta").wrappedValue = "15"
        model.generateRecommendationGuide()

        return model
    }
}

private struct StubLayoutExtractor: LayoutOCRExtracting {
    func extractAppLabels(from imagePath: String) async throws -> [OCRLabelCandidate] {
        []
    }
}

import Core
import Foundation
import Guide
import Ingestion
import Optimizer
import PhotosUI
import Profiles
import Simulation
import SwiftUI

struct RootView: View {
    @StateObject private var model = RootViewModel()
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                if !model.statusMessage.isEmpty {
                    Section {
                        Label(model.statusMessage, systemImage: model.statusLevel.iconName)
                            .font(.footnote)
                            .foregroundStyle(model.statusLevel.tint)
                    }
                }

                onboardingSection
                calibrationSection
                profileListSection
                importSection
                recommendationSection
            }
            .navigationTitle("HomeScreenOptimizer")
            .onAppear {
                model.loadProfiles()
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else {
                    return
                }

                Task {
                    await model.handlePickedItem(item)
                    selectedItem = nil
                }
            }
        }
    }

    private var onboardingSection: some View {
        Section("Onboarding") {
            TextField("Profile name", text: $model.profileName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            Picker("Context", selection: $model.context) {
                ForEach(ProfileContext.allCases, id: \.self) { context in
                    Text(context.displayTitle).tag(context)
                }
            }

            Picker("Handedness", selection: $model.handedness) {
                ForEach(Handedness.allCases, id: \.self) { handedness in
                    Text(handedness.displayTitle).tag(handedness)
                }
            }

            Picker("Grip mode", selection: $model.gripMode) {
                ForEach(GripMode.allCases, id: \.self) { gripMode in
                    Text(gripMode.displayTitle).tag(gripMode)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                weightSlider(title: "Utility", value: $model.utilityWeight)
                weightSlider(title: "Flow", value: $model.flowWeight)
                weightSlider(title: "Aesthetics", value: $model.aestheticsWeight)
                weightSlider(title: "Move Cost", value: $model.moveCostWeight)
            }

            Button("Save Profile") {
                model.saveProfile()
            }
            .disabled(!model.canSubmitProfile)
        }
    }

    private var profileListSection: some View {
        Section("Saved Profiles") {
            if model.savedProfiles.isEmpty {
                Text("No saved profiles yet")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Active profile", selection: $model.selectedProfileID) {
                    ForEach(model.savedProfiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }

                ForEach(model.savedProfiles) { profile in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(profile.name)
                                .font(.headline)
                            if model.selectedProfileID == profile.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        Text("\(profile.context.displayTitle) • \(profile.handedness.displayTitle) • \(profile.gripMode.displayTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Refresh Profiles") {
                model.loadProfiles()
            }
        }
    }

    private var calibrationSection: some View {
        Section("Reachability Calibration") {
            Text("Tap the highlighted target as quickly as possible. This personalizes thumb-reach weighting.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let target = model.calibrationCurrentTarget {
                Text("Target \(model.calibrationProgressLabel): R\(target.row + 1) C\(target.column + 1)")
                    .font(.subheadline)
            } else {
                Text("No active calibration session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(calibrationCoordinates, id: \.id) { coordinate in
                    Button {
                        model.handleCalibrationTap(row: coordinate.row, column: coordinate.column)
                    } label: {
                        Text("\(coordinate.row + 1),\(coordinate.column + 1)")
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(model.calibrationButtonTint(row: coordinate.row, column: coordinate.column))
                    .disabled(!model.calibrationInProgress)
                }
            }

            Button(model.calibrationInProgress ? "Restart Calibration" : "Start Calibration") {
                model.startCalibration()
            }

            if !model.lastCalibrationMap.slotWeights.isEmpty {
                Text("Calibration saved with \(model.lastCalibrationMap.slotWeights.count) sampled targets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importSection: some View {
        Section("Screenshot Import") {
            if let session = model.importSession {
                Text("Session: \(session.id.uuidString.prefix(8))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Pages: \(session.pages.count)")
                    .font(.subheadline)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Add Screenshot", systemImage: "photo")
                }

                Button("Analyze Latest Screenshot (OCR)") {
                    Task {
                        await model.analyzeLatestScreenshot()
                    }
                }
                .disabled(session.pages.isEmpty)

                Button("Analyze All Screenshots (OCR)") {
                    Task {
                        await model.analyzeAllScreenshots()
                    }
                }
                .disabled(session.pages.isEmpty)

                if !model.ocrCandidates.isEmpty {
                    Text("OCR quality: \(model.ocrQuality.displayTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Array(model.ocrCandidates.prefix(8).enumerated()), id: \.offset) { _, candidate in
                        HStack {
                            Text(candidate.text)
                            Spacer()
                            Text(String(format: "%.2f", candidate.confidence))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                if !model.detectedSlots.isEmpty {
                    Text("Detected layout slots")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Array(model.detectedSlots.prefix(10).enumerated()), id: \.offset) { _, slot in
                        HStack {
                            Text(slot.appName)
                            Spacer()
                            Text("P\(slot.slot.page + 1) R\(slot.slot.row + 1) C\(slot.slot.column + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(session.pages) { page in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Page \(page.pageIndex + 1)")
                            Text(page.filePath)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()

                        Button {
                            model.movePageUp(pageID: page.id)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!model.canMovePageUp(pageID: page.id))

                        Button {
                            model.movePageDown(pageID: page.id)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!model.canMovePageDown(pageID: page.id))

                        Button("Delete", role: .destructive) {
                            model.removePage(pageID: page.id)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } else {
                Text("No active import session")
                    .foregroundStyle(.secondary)
            }

            Button(model.importSession == nil ? "Start Import Session" : "Reset Session") {
                model.startOrResetSession()
            }
        }
    }

    private var recommendationSection: some View {
        Section("Recommendation Guide") {
            if model.detectedSlots.isEmpty {
                Text("Import and analyze screenshots to generate a layout plan.")
                    .foregroundStyle(.secondary)
            } else {
                if let activeProfileName = model.activeProfileName {
                    Text("Active profile: \(activeProfileName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Save/select a profile to generate a recommendation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Generate Rearrangement Guide") {
                    model.generateRecommendationGuide()
                }
                .disabled(model.selectedProfileID == nil || model.detectedSlots.isEmpty)

                if let summary = model.simulationSummary {
                    Text("Score delta: \(String(format: "%+.3f", summary.aggregateScoreDelta))")
                        .font(.subheadline)
                    Text("Estimated moves: \(summary.moveCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !model.currentLayoutAssignments.isEmpty {
                    Text("Current layout")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Array(model.currentLayoutAssignments.prefix(8).enumerated()), id: \.offset) { _, assignment in
                        HStack {
                            Text(model.displayName(for: assignment.appID))
                            Spacer()
                            Text(slotLabel(assignment.slot))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !model.recommendedLayoutAssignments.isEmpty {
                    Text("Recommended layout")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Array(model.recommendedLayoutAssignments.prefix(8).enumerated()), id: \.offset) { _, assignment in
                        HStack {
                            Text(model.displayName(for: assignment.appID))
                            Spacer()
                            Text(slotLabel(assignment.slot))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !model.moveSteps.isEmpty {
                    Text("Manual move sequence")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(Array(model.moveSteps.prefix(12).enumerated()), id: \.offset) { index, step in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(index + 1). Move \(model.displayName(for: step.appID))")
                                .font(.subheadline)
                            Text("\(slotLabel(step.fromSlot)) → \(slotLabel(step.toSlot))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func weightSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...1)
        }
    }

    private func slotLabel(_ slot: Slot) -> String {
        "P\(slot.page + 1) R\(slot.row + 1) C\(slot.column + 1)"
    }

    private var calibrationCoordinates: [(row: Int, column: Int, id: String)] {
        (0..<6).flatMap { row in
            (0..<4).map { column in
                (row: row, column: column, id: "\(row)-\(column)")
            }
        }
    }
}

@MainActor
final class RootViewModel: ObservableObject {
    @Published var profileName = ""
    @Published var context: ProfileContext = .workday
    @Published var handedness: Handedness = .right
    @Published var gripMode: GripMode = .oneHand

    @Published var utilityWeight = GoalWeights.default.utility
    @Published var flowWeight = GoalWeights.default.flow
    @Published var aestheticsWeight = GoalWeights.default.aesthetics
    @Published var moveCostWeight = GoalWeights.default.moveCost

    @Published var savedProfiles: [Profile] = []
    @Published var selectedProfileID: UUID?
    @Published var importSession: ScreenshotImportSession?
    @Published var statusMessage = ""
    @Published var statusLevel: StatusLevel = .info
    @Published var ocrCandidates: [OCRLabelCandidate] = []
    @Published var ocrQuality: ImportQuality = .low
    @Published var detectedSlots: [DetectedAppSlot] = []
    @Published var calibrationInProgress = false
    @Published var calibrationCurrentTarget: Slot?
    @Published var calibrationProgressLabel = "0/0"
    @Published var lastCalibrationMap = ReachabilityMap()
    @Published var currentLayoutAssignments: [LayoutAssignment] = []
    @Published var recommendedLayoutAssignments: [LayoutAssignment] = []
    @Published var moveSteps: [MoveStep] = []
    @Published var simulationSummary: SimulationSummary?

    private let profileBuilder = OnboardingProfileBuilder()
    private let profileRepository: FileProfileRepository
    private let importCoordinator: ScreenshotImportCoordinator
    private let ocrExtractor: any LayoutOCRExtracting
    private let ocrPostProcessor = OCRPostProcessor()
    private let gridMapper = HomeScreenGridMapper()
    private let reachabilityCalibrator = ReachabilityCalibrator()
    private let layoutPlanner = ReachabilityAwareLayoutPlanner()
    private let movePlanBuilder = MovePlanBuilder()
    private let whatIfSimulation = WhatIfSimulation()
    private var calibrationTargets: [Slot] = []
    private var calibrationStartAt: Date?
    private var calibrationSamples: [CalibrationSample] = []
    private var appNamesByID: [UUID: String] = [:]

    init(ocrExtractor: any LayoutOCRExtracting = VisionLayoutOCRExtractor()) {
        self.ocrExtractor = ocrExtractor

        let baseURL: URL
        if let appData = try? AppDirectories.dataDirectory() {
            baseURL = appData
        } else {
            baseURL = FileManager.default.temporaryDirectory
        }

        profileRepository = FileProfileRepository(fileURL: baseURL.appendingPathComponent("profiles.json"))
        let importRepository = FileScreenshotImportSessionRepository(fileURL: baseURL.appendingPathComponent("import_sessions.json"))
        importCoordinator = ScreenshotImportCoordinator(repository: importRepository)

        restoreLatestImportSession()
    }

    var canSubmitProfile: Bool {
        (utilityWeight + flowWeight + aestheticsWeight + moveCostWeight) > 0.0001
    }

    var activeProfileName: String? {
        guard let selectedProfileID else {
            return nil
        }

        return savedProfiles.first { $0.id == selectedProfileID }?.name
    }

    func displayName(for appID: UUID) -> String {
        appNamesByID[appID] ?? "Unknown App"
    }

    func loadProfiles() {
        do {
            savedProfiles = try profileRepository.fetchAll()
            if selectedProfileID == nil || !savedProfiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = savedProfiles.first?.id
            }
        } catch {
            showStatus("Failed to load profiles: \(error.localizedDescription)", level: .error)
        }
    }

    func saveProfile() {
        guard canSubmitProfile else {
            showStatus("Set at least one weight above zero before saving.", level: .error)
            return
        }

        let answers = OnboardingAnswers(
            preferredName: profileName,
            context: context,
            handedness: handedness,
            gripMode: gripMode,
            goalWeights: GoalWeights(
                utility: utilityWeight,
                flow: flowWeight,
                aesthetics: aestheticsWeight,
                moveCost: moveCostWeight
            )
        )

        var profile = profileBuilder.buildProfile(from: answers)
        if !lastCalibrationMap.slotWeights.isEmpty {
            profile.reachabilityMap = lastCalibrationMap
        }

        do {
            try profileRepository.upsert(profile)
            loadProfiles()
            selectedProfileID = profile.id
            showStatus("Saved profile \"\(profile.name)\".", level: .success)
        } catch {
            showStatus("Failed to save profile: \(error.localizedDescription)", level: .error)
        }
    }

    func startOrResetSession() {
        do {
            importSession = try importCoordinator.startSession()
            ocrCandidates = []
            ocrQuality = .low
            detectedSlots = []
            resetRecommendationOutput()
            showStatus("Import session ready.", level: .success)
        } catch {
            showStatus("Failed to create session: \(error.localizedDescription)", level: .error)
        }
    }

    func handlePickedItem(_ item: PhotosPickerItem) async {
        guard let session = importSession else {
            showStatus("Start an import session first.", level: .error)
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                showStatus("Could not read selected image.", level: .error)
                return
            }

            let fileURL = try writeImageToTemporaryFile(data: data)
            importSession = try importCoordinator.addPage(sessionID: session.id, filePath: fileURL.path)
            showStatus("Screenshot added.", level: .success)
        } catch {
            showStatus("Failed to add screenshot: \(error.localizedDescription)", level: .error)
        }
    }

    func removePage(pageID: UUID) {
        guard let session = importSession else {
            return
        }

        do {
            importSession = try importCoordinator.removePage(sessionID: session.id, pageID: pageID)
            ocrCandidates = []
            ocrQuality = .low
            detectedSlots = []
            resetRecommendationOutput()
            showStatus("Removed screenshot.", level: .success)
        } catch {
            showStatus("Failed to remove screenshot: \(error.localizedDescription)", level: .error)
        }
    }

    func canMovePageUp(pageID: UUID) -> Bool {
        guard let index = indexForPage(id: pageID) else {
            return false
        }

        return index > 0
    }

    func canMovePageDown(pageID: UUID) -> Bool {
        guard let session = importSession, let index = indexForPage(id: pageID) else {
            return false
        }

        return index < session.pages.count - 1
    }

    func movePageUp(pageID: UUID) {
        movePage(pageID: pageID, offset: -1)
    }

    func movePageDown(pageID: UUID) {
        movePage(pageID: pageID, offset: 1)
    }

    func analyzeLatestScreenshot() async {
        guard let latestPage = importSession?.pages.last else {
            showStatus("Add a screenshot before running OCR.", level: .error)
            return
        }

        await analyzeScreenshots([latestPage])
    }

    func analyzeAllScreenshots() async {
        guard let pages = importSession?.pages, !pages.isEmpty else {
            showStatus("Add at least one screenshot before analysis.", level: .error)
            return
        }

        await analyzeScreenshots(pages.sorted { $0.pageIndex < $1.pageIndex })
    }

    func generateRecommendationGuide() {
        guard let profile = activeProfile() else {
            showStatus("Select a saved profile first.", level: .error)
            return
        }

        guard !detectedSlots.isEmpty else {
            showStatus("Analyze screenshots before generating a guide.", level: .error)
            return
        }

        let sortedDetectedSlots = detectedSlots.sorted { lhs, rhs in
            if lhs.slot.page != rhs.slot.page {
                return lhs.slot.page < rhs.slot.page
            }
            if lhs.slot.row != rhs.slot.row {
                return lhs.slot.row < rhs.slot.row
            }

            return lhs.slot.column < rhs.slot.column
        }

        var apps: [AppItem] = []
        var assignments: [LayoutAssignment] = []
        var appNames: [UUID: String] = [:]

        for detected in sortedDetectedSlots {
            let app = AppItem(displayName: detected.appName, usageScore: max(0.05, detected.confidence))
            apps.append(app)
            assignments.append(LayoutAssignment(appID: app.id, slot: detected.slot))
            appNames[app.id] = app.displayName
        }

        let generated = layoutPlanner.generate(
            profile: profile,
            apps: apps,
            currentAssignments: assignments
        )
        let planMoves = movePlanBuilder.buildMoves(
            current: assignments,
            target: generated.recommendedPlan.assignments
        )
        let simulation = whatIfSimulation.compare(
            currentScore: generated.currentScore,
            candidateScore: generated.recommendedPlan.scoreBreakdown,
            moveCount: planMoves.count
        )

        currentLayoutAssignments = assignments
        recommendedLayoutAssignments = generated.recommendedPlan.assignments
        moveSteps = planMoves
        simulationSummary = simulation
        appNamesByID = appNames

        showStatus("Generated guide with \(planMoves.count) moves.", level: .success)
    }

    private func analyzeScreenshots(_ pages: [ScreenshotPage]) async {
        resetRecommendationOutput()

        do {
            var mergedCandidates: [OCRLabelCandidate] = []
            var mergedDetectedSlots: [DetectedAppSlot] = []
            let locatingExtractor = ocrExtractor as? any LayoutOCRLocating

            for page in pages {
                let extracted = try await ocrExtractor.extractAppLabels(from: page.filePath)
                mergedCandidates.append(contentsOf: extracted)

                if let locatingExtractor {
                    let located = try await locatingExtractor.extractLocatedAppLabels(from: page.filePath)
                    let mapped = gridMapper.map(locatedCandidates: located, page: page.pageIndex)
                    mergedDetectedSlots.append(contentsOf: mapped.apps)
                }
            }

            ocrCandidates = ocrPostProcessor.process(mergedCandidates)
            ocrQuality = ocrPostProcessor.estimateImportQuality(from: ocrCandidates)
            detectedSlots = mergedDetectedSlots
                .sorted { lhs, rhs in
                    if lhs.slot.page != rhs.slot.page {
                        return lhs.slot.page < rhs.slot.page
                    }
                    if lhs.slot.row != rhs.slot.row {
                        return lhs.slot.row < rhs.slot.row
                    }
                    return lhs.slot.column < rhs.slot.column
                }

            if ocrCandidates.isEmpty {
                showStatus("No likely app labels detected.", level: .info)
            } else {
                showStatus(
                    "Extracted \(ocrCandidates.count) app labels and mapped \(detectedSlots.count) slots.",
                    level: .success
                )
            }
        } catch {
            showStatus("OCR failed: \(error.localizedDescription)", level: .error)
        }
    }

    func restoreLatestImportSession() {
        do {
            guard let latest = try importCoordinator.latestSession() else {
                return
            }

            importSession = latest
            if !latest.pages.isEmpty {
                showStatus("Resumed latest import session (\(latest.pages.count) pages).", level: .info)
            }
        } catch {
            showStatus("Failed to restore latest session: \(error.localizedDescription)", level: .error)
        }
    }

    func startCalibration() {
        calibrationTargets = [
            Slot(page: 0, row: 5, column: 3),
            Slot(page: 0, row: 5, column: 0),
            Slot(page: 0, row: 4, column: 2),
            Slot(page: 0, row: 4, column: 1),
            Slot(page: 0, row: 2, column: 3),
            Slot(page: 0, row: 2, column: 0),
            Slot(page: 0, row: 0, column: 3),
            Slot(page: 0, row: 0, column: 0)
        ]

        calibrationSamples = []
        calibrationInProgress = true
        calibrationCurrentTarget = calibrationTargets.first
        calibrationStartAt = Date()
        updateCalibrationProgress()
        showStatus("Calibration started.", level: .info)
    }

    func handleCalibrationTap(row: Int, column: Int) {
        guard calibrationInProgress, let target = calibrationCurrentTarget else {
            return
        }

        let tapped = Slot(page: 0, row: row, column: column)
        guard tapped == target else {
            showStatus("Tap the highlighted target.", level: .info)
            return
        }

        let elapsedMs = max(1, Date().timeIntervalSince(calibrationStartAt ?? Date()) * 1000)
        calibrationSamples.append(CalibrationSample(slot: target, responseTimeMs: elapsedMs))

        calibrationTargets.removeFirst()

        if calibrationTargets.isEmpty {
            calibrationInProgress = false
            calibrationCurrentTarget = nil
            calibrationStartAt = nil
            lastCalibrationMap = reachabilityCalibrator.buildReachabilityMap(from: calibrationSamples)
            showStatus("Calibration complete. Reachability map updated.", level: .success)
            updateCalibrationProgress()
            return
        }

        calibrationCurrentTarget = calibrationTargets.first
        calibrationStartAt = Date()
        updateCalibrationProgress()
    }

    func calibrationButtonTint(row: Int, column: Int) -> Color {
        guard calibrationInProgress, let target = calibrationCurrentTarget else {
            return .gray
        }

        if target.row == row, target.column == column {
            return .orange
        }

        return .gray
    }

    private func activeProfile() -> Profile? {
        guard let selectedProfileID else {
            return nil
        }

        return savedProfiles.first { $0.id == selectedProfileID }
    }

    private func resetRecommendationOutput() {
        currentLayoutAssignments = []
        recommendedLayoutAssignments = []
        moveSteps = []
        simulationSummary = nil
        appNamesByID = [:]
    }

    private func writeImageToTemporaryFile(data: Data) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HSOImports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileURL = folder.appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func movePage(pageID: UUID, offset: Int) {
        guard let session = importSession, let index = indexForPage(id: pageID) else {
            return
        }

        let destination = index + offset
        guard session.pages.indices.contains(destination) else {
            return
        }

        do {
            importSession = try importCoordinator.reorderPages(
                sessionID: session.id,
                fromIndex: index,
                toIndex: destination
            )
            showStatus("Reordered import pages.", level: .success)
        } catch {
            showStatus("Failed to reorder pages: \(error.localizedDescription)", level: .error)
        }
    }

    private func indexForPage(id: UUID) -> Int? {
        importSession?.pages.firstIndex { $0.id == id }
    }

    private func showStatus(_ message: String, level: StatusLevel = .info) {
        statusMessage = message
        statusLevel = level
    }

    private func updateCalibrationProgress() {
        let completed = calibrationSamples.count
        let total = calibrationSamples.count + calibrationTargets.count
        let current = calibrationInProgress ? min(completed + 1, max(total, 1)) : completed
        calibrationProgressLabel = "\(current)/\(max(total, 1))"
    }
}

enum StatusLevel {
    case info
    case success
    case error

    var tint: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

private extension ProfileContext {
    var displayTitle: String {
        switch self {
        case .workday:
            return "Workday"
        case .weekend:
            return "Weekend"
        case .custom:
            return "Custom"
        }
    }
}

private extension Handedness {
    var displayTitle: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .alternating:
            return "Alternating"
        }
    }
}

private extension GripMode {
    var displayTitle: String {
        switch self {
        case .oneHand:
            return "One-Hand"
        case .twoHand:
            return "Two-Hand"
        }
    }
}

private extension ImportQuality {
    var displayTitle: String {
        switch self {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }
}

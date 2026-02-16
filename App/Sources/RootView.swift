import Core
import Foundation
import Guide
import Ingestion
import Optimizer
import PhotosUI
import Profiles
import Simulation
import SwiftUI
import Usage

struct RootView: View {
    @StateObject private var model = RootViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedUsageItem: PhotosPickerItem?

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
            .onChange(of: model.selectedProfileID) { _, _ in
                model.handleProfileSelectionChange()
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
            .onChange(of: selectedUsageItem) { _, item in
                guard let item else {
                    return
                }

                Task {
                    await model.handlePickedUsageItem(item)
                    selectedUsageItem = nil
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
                    Text("Detected layout slots (editable)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if model.hasSlotConflicts {
                        Label("Some apps share the same slot. Adjust before generating.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Button("Reset OCR Corrections") {
                        model.resetDetectedSlotCorrections()
                    }
                    .font(.footnote)

                    ForEach(Array(model.detectedSlots.prefix(12).indices), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                "App name",
                                text: model.bindingForDetectedAppName(index: index)
                            )
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Page \(model.detectedSlots[index].slot.page + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        Button {
                                            model.adjustDetectedSlot(index: index, pageDelta: -1)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                        }
                                        Button {
                                            model.adjustDetectedSlot(index: index, pageDelta: 1)
                                        } label: {
                                            Image(systemName: "plus.circle")
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Row \(model.detectedSlots[index].slot.row + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        Button {
                                            model.adjustDetectedSlot(index: index, rowDelta: -1)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                        }
                                        Button {
                                            model.adjustDetectedSlot(index: index, rowDelta: 1)
                                        } label: {
                                            Image(systemName: "plus.circle")
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Col \(model.detectedSlots[index].slot.column + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        Button {
                                            model.adjustDetectedSlot(index: index, columnDelta: -1)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                        }
                                        Button {
                                            model.adjustDetectedSlot(index: index, columnDelta: 1)
                                        } label: {
                                            Image(systemName: "plus.circle")
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
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

                Toggle("Use manual usage input", isOn: $model.manualUsageEnabled)

                if model.manualUsageEnabled {
                    Text("Enter minutes per day for each app to drive utility ranking.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    PhotosPicker(selection: $selectedUsageItem, matching: .images) {
                        Label("Import Screen Time Screenshot", systemImage: "chart.bar.doc.horizontal")
                    }
                    .disabled(model.selectedProfileID == nil)

                    if !model.importedUsageEntries.isEmpty {
                        Text("Latest imported usage")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ForEach(Array(model.importedUsageEntries.prefix(6).enumerated()), id: \.offset) { _, entry in
                            HStack {
                                Text(entry.appName)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(entry.minutesPerDay)) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(model.usageEditorAppNames, id: \.self) { appName in
                        HStack {
                            Text(appName)
                                .lineLimit(1)
                            Spacer()
                            TextField(
                                "min/day",
                                text: model.bindingForUsageMinutes(appName: appName)
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                        }
                    }

                    HStack {
                        Button("Load Saved Usage") {
                            model.loadManualUsageSnapshot()
                        }
                        .disabled(model.selectedProfileID == nil)

                        Spacer()

                        Button("Save Usage") {
                            model.saveManualUsageSnapshot()
                        }
                        .disabled(model.selectedProfileID == nil || model.usageEditorAppNames.isEmpty)
                    }
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
                    HStack {
                        Text("Guided apply checklist")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(model.moveProgressText)
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(model.allMovesCompleted ? .green : .secondary)
                    }

                    HStack {
                        Button("Mark Next Complete") {
                            model.markNextMoveStepComplete()
                        }
                        .disabled(model.allMovesCompleted)

                        Spacer()

                        Button("Reset Progress") {
                            model.resetMoveProgress()
                        }
                    }
                    .buttonStyle(.borderless)

                    ForEach(Array(model.moveSteps.prefix(20).enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Button {
                                model.toggleMoveStepCompletion(step.id)
                            } label: {
                                Image(systemName: model.completedMoveStepIDs.contains(step.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(model.completedMoveStepIDs.contains(step.id) ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(index + 1). Move \(model.displayName(for: step.appID))")
                                    .font(.subheadline)
                                    .foregroundStyle(model.completedMoveStepIDs.contains(step.id) ? .secondary : .primary)
                                Text("\(slotLabel(step.fromSlot)) → \(slotLabel(step.toSlot))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if model.nextPendingMoveStepID == step.id {
                                    Text("Next recommended step")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
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
    @Published var manualUsageEnabled = false
    @Published var usageDraftByNormalizedName: [String: String] = [:]
    @Published var importedUsageEntries: [ScreenTimeUsageEntry] = []
    @Published var completedMoveStepIDs: Set<UUID> = []
    @Published var activeRecommendationPlanID: UUID?

    private let profileBuilder = OnboardingProfileBuilder()
    private let profileRepository: FileProfileRepository
    private let usageRepository: FileUsageSnapshotRepository
    private let guidedApplyDraftRepository: FileGuidedApplyDraftRepository
    private let importCoordinator: ScreenshotImportCoordinator
    private let ocrExtractor: any LayoutOCRExtracting
    private let ocrPostProcessor = OCRPostProcessor()
    private let gridMapper = HomeScreenGridMapper()
    private let screenTimeUsageParser = ScreenTimeUsageParser()
    private let reachabilityCalibrator = ReachabilityCalibrator()
    private let usageNormalizer = UsageNormalizer()
    private let layoutPlanner = ReachabilityAwareLayoutPlanner()
    private let movePlanBuilder = MovePlanBuilder()
    private let whatIfSimulation = WhatIfSimulation()
    private var calibrationTargets: [Slot] = []
    private var calibrationStartAt: Date?
    private var calibrationSamples: [CalibrationSample] = []
    private var appNamesByID: [UUID: String] = [:]
    private var originalDetectedSlots: [DetectedAppSlot] = []

    init(ocrExtractor: any LayoutOCRExtracting = VisionLayoutOCRExtractor()) {
        self.ocrExtractor = ocrExtractor

        let baseURL: URL
        if let appData = try? AppDirectories.dataDirectory() {
            baseURL = appData
        } else {
            baseURL = FileManager.default.temporaryDirectory
        }

        profileRepository = FileProfileRepository(fileURL: baseURL.appendingPathComponent("profiles.json"))
        usageRepository = FileUsageSnapshotRepository(fileURL: baseURL.appendingPathComponent("usage_snapshots.json"))
        guidedApplyDraftRepository = FileGuidedApplyDraftRepository(fileURL: baseURL.appendingPathComponent("guided_apply_drafts.json"))
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

    var hasSlotConflicts: Bool {
        var seen: Set<Slot> = []
        for detected in detectedSlots {
            if seen.contains(detected.slot) {
                return true
            }
            seen.insert(detected.slot)
        }
        return false
    }

    var usageEditorAppNames: [String] {
        var seen: Set<String> = []
        var ordered: [String] = []

        for detected in detectedSlots {
            let displayName = detected.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            let canonical = canonicalAppName(displayName)
            guard !canonical.isEmpty, !seen.contains(canonical) else {
                continue
            }
            seen.insert(canonical)
            ordered.append(displayName)
        }

        return ordered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var completedMoveCount: Int {
        moveSteps.filter { completedMoveStepIDs.contains($0.id) }.count
    }

    var moveProgressText: String {
        "\(completedMoveCount)/\(moveSteps.count)"
    }

    var allMovesCompleted: Bool {
        !moveSteps.isEmpty && completedMoveCount == moveSteps.count
    }

    var nextPendingMoveStepID: UUID? {
        moveSteps.first { !completedMoveStepIDs.contains($0.id) }?.id
    }

    func displayName(for appID: UUID) -> String {
        appNamesByID[appID] ?? "Unknown App"
    }

    func bindingForUsageMinutes(appName: String) -> Binding<String> {
        let key = canonicalAppName(appName)
        return Binding(
            get: {
                self.usageDraftByNormalizedName[key] ?? ""
            },
            set: { newValue in
                self.usageDraftByNormalizedName[key] = newValue
            }
        )
    }

    func bindingForDetectedAppName(index: Int) -> Binding<String> {
        Binding(
            get: {
                guard self.detectedSlots.indices.contains(index) else {
                    return ""
                }
                return self.detectedSlots[index].appName
            },
            set: { newValue in
                guard self.detectedSlots.indices.contains(index) else {
                    return
                }
                let oldName = self.detectedSlots[index].appName
                let oldKey = self.canonicalAppName(oldName)
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                self.detectedSlots[index].appName = trimmed

                let newKey = self.canonicalAppName(trimmed)
                guard oldKey != newKey, !oldKey.isEmpty, !newKey.isEmpty else {
                    self.hydrateUsageDraftFromDetectedApps()
                    return
                }

                if let oldValue = self.usageDraftByNormalizedName.removeValue(forKey: oldKey),
                   self.usageDraftByNormalizedName[newKey] == nil {
                    self.usageDraftByNormalizedName[newKey] = oldValue
                }

                self.hydrateUsageDraftFromDetectedApps()
            }
        )
    }

    func loadProfiles() {
        do {
            savedProfiles = try profileRepository.fetchAll()
            if selectedProfileID == nil || !savedProfiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = savedProfiles.first?.id
            }
            loadUsageSnapshotForSelectedProfile()
            loadGuidedApplyDraftForSelectedProfile()
        } catch {
            showStatus("Failed to load profiles: \(error.localizedDescription)", level: .error)
        }
    }

    func handleProfileSelectionChange() {
        loadUsageSnapshotForSelectedProfile()
        loadGuidedApplyDraftForSelectedProfile()
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
            loadUsageSnapshotForSelectedProfile()
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

    func handlePickedUsageItem(_ item: PhotosPickerItem) async {
        guard selectedProfileID != nil else {
            showStatus("Select a profile before importing usage.", level: .error)
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                showStatus("Could not read selected usage screenshot.", level: .error)
                return
            }

            let fileURL = try writeImageToTemporaryFile(data: data)
            let entries: [ScreenTimeUsageEntry]

            if let locatingExtractor = ocrExtractor as? any LayoutOCRLocating {
                let located = try await locatingExtractor.extractLocatedAppLabels(from: fileURL.path)
                entries = screenTimeUsageParser.parse(from: located)
            } else {
                let labels = try await ocrExtractor.extractAppLabels(from: fileURL.path)
                entries = screenTimeUsageParser.parse(from: labels)
            }

            guard !entries.isEmpty else {
                showStatus("No app usage durations detected in screenshot.", level: .info)
                return
            }

            applyImportedUsage(entries)
            showStatus("Imported usage for \(entries.count) apps.", level: .success)
        } catch {
            showStatus("Failed to import usage screenshot: \(error.localizedDescription)", level: .error)
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

        guard !hasSlotConflicts else {
            showStatus("Resolve duplicate slot conflicts before generating a guide.", level: .error)
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
        let manualUsageByName = manualUsageEnabled
            ? usageNormalizer.normalize(minutesByName: parsedManualUsageMinutes())
            : [:]

        for detected in sortedDetectedSlots {
            let canonicalName = canonicalAppName(detected.appName)
            let usageScore = manualUsageByName[canonicalName] ?? max(0.05, detected.confidence)
            let app = AppItem(displayName: detected.appName, usageScore: usageScore)
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
        activeRecommendationPlanID = generated.recommendedPlan.id
        completedMoveStepIDs = []
        persistGuidedApplyDraft()

        showStatus("Generated guide with \(planMoves.count) moves.", level: .success)
    }

    func loadManualUsageSnapshot() {
        guard let profileID = selectedProfileID else {
            showStatus("Select a profile before loading usage data.", level: .error)
            return
        }

        do {
            guard let snapshot = try usageRepository.fetch(profileID: profileID) else {
                usageDraftByNormalizedName = [:]
                importedUsageEntries = []
                showStatus("No saved manual usage for this profile yet.", level: .info)
                return
            }

            usageDraftByNormalizedName = Dictionary(uniqueKeysWithValues: snapshot.appMinutesByNormalizedName.map { key, value in
                (key, String(format: "%.0f", value))
            })
            manualUsageEnabled = true
            importedUsageEntries = []
            hydrateUsageDraftFromDetectedApps()
            showStatus("Loaded saved manual usage for profile.", level: .success)
        } catch {
            showStatus("Failed to load usage data: \(error.localizedDescription)", level: .error)
        }
    }

    func saveManualUsageSnapshot() {
        guard let profileID = selectedProfileID else {
            showStatus("Select a profile before saving usage data.", level: .error)
            return
        }

        do {
            let parsed = parsedManualUsageMinutes()

            if parsed.isEmpty {
                try usageRepository.delete(profileID: profileID)
                showStatus("Cleared saved manual usage for this profile.", level: .info)
                return
            }

            var snapshot = try usageRepository.fetch(profileID: profileID) ?? UsageSnapshot(profileID: profileID)
            snapshot.appMinutesByNormalizedName = parsed
            snapshot.updatedAt = Date()

            try usageRepository.upsert(snapshot)
            showStatus("Saved manual usage for \(parsed.count) apps.", level: .success)
        } catch {
            showStatus("Failed to save usage data: \(error.localizedDescription)", level: .error)
        }
    }

    func adjustDetectedSlot(
        index: Int,
        pageDelta: Int = 0,
        rowDelta: Int = 0,
        columnDelta: Int = 0
    ) {
        guard detectedSlots.indices.contains(index) else {
            return
        }

        var mutable = detectedSlots[index]
        let pageUpperBound = max((importSession?.pages.count ?? 1) - 1, 0)
        let rowUpperBound = 5
        let columnUpperBound = 3

        mutable.slot.page = min(max(0, mutable.slot.page + pageDelta), pageUpperBound)
        mutable.slot.row = min(max(0, mutable.slot.row + rowDelta), rowUpperBound)
        mutable.slot.column = min(max(0, mutable.slot.column + columnDelta), columnUpperBound)
        detectedSlots[index] = mutable
    }

    func resetDetectedSlotCorrections() {
        guard !originalDetectedSlots.isEmpty else {
            return
        }

        detectedSlots = originalDetectedSlots
        hydrateUsageDraftFromDetectedApps()
        showStatus("Restored OCR-detected labels and slots.", level: .info)
    }

    func toggleMoveStepCompletion(_ stepID: UUID) {
        if completedMoveStepIDs.contains(stepID) {
            completedMoveStepIDs.remove(stepID)
        } else {
            completedMoveStepIDs.insert(stepID)
        }

        persistGuidedApplyDraft()
    }

    func markNextMoveStepComplete() {
        guard let next = nextPendingMoveStepID else {
            return
        }

        completedMoveStepIDs.insert(next)
        persistGuidedApplyDraft()
    }

    func resetMoveProgress() {
        completedMoveStepIDs = []
        persistGuidedApplyDraft()
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
            originalDetectedSlots = detectedSlots
            hydrateUsageDraftFromDetectedApps()

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

    private func loadUsageSnapshotForSelectedProfile() {
        guard let profileID = selectedProfileID else {
            usageDraftByNormalizedName = [:]
            manualUsageEnabled = false
            importedUsageEntries = []
            return
        }

        do {
            if let snapshot = try usageRepository.fetch(profileID: profileID) {
                usageDraftByNormalizedName = Dictionary(
                    uniqueKeysWithValues: snapshot.appMinutesByNormalizedName.map { key, value in
                        (key, String(format: "%.0f", value))
                    }
                )
                manualUsageEnabled = true
            } else {
                usageDraftByNormalizedName = [:]
                manualUsageEnabled = false
            }

            importedUsageEntries = []
            hydrateUsageDraftFromDetectedApps()
        } catch {
            usageDraftByNormalizedName = [:]
            manualUsageEnabled = false
            importedUsageEntries = []
            showStatus("Failed to load usage snapshot: \(error.localizedDescription)", level: .error)
        }
    }

    private func loadGuidedApplyDraftForSelectedProfile() {
        guard let profileID = selectedProfileID else {
            currentLayoutAssignments = []
            recommendedLayoutAssignments = []
            moveSteps = []
            simulationSummary = nil
            appNamesByID = [:]
            completedMoveStepIDs = []
            activeRecommendationPlanID = nil
            return
        }

        do {
            guard let draft = try guidedApplyDraftRepository.fetch(profileID: profileID) else {
                currentLayoutAssignments = []
                recommendedLayoutAssignments = []
                moveSteps = []
                simulationSummary = nil
                appNamesByID = [:]
                completedMoveStepIDs = []
                activeRecommendationPlanID = nil
                return
            }

            currentLayoutAssignments = draft.currentAssignments
            recommendedLayoutAssignments = draft.recommendedAssignments
            moveSteps = draft.moveSteps
            appNamesByID = draft.appNamesByID
            activeRecommendationPlanID = draft.planID
            simulationSummary = nil
            completedMoveStepIDs = draft.completedStepIDs
        } catch {
            showStatus("Failed to load guided apply draft: \(error.localizedDescription)", level: .error)
        }
    }

    private func persistGuidedApplyDraft() {
        guard let profileID = selectedProfileID else {
            return
        }
        guard !moveSteps.isEmpty else {
            return
        }

        do {
            let draft = GuidedApplyDraft(
                profileID: profileID,
                planID: activeRecommendationPlanID ?? UUID(),
                currentAssignments: currentLayoutAssignments,
                recommendedAssignments: recommendedLayoutAssignments,
                moveSteps: moveSteps,
                appNamesByID: appNamesByID,
                completedStepIDs: completedMoveStepIDs,
                updatedAt: Date()
            )
            try guidedApplyDraftRepository.upsert(draft)
        } catch {
            showStatus("Failed to save guided apply draft: \(error.localizedDescription)", level: .error)
        }
    }

    private func resetRecommendationOutput() {
        currentLayoutAssignments = []
        recommendedLayoutAssignments = []
        moveSteps = []
        simulationSummary = nil
        appNamesByID = [:]
        originalDetectedSlots = []
        completedMoveStepIDs = []
        activeRecommendationPlanID = nil
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

    private func parsedManualUsageMinutes() -> [String: Double] {
        var parsed: [String: Double] = [:]

        for (key, rawValue) in usageDraftByNormalizedName {
            let cleaned = rawValue
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let value = Double(cleaned), value > 0 else {
                continue
            }

            parsed[key] = value
        }

        return parsed
    }

    private func applyImportedUsage(_ entries: [ScreenTimeUsageEntry]) {
        manualUsageEnabled = true
        importedUsageEntries = entries

        for entry in entries {
            let key = canonicalAppName(entry.appName)
            guard !key.isEmpty else {
                continue
            }

            usageDraftByNormalizedName[key] = String(format: "%.0f", entry.minutesPerDay)
        }

        hydrateUsageDraftFromDetectedApps()
    }

    private func hydrateUsageDraftFromDetectedApps() {
        let expectedKeys = Set(usageEditorAppNames.map(canonicalAppName))

        for key in expectedKeys where usageDraftByNormalizedName[key] == nil {
            usageDraftByNormalizedName[key] = ""
        }
    }

    private func canonicalAppName(_ text: String) -> String {
        usageNormalizer.canonicalName(text)
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

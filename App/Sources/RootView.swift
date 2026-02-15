import Core
import Foundation
import Ingestion
import PhotosUI
import Profiles
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
                profileListSection
                importSection
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
                ForEach(model.savedProfiles) { profile in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.headline)
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
    @Published var importSession: ScreenshotImportSession?
    @Published var statusMessage = ""
    @Published var statusLevel: StatusLevel = .info
    @Published var ocrCandidates: [OCRLabelCandidate] = []
    @Published var ocrQuality: ImportQuality = .low

    private let profileBuilder = OnboardingProfileBuilder()
    private let profileRepository: FileProfileRepository
    private let importCoordinator: ScreenshotImportCoordinator
    private let ocrExtractor: any LayoutOCRExtracting
    private let ocrPostProcessor = OCRPostProcessor()

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
    }

    var canSubmitProfile: Bool {
        (utilityWeight + flowWeight + aestheticsWeight + moveCostWeight) > 0.0001
    }

    func loadProfiles() {
        do {
            savedProfiles = try profileRepository.fetchAll()
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

        let profile = profileBuilder.buildProfile(from: answers)

        do {
            try profileRepository.upsert(profile)
            loadProfiles()
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

        do {
            let extracted = try await ocrExtractor.extractAppLabels(from: latestPage.filePath)
            ocrCandidates = extracted
            ocrQuality = ocrPostProcessor.estimateImportQuality(from: extracted)

            if extracted.isEmpty {
                showStatus("No likely app labels detected.", level: .info)
            } else {
                showStatus("Extracted \(extracted.count) app label candidates.", level: .success)
            }
        } catch {
            showStatus("OCR failed: \(error.localizedDescription)", level: .error)
        }
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

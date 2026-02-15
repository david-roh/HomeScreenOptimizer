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
            .alert("Status", isPresented: $model.showingStatus) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.statusMessage)
            }
        }
    }

    private var onboardingSection: some View {
        Section("Onboarding") {
            TextField("Profile name", text: $model.profileName)

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
    @Published var showingStatus = false

    private let profileBuilder = OnboardingProfileBuilder()
    private let profileRepository: FileProfileRepository
    private let importCoordinator: ScreenshotImportCoordinator

    init() {
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

    func loadProfiles() {
        do {
            savedProfiles = try profileRepository.fetchAll()
        } catch {
            showStatus("Failed to load profiles: \(error.localizedDescription)")
        }
    }

    func saveProfile() {
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
            showStatus("Saved profile \"\(profile.name)\".")
        } catch {
            showStatus("Failed to save profile: \(error.localizedDescription)")
        }
    }

    func startOrResetSession() {
        do {
            importSession = try importCoordinator.startSession()
            showStatus("Import session ready.")
        } catch {
            showStatus("Failed to create session: \(error.localizedDescription)")
        }
    }

    func handlePickedItem(_ item: PhotosPickerItem) async {
        guard let session = importSession else {
            showStatus("Start an import session first.")
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                showStatus("Could not read selected image.")
                return
            }

            let fileURL = try writeImageToTemporaryFile(data: data)
            importSession = try importCoordinator.addPage(sessionID: session.id, filePath: fileURL.path)
            showStatus("Screenshot added.")
        } catch {
            showStatus("Failed to add screenshot: \(error.localizedDescription)")
        }
    }

    func removePage(pageID: UUID) {
        guard let session = importSession else {
            return
        }

        do {
            importSession = try importCoordinator.removePage(sessionID: session.id, pageID: pageID)
            showStatus("Removed screenshot.")
        } catch {
            showStatus("Failed to remove screenshot: \(error.localizedDescription)")
        }
    }

    private func writeImageToTemporaryFile(data: Data) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HSOImports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fileURL = folder.appendingPathComponent("\(UUID().uuidString).png")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        showingStatus = true
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

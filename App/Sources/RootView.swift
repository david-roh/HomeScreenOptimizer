import Core
#if canImport(DeviceActivity)
import DeviceActivity
#endif
#if canImport(FamilyControls)
import FamilyControls
#endif
import Foundation
import Guide
import Ingestion
import Optimizer
import PhotosUI
import Privacy
import Profiles
import Simulation
import SwiftUI
import Usage

struct RootView: View {
    @StateObject private var model = RootViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedUsageItem: PhotosPickerItem?
    @State private var selectedTab: Tab = .setup

    private enum Tab: String, CaseIterable {
        case setup
        case importData
        case plan
        case apply

        var title: String {
            switch self {
            case .setup:
                return "Setup"
            case .importData:
                return "Import"
            case .plan:
                return "Plan"
            case .apply:
                return "Apply"
            }
        }

        var icon: String {
            switch self {
            case .setup:
                return "slider.horizontal.3"
            case .importData:
                return "photo.stack"
            case .plan:
                return "chart.bar.doc.horizontal"
            case .apply:
                return "checklist"
            }
        }

        var heroTitle: String {
            switch self {
            case .setup:
                return "Define Your Grip Profile"
            case .importData:
                return "Capture Your Current Layout"
            case .plan:
                return "Generate A Practical Plan"
            case .apply:
                return "Execute Changes With Confidence"
            }
        }

        var heroSubtitle: String {
            switch self {
            case .setup:
                return "Set ergonomics and intent so optimization is personalized, not generic."
            case .importData:
                return "Import screenshots in order, fix OCR, and confirm slots before planning."
            case .plan:
                return "Blend Screen Time signal with your profile to output a high-value arrangement."
            case .apply:
                return "Follow a guided move sequence and track completion as you reorganize."
            }
        }

        var accent: Color {
            switch self {
            case .setup:
                return Color(red: 0.13, green: 0.45, blue: 0.94)
            case .importData:
                return Color(red: 0.14, green: 0.61, blue: 0.54)
            case .plan:
                return Color(red: 0.21, green: 0.49, blue: 0.86)
            case .apply:
                return Color(red: 0.23, green: 0.56, blue: 0.40)
            }
        }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                setupTab
                    .tag(Tab.setup)
                    .tabItem {
                        Label(Tab.setup.title, systemImage: Tab.setup.icon)
                    }

                importTab
                    .tag(Tab.importData)
                    .tabItem {
                        Label(Tab.importData.title, systemImage: Tab.importData.icon)
                    }

                planningTab
                    .tag(Tab.plan)
                    .tabItem {
                        Label(Tab.plan.title, systemImage: Tab.plan.icon)
                    }

                applyTab
                    .tag(Tab.apply)
                    .tabItem {
                        Label(Tab.apply.title, systemImage: Tab.apply.icon)
                    }
            }
            .navigationTitle("HomeScreenOptimizer")
            .toolbarTitleDisplayMode(.inline)
            .fontDesign(.rounded)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: selectedTab)
        }
        .background(screenBackground.ignoresSafeArea())
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

    private var screenBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 1.0),
                Color(red: 0.93, green: 0.96, blue: 0.99),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var setupTab: some View {
        screenScroll {
            workflowHero(for: .setup)
            if !model.statusMessage.isEmpty {
                statusBanner
            }
            onboardingCard
            profilesCard
            calibrationCard
        }
    }

    private var importTab: some View {
        screenScroll {
            workflowHero(for: .importData)
            if !model.statusMessage.isEmpty {
                statusBanner
            }
            importSessionCard
            importedScreensCard
        }
    }

    private var planningTab: some View {
        screenScroll {
            workflowHero(for: .plan)
            if !model.statusMessage.isEmpty {
                statusBanner
            }
            usageAndGenerationCard

            if !model.recommendationHistory.isEmpty || !model.historyComparisonMessage.isEmpty {
                recommendationHistoryCard
            }

            if !model.currentLayoutAssignments.isEmpty || !model.recommendedLayoutAssignments.isEmpty {
                layoutPreviewCard
            }
        }
    }

    private var applyTab: some View {
        screenScroll {
            workflowHero(for: .apply)
            if !model.statusMessage.isEmpty {
                statusBanner
            }
            applyChecklistCard
        }
    }

    private func workflowHero(for tab: Tab) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(tab.title, systemImage: tab.icon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.22), in: Capsule())

                Spacer()

                Text("Step \(tabStepIndex(tab))/\(Tab.allCases.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18), in: Capsule())
            }

            Text(tab.heroTitle)
                .font(.system(.title3, design: .rounded).weight(.bold))

            Text(tab.heroSubtitle)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.88))

            HStack(spacing: 6) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item == tab ? Color.white : Color.white.opacity(0.35))
                        .frame(height: 5)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            LinearGradient(
                colors: [tab.accent, tab.accent.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: tab.accent.opacity(0.28), radius: 14, x: 0, y: 8)
    }

    private var statusBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: model.statusLevel.iconName)
                .foregroundStyle(model.statusLevel.tint)
                .padding(6)
                .background(model.statusLevel.tint.opacity(0.18), in: Circle())

            Text(model.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(model.statusLevel.tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(model.statusLevel.tint.opacity(0.20), lineWidth: 1)
        )
    }

    private var onboardingCard: some View {
        card(title: "Profile Intent", subtitle: "Tell the optimizer how you hold and prioritize") {
            TextField("Profile name", text: $model.profileName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            pickerRow(title: "Context", selection: $model.context) {
                ForEach(ProfileContext.allCases, id: \.self) { context in
                    Text(context.displayTitle).tag(context)
                }
            }

            pickerRow(title: "Handedness", selection: $model.handedness) {
                ForEach(Handedness.allCases, id: \.self) { handedness in
                    Text(handedness.displayTitle).tag(handedness)
                }
            }

            pickerRow(title: "Grip mode", selection: $model.gripMode) {
                ForEach(GripMode.allCases, id: \.self) { gripMode in
                    Text(gripMode.displayTitle).tag(gripMode)
                }
            }

            VStack(spacing: 10) {
                weightSlider(title: "Utility", value: $model.utilityWeight, accent: Tab.setup.accent)
                weightSlider(title: "Flow", value: $model.flowWeight, accent: Tab.setup.accent)
                weightSlider(title: "Aesthetics", value: $model.aestheticsWeight, accent: Tab.setup.accent)
                weightSlider(title: "Move Cost", value: $model.moveCostWeight, accent: Tab.setup.accent)
            }

            Button {
                model.saveProfile()
            } label: {
                Label("Save Profile", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Tab.setup.accent)
            .disabled(!model.canSubmitProfile)
        }
    }

    private var profilesCard: some View {
        card(title: "Profiles", subtitle: "Switch context quickly before planning") {
            if model.savedProfiles.isEmpty {
                Text("No saved profiles yet")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Active profile", selection: $model.selectedProfileID) {
                    ForEach(model.savedProfiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .pickerStyle(.menu)

                ForEach(model.savedProfiles) { profile in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.headline)
                            Text("\(profile.context.displayTitle) • \(profile.handedness.displayTitle) • \(profile.gripMode.displayTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.selectedProfileID == profile.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                model.loadProfiles()
            } label: {
                Label("Refresh Profiles", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var calibrationCard: some View {
        card(title: "Reachability Calibration", subtitle: "Improve thumb weighting using quick taps") {
            if let target = model.calibrationCurrentTarget {
                Text("Current target: R\(target.row + 1) C\(target.column + 1) (\(model.calibrationProgressLabel))")
                    .font(.subheadline)
            } else {
                Text("No active calibration session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(calibrationCoordinates, id: \.id) { coordinate in
                    Button {
                        model.handleCalibrationTap(row: coordinate.row, column: coordinate.column)
                    } label: {
                        Text("\(coordinate.row + 1),\(coordinate.column + 1)")
                            .font(.caption2.weight(.semibold))
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
            .buttonStyle(.bordered)
            .tint(Tab.setup.accent)

            if !model.lastCalibrationMap.slotWeights.isEmpty {
                Text("Calibration saved with \(model.lastCalibrationMap.slotWeights.count) sampled targets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importSessionCard: some View {
        card(title: "Screenshot Intake", subtitle: "Bring in pages and detect app slots") {
            if let session = model.importSession {
                HStack {
                    metricPill(title: "Session", value: String(session.id.uuidString.prefix(8)))
                    metricPill(title: "Pages", value: "\(session.pages.count)")
                    Spacer()
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Add Screenshot", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tab.importData.accent)

                HStack {
                    Button("Analyze Latest") {
                        Task {
                            await model.analyzeLatestScreenshot()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(session.pages.isEmpty)

                    Button("Analyze All") {
                        Task {
                            await model.analyzeAllScreenshots()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(session.pages.isEmpty)
                }

                if !model.detectedSlots.isEmpty {
                    HStack {
                        Text("Detected slots")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        metricPill(title: "OCR", value: model.ocrQuality.displayTitle)
                    }

                    if model.hasSlotConflicts {
                        Label("Some apps share the same slot. Resolve before generating.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Button("Reset OCR Corrections") {
                        model.resetDetectedSlotCorrections()
                    }
                    .buttonStyle(.borderless)

                    ForEach(Array(model.detectedSlots.prefix(10).indices), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("App name", text: model.bindingForDetectedAppName(index: index))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 16) {
                                slotStepper(label: "Page \(model.detectedSlots[index].slot.page + 1)") {
                                    model.adjustDetectedSlot(index: index, pageDelta: -1)
                                } increment: {
                                    model.adjustDetectedSlot(index: index, pageDelta: 1)
                                }

                                slotStepper(label: "Row \(model.detectedSlots[index].slot.row + 1)") {
                                    model.adjustDetectedSlot(index: index, rowDelta: -1)
                                } increment: {
                                    model.adjustDetectedSlot(index: index, rowDelta: 1)
                                }

                                slotStepper(label: "Col \(model.detectedSlots[index].slot.column + 1)") {
                                    model.adjustDetectedSlot(index: index, columnDelta: -1)
                                } increment: {
                                    model.adjustDetectedSlot(index: index, columnDelta: 1)
                                }
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                        )
                    }
                }
            } else {
                Text("No active import session")
                    .foregroundStyle(.secondary)
            }

            Button(model.importSession == nil ? "Start Import Session" : "Reset Session") {
                model.startOrResetSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(Tab.importData.accent)
        }
    }

    private var importedScreensCard: some View {
        card(title: "Imported Pages", subtitle: "Reorder pages to match your home-screen sequence") {
            if let session = model.importSession, !session.pages.isEmpty {
                ForEach(session.pages) { page in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Page \(page.pageIndex + 1)")
                                .font(.subheadline)
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

                        Button(role: .destructive) {
                            model.removePage(pageID: page.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("Add screenshots to begin OCR and slot detection.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var usageAndGenerationCard: some View {
        card(title: "Usage Signals + Recommendation", subtitle: "Connect data and generate an actionable arrangement") {
            if let activeProfileName = model.activeProfileName {
                Label("Active profile: \(activeProfileName)", systemImage: "person.crop.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Save/select a profile first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

#if canImport(DeviceActivity) && canImport(FamilyControls)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Native Screen Time")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    metricPill(title: "Status", value: model.nativeScreenTimeAuthorizationLabel)
                }

                HStack {
                    Button(model.nativeScreenTimeAuthorized ? "Refresh Access" : "Connect Screen Time") {
                        Task {
                            await model.requestNativeScreenTimeAuthorization()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Import Native Usage") {
                        model.importNativeUsageSnapshot()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.nativeScreenTimeAuthorized)
                }

                if let lastSnapshot = model.nativeScreenTimeLastSnapshotAt {
                    Text("Last native snapshot: \(lastSnapshot.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if model.nativeScreenTimeAuthorized {
                    DeviceActivityReport(
                        DeviceActivityReport.Context("HSO Usage Summary"),
                        filter: model.nativeUsageFilter
                    )
                    .frame(minHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
#endif

            Toggle("Use manual usage input", isOn: $model.manualUsageEnabled)
                .tint(Tab.plan.accent)

            if model.manualUsageEnabled {
                PhotosPicker(selection: $selectedUsageItem, matching: .images) {
                    Label("Import Screen Time Screenshot", systemImage: "chart.bar.doc.horizontal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.selectedProfileID == nil)

                if !model.importedUsageEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latest imported usage")
                            .font(.caption)
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
                }

                ForEach(model.usageEditorAppNames, id: \.self) { appName in
                    HStack {
                        Text(appName)
                            .lineLimit(1)
                        Spacer()
                        TextField("min/day", text: model.bindingForUsageMinutes(appName: appName))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                }

                HStack {
                    Button("Load Saved Usage") {
                        model.loadManualUsageSnapshot()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.selectedProfileID == nil)

                    Spacer()

                    Button("Save Usage") {
                        model.saveManualUsageSnapshot()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.selectedProfileID == nil || model.usageEditorAppNames.isEmpty)
                }
            }

            if model.detectedSlots.isEmpty {
                Label("Analyze home-screen screenshots in Import tab first.", systemImage: "arrow.up.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                model.generateRecommendationGuide()
            } label: {
                Label("Generate Rearrangement Guide", systemImage: "sparkles.rectangle.stack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Tab.plan.accent)
            .disabled(model.selectedProfileID == nil || model.detectedSlots.isEmpty)

            if let summary = model.simulationSummary {
                HStack {
                    metricPill(title: "Score", value: String(format: "%+.3f", summary.aggregateScoreDelta))
                    metricPill(title: "Moves", value: "\(summary.moveCount)")
                    Spacer()
                }
            }
        }
    }

    private var recommendationHistoryCard: some View {
        card(title: "Recommendation History", subtitle: "Compare new and previous plans") {
            ForEach(Array(model.recommendationHistory.prefix(8).enumerated()), id: \.offset) { _, plan in
                HStack(alignment: .top) {
                    Text(model.historyLabel(for: plan))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if plan.id == model.activeRecommendationPlanID {
                        Text("Current")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Button("Compare") {
                            model.compareAgainstHistory(planID: plan.id)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            if !model.historyComparisonMessage.isEmpty {
                Text(model.historyComparisonMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var layoutPreviewCard: some View {
        card(title: "Layout Snapshot", subtitle: "Before and after for top assignments") {
            if !model.currentLayoutAssignments.isEmpty {
                Text("Current")
                    .font(.subheadline)
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
                Divider()
                Text("Recommended")
                    .font(.subheadline)
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
        }
    }

    private var applyChecklistCard: some View {
        card(title: "Guided Apply", subtitle: "Follow this sequence to rearrange with less friction") {
            if model.moveSteps.isEmpty {
                Text("Generate a recommendation in Plan tab to create checklist steps.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.subheadline)
                        Spacer()
                        Text(model.moveProgressText)
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(model.allMovesCompleted ? .green : .secondary)
                    }

                    ProgressView(value: applyProgressValue)
                        .tint(Tab.apply.accent)
                }

                HStack {
                    Button("Mark Next Complete") {
                        model.markNextMoveStepComplete()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.allMovesCompleted)

                    Spacer()

                    Button("Reset Progress") {
                        model.resetMoveProgress()
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(Array(model.moveSteps.prefix(24).enumerated()), id: \.offset) { index, step in
                    let isDone = model.completedMoveStepIDs.contains(step.id)
                    let isNext = model.nextPendingMoveStepID == step.id

                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            model.toggleMoveStepCompletion(step.id)
                        } label: {
                            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isDone ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(index + 1). Move \(model.displayName(for: step.appID))")
                                .font(.subheadline)
                                .foregroundStyle(isDone ? .secondary : .primary)
                            Text("\(slotLabel(step.fromSlot)) -> \(slotLabel(step.toSlot))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if isNext {
                                Text("Next recommended step")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isNext ? Color.orange.opacity(0.14) : Color(.tertiarySystemFill))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func screenScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private func card<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.40), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private func pickerRow<Selection: Hashable, Content: View>(
        title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LabeledContent {
            Picker(title, selection: selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
        } label: {
            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    private func slotStepper(
        label: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button {
                    decrement()
                } label: {
                    Image(systemName: "minus.circle")
                }
                Button {
                    increment()
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .buttonStyle(.borderless)
    }

    private func weightSlider(title: String, value: Binding<Double>, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...1)
                .tint(accent)
        }
    }

    private var applyProgressValue: Double {
        guard !model.moveSteps.isEmpty else {
            return 0
        }

        return Double(model.completedMoveCount) / Double(model.moveSteps.count)
    }

    private func tabStepIndex(_ tab: Tab) -> Int {
        switch tab {
        case .setup:
            return 1
        case .importData:
            return 2
        case .plan:
            return 3
        case .apply:
            return 4
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

#Preview {
    RootView()
}

#Preview("Dark") {
    RootView()
        .preferredColorScheme(.dark)
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
    @Published var nativeScreenTimeAuthorized = false
    @Published var nativeScreenTimeAuthorizationLabel = "Not connected"
    @Published var nativeScreenTimeLastSnapshotAt: Date?
    @Published var completedMoveStepIDs: Set<UUID> = []
    @Published var activeRecommendationPlanID: UUID?
    @Published var recommendationHistory: [LayoutPlan] = []
    @Published var historyComparisonMessage = ""

    private let profileBuilder = OnboardingProfileBuilder()
    private let profileRepository: FileProfileRepository
    private let layoutPlanRepository: FileLayoutPlanRepository
    private let usageRepository: FileUsageSnapshotRepository
    private let guidedApplyDraftRepository: FileGuidedApplyDraftRepository
    private let analyticsEventRepository: FileAnalyticsEventRepository
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
        layoutPlanRepository = FileLayoutPlanRepository(fileURL: baseURL.appendingPathComponent("layout_plans.json"))
        usageRepository = FileUsageSnapshotRepository(fileURL: baseURL.appendingPathComponent("usage_snapshots.json"))
        guidedApplyDraftRepository = FileGuidedApplyDraftRepository(fileURL: baseURL.appendingPathComponent("guided_apply_drafts.json"))
        analyticsEventRepository = FileAnalyticsEventRepository(fileURL: baseURL.appendingPathComponent("analytics_events.json"))
        let importRepository = FileScreenshotImportSessionRepository(fileURL: baseURL.appendingPathComponent("import_sessions.json"))
        importCoordinator = ScreenshotImportCoordinator(repository: importRepository)

        restoreLatestImportSession()
        refreshNativeScreenTimeAuthorizationState()
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

#if canImport(DeviceActivity)
    var nativeUsageFilter: DeviceActivityFilter {
        let interval = DateInterval(
            start: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            devices: .all
        )
    }
#endif

    func historyLabel(for plan: LayoutPlan) -> String {
        let when = DateFormatter.localizedString(
            from: plan.generatedAt,
            dateStyle: .short,
            timeStyle: .short
        )
        let score = String(format: "%.3f", plan.scoreBreakdown.aggregateScore)
        return "\(when) • score \(score)"
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
            loadRecommendationHistoryForSelectedProfile()
        } catch {
            showStatus("Failed to load profiles: \(error.localizedDescription)", level: .error)
        }
    }

    func handleProfileSelectionChange() {
        loadUsageSnapshotForSelectedProfile()
        loadGuidedApplyDraftForSelectedProfile()
        loadRecommendationHistoryForSelectedProfile()
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
        let previousPlan = recommendationHistory.first

        currentLayoutAssignments = assignments
        recommendedLayoutAssignments = generated.recommendedPlan.assignments
        moveSteps = planMoves
        simulationSummary = simulation
        appNamesByID = appNames
        activeRecommendationPlanID = generated.recommendedPlan.id
        completedMoveStepIDs = []
        persistGuidedApplyDraft()
        do {
            try layoutPlanRepository.upsert(generated.recommendedPlan)
            loadRecommendationHistoryForSelectedProfile()
        } catch {
            showStatus("Generated guide but failed to save plan history: \(error.localizedDescription)", level: .error)
        }

        if let previousPlan {
            historyComparisonMessage = buildHistoryComparisonMessage(
                currentPlan: generated.recommendedPlan,
                baselinePlan: previousPlan,
                currentAssignments: assignments,
                currentMoveCount: planMoves.count
            )
        } else {
            historyComparisonMessage = ""
        }

        trackAnalyticsEvent(
            .guideGenerated,
            profileID: profile.id,
            planID: generated.recommendedPlan.id,
            payload: [
                "move_count": String(planMoves.count),
                "score_delta": String(format: "%.3f", simulation.aggregateScoreDelta)
            ]
        )
        trackAnalyticsEvent(
            .guidedApplyStarted,
            profileID: profile.id,
            planID: generated.recommendedPlan.id,
            payload: ["total_steps": String(planMoves.count)]
        )

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

    func requestNativeScreenTimeAuthorization() async {
#if canImport(FamilyControls)
        guard #available(iOS 16.0, *) else {
            nativeScreenTimeAuthorized = false
            nativeScreenTimeAuthorizationLabel = "Unsupported iOS"
            showStatus("Native Screen Time API requires iOS 16+.", level: .info)
            return
        }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshNativeScreenTimeAuthorizationState()
            showStatus("Screen Time access authorized.", level: .success)
        } catch {
            refreshNativeScreenTimeAuthorizationState()
            showStatus("Screen Time authorization failed: \(error.localizedDescription)", level: .error)
        }
#else
        nativeScreenTimeAuthorized = false
        nativeScreenTimeAuthorizationLabel = "Not available"
        showStatus("Native Screen Time API is unavailable on this build.", level: .info)
#endif
    }

    func importNativeUsageSnapshot() {
        guard selectedProfileID != nil else {
            showStatus("Select a profile before importing usage.", level: .error)
            return
        }

        guard let defaults = UserDefaults(suiteName: SharedScreenTimeBridge.appGroupID) else {
            showStatus("Could not access shared Screen Time data.", level: .error)
            return
        }
        guard let data = defaults.data(forKey: SharedScreenTimeBridge.entriesDefaultsKey) else {
            nativeScreenTimeLastSnapshotAt = defaults.object(forKey: SharedScreenTimeBridge.updatedAtDefaultsKey) as? Date
            showStatus("No native Screen Time snapshot found yet.", level: .info)
            return
        }

        do {
            let entries = try JSONDecoder().decode([ScreenTimeUsageEntry].self, from: data)
            guard !entries.isEmpty else {
                showStatus("Native Screen Time snapshot is empty.", level: .info)
                return
            }

            applyImportedUsage(entries)
            nativeScreenTimeLastSnapshotAt = defaults.object(forKey: SharedScreenTimeBridge.updatedAtDefaultsKey) as? Date
            showStatus("Imported native Screen Time usage for \(entries.count) apps.", level: .success)
        } catch {
            showStatus("Failed to decode native Screen Time snapshot: \(error.localizedDescription)", level: .error)
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
        let inserted: Bool
        if completedMoveStepIDs.contains(stepID) {
            completedMoveStepIDs.remove(stepID)
            inserted = false
        } else {
            completedMoveStepIDs.insert(stepID)
            inserted = true
        }

        persistGuidedApplyDraft()
        if inserted {
            trackChecklistProgress(stepID: stepID)
        }
    }

    func markNextMoveStepComplete() {
        guard let next = nextPendingMoveStepID else {
            return
        }

        completedMoveStepIDs.insert(next)
        persistGuidedApplyDraft()
        trackChecklistProgress(stepID: next)
    }

    func resetMoveProgress() {
        completedMoveStepIDs = []
        persistGuidedApplyDraft()
        trackAnalyticsEvent(
            .guidedApplyReset,
            payload: ["total_steps": String(moveSteps.count)]
        )
    }

    func compareAgainstHistory(planID: UUID) {
        guard let currentPlanID = activeRecommendationPlanID else {
            showStatus("Generate a recommendation before comparing history.", level: .info)
            return
        }
        guard currentPlanID != planID else {
            historyComparisonMessage = ""
            return
        }
        guard let currentPlan = recommendationHistory.first(where: { $0.id == currentPlanID }),
              let baseline = recommendationHistory.first(where: { $0.id == planID }) else {
            showStatus("Selected history plan is no longer available.", level: .error)
            return
        }

        historyComparisonMessage = buildHistoryComparisonMessage(
            currentPlan: currentPlan,
            baselinePlan: baseline,
            currentAssignments: currentLayoutAssignments,
            currentMoveCount: moveSteps.count
        )
        trackAnalyticsEvent(
            .historyCompared,
            planID: currentPlanID,
            payload: ["baseline_plan_id": baseline.id.uuidString]
        )
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

    private func refreshNativeScreenTimeAuthorizationState() {
#if canImport(FamilyControls)
        if #available(iOS 15.0, *) {
            switch AuthorizationCenter.shared.authorizationStatus {
            case .approved:
                nativeScreenTimeAuthorized = true
                nativeScreenTimeAuthorizationLabel = "Authorized"
            case .denied:
                nativeScreenTimeAuthorized = false
                nativeScreenTimeAuthorizationLabel = "Denied"
            case .notDetermined:
                nativeScreenTimeAuthorized = false
                nativeScreenTimeAuthorizationLabel = "Not connected"
            @unknown default:
                nativeScreenTimeAuthorized = false
                nativeScreenTimeAuthorizationLabel = "Unknown"
            }
        } else {
            nativeScreenTimeAuthorized = false
            nativeScreenTimeAuthorizationLabel = "Unsupported iOS"
        }
#else
        nativeScreenTimeAuthorized = false
        nativeScreenTimeAuthorizationLabel = "Not available"
#endif
        loadNativeScreenTimeSnapshotTimestamp()
    }

    private func loadNativeScreenTimeSnapshotTimestamp() {
        guard let defaults = UserDefaults(suiteName: SharedScreenTimeBridge.appGroupID) else {
            nativeScreenTimeLastSnapshotAt = nil
            return
        }
        nativeScreenTimeLastSnapshotAt = defaults.object(forKey: SharedScreenTimeBridge.updatedAtDefaultsKey) as? Date
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

    private func loadRecommendationHistoryForSelectedProfile() {
        guard let profileID = selectedProfileID else {
            recommendationHistory = []
            historyComparisonMessage = ""
            return
        }

        do {
            recommendationHistory = try layoutPlanRepository
                .fetchAll(for: profileID)
                .sorted { $0.generatedAt > $1.generatedAt }
        } catch {
            recommendationHistory = []
            showStatus("Failed to load recommendation history: \(error.localizedDescription)", level: .error)
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

    private func buildHistoryComparisonMessage(
        currentPlan: LayoutPlan,
        baselinePlan: LayoutPlan,
        currentAssignments: [LayoutAssignment],
        currentMoveCount: Int
    ) -> String {
        let scoreDelta = currentPlan.scoreBreakdown.aggregateScore - baselinePlan.scoreBreakdown.aggregateScore
        let baselineMoveCount = movePlanBuilder.buildMoves(
            current: currentAssignments,
            target: baselinePlan.assignments
        ).count
        let moveDelta = currentMoveCount - baselineMoveCount
        let moveText: String
        if moveDelta == 0 {
            moveText = "same move count"
        } else if moveDelta < 0 {
            moveText = "\(abs(moveDelta)) fewer moves"
        } else {
            moveText = "\(moveDelta) more moves"
        }

        let baselineDate = DateFormatter.localizedString(
            from: baselinePlan.generatedAt,
            dateStyle: .short,
            timeStyle: .short
        )

        return "Vs \(baselineDate): \(String(format: "%+.3f", scoreDelta)) score, \(moveText)."
    }

    private func trackChecklistProgress(stepID: UUID) {
        trackAnalyticsEvent(
            .guidedApplyStepCompleted,
            stepID: stepID,
            payload: [
                "completed_steps": String(completedMoveCount),
                "total_steps": String(moveSteps.count)
            ]
        )

        if allMovesCompleted {
            trackAnalyticsEvent(
                .guidedApplyCompleted,
                payload: ["total_steps": String(moveSteps.count)]
            )
        }
    }

    private func trackAnalyticsEvent(
        _ name: AnalyticsEventName,
        profileID: UUID? = nil,
        planID: UUID? = nil,
        stepID: UUID? = nil,
        payload: [String: String] = [:]
    ) {
        do {
            let event = AnalyticsEvent(
                name: name,
                profileID: profileID ?? selectedProfileID,
                planID: planID ?? activeRecommendationPlanID,
                stepID: stepID,
                payload: payload
            )
            try analyticsEventRepository.append(event)
        } catch {
            showStatus("Analytics log failed: \(error.localizedDescription)", level: .error)
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
        historyComparisonMessage = ""
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

private enum SharedScreenTimeBridge {
    static let appGroupID = "group.com.davidroh.hso"
    static let entriesDefaultsKey = "native_screen_time_usage_entries"
    static let updatedAtDefaultsKey = "native_screen_time_usage_updated_at"
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

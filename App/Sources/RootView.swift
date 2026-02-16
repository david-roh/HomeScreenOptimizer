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
    @State private var selectedPreset: OptimizationPreset = .balanced
    @State private var showTuneSheet = false
    @State private var showManualUsageEditor = false
    @State private var showDetectedAppsEditor = false
    @State private var showPageList = false
    @State private var showLayoutPreview = false
    @State private var showAllMoves = false
    @State private var showQuickStart = false
    @State private var quickStartPage = 0
    @AppStorage("hso_quick_start_seen_v2") private var quickStartSeen = false

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
                return "square.stack.3d.up"
            case .plan:
                return "wand.and.stars"
            case .apply:
                return "checklist.checked"
            }
        }

        var accent: Color {
            switch self {
            case .setup:
                return Color(red: 0.22, green: 0.49, blue: 0.97)
            case .importData:
                return Color(red: 0.10, green: 0.63, blue: 0.54)
            case .plan:
                return Color(red: 0.29, green: 0.45, blue: 0.89)
            case .apply:
                return Color(red: 0.15, green: 0.60, blue: 0.44)
            }
        }

        var backgroundTop: Color {
            switch self {
            case .setup:
                return Color(red: 0.89, green: 0.94, blue: 1.00)
            case .importData:
                return Color(red: 0.89, green: 0.97, blue: 0.95)
            case .plan:
                return Color(red: 0.91, green: 0.94, blue: 1.00)
            case .apply:
                return Color(red: 0.91, green: 0.97, blue: 0.93)
            }
        }

        var headline: String {
            switch self {
            case .setup:
                return "Build your profile"
            case .importData:
                return "Capture layout"
            case .plan:
                return "Generate plan"
            case .apply:
                return "Apply safely"
            }
        }
    }

    private enum OptimizationPreset: String, CaseIterable, Identifiable {
        case balanced
        case reachFirst
        case visualHarmony
        case minimalDisruption

        var id: String { rawValue }

        var title: String {
            switch self {
            case .balanced:
                return "Balanced"
            case .reachFirst:
                return "Reach"
            case .visualHarmony:
                return "Visual"
            case .minimalDisruption:
                return "Stable"
            }
        }

        var shortDescription: String {
            switch self {
            case .balanced:
                return "General"
            case .reachFirst:
                return "Thumb-first"
            case .visualHarmony:
                return "Aesthetics"
            case .minimalDisruption:
                return "Fewer moves"
            }
        }

        var weights: GoalWeights {
            switch self {
            case .balanced:
                return GoalWeights(utility: 0.45, flow: 0.20, aesthetics: 0.20, moveCost: 0.15)
            case .reachFirst:
                return GoalWeights(utility: 0.58, flow: 0.18, aesthetics: 0.09, moveCost: 0.15)
            case .visualHarmony:
                return GoalWeights(utility: 0.24, flow: 0.20, aesthetics: 0.46, moveCost: 0.10)
            case .minimalDisruption:
                return GoalWeights(utility: 0.28, flow: 0.14, aesthetics: 0.08, moveCost: 0.50)
            }
        }

        static func nearest(to weights: GoalWeights) -> OptimizationPreset {
            let candidates = OptimizationPreset.allCases
            return candidates.min { lhs, rhs in
                lhs.distance(to: weights) < rhs.distance(to: weights)
            } ?? .balanced
        }

        private func distance(to other: GoalWeights) -> Double {
            let w = weights
            let utility = (w.utility - other.utility) * (w.utility - other.utility)
            let flow = (w.flow - other.flow) * (w.flow - other.flow)
            let aesthetics = (w.aesthetics - other.aesthetics) * (w.aesthetics - other.aesthetics)
            let moveCost = (w.moveCost - other.moveCost) * (w.moveCost - other.moveCost)
            return utility + flow + aesthetics + moveCost
        }
    }

    private struct TutorialCard: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private var tutorialCards: [TutorialCard] {
        [
            TutorialCard(icon: "figure.wave", title: "Set up once", body: "Pick hand/grip and choose a style preset."),
            TutorialCard(icon: "photo.stack", title: "Import quickly", body: "Add screenshots, then auto-analyze."),
            TutorialCard(icon: "checkmark.circle", title: "Follow steps", body: "Generate and apply one move at a time.")
        ]
    }

    var body: some View {
        NavigationStack {
            TabView(selection: guidedTabSelection) {
                stageScaffold(for: .setup) {
                    setupCard
                }
                .tag(Tab.setup)
                .tabItem {
                    Label(Tab.setup.title, systemImage: tabBarIcon(for: .setup))
                }

                stageScaffold(for: .importData) {
                    importCard
                }
                .tag(Tab.importData)
                .tabItem {
                    Label(Tab.importData.title, systemImage: tabBarIcon(for: .importData))
                }

                stageScaffold(for: .plan) {
                    planCard
                }
                .tag(Tab.plan)
                .tabItem {
                    Label(Tab.plan.title, systemImage: tabBarIcon(for: .plan))
                }

                stageScaffold(for: .apply) {
                    applyCard
                }
                .tag(Tab.apply)
                .tabItem {
                    Label(Tab.apply.title, systemImage: tabBarIcon(for: .apply))
                }
            }
            .navigationTitle("HomeScreenOptimizer")
            .toolbarTitleDisplayMode(.inline)
            .fontDesign(.rounded)
            .animation(.easeInOut(duration: 0.22), value: selectedTab)
        }
        .background(stageBackground(for: selectedTab).ignoresSafeArea())
        .sheet(isPresented: $showTuneSheet) {
            tuneSheet
        }
        .sheet(isPresented: $showQuickStart) {
            quickStartSheet
        }
        .sheet(isPresented: $showManualUsageEditor) {
            manualUsageSheet
        }
        .onAppear {
            model.loadProfiles()
            syncPresetFromModelWeights()
            if !quickStartSeen && !isUITesting {
                showQuickStart = true
            }
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

    private var guidedTabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                guard !bypassGuidedTabValidation else {
                    selectedTab = newValue
                    return
                }

                guard let reason = blockedReason(for: newValue) else {
                    selectedTab = newValue
                    return
                }

                model.presentStatus(reason, level: .info)
                selectedTab = firstIncompleteTab()
            }
        )
    }

    private func stageBackground(for tab: Tab) -> some View {
        LinearGradient(
            colors: [
                tab.backgroundTop,
                Color(.systemBackground),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func stageScaffold<Content: View>(for tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                stageHeader(for: tab)

                if !model.statusMessage.isEmpty {
                    statusBanner
                }

                content()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                Color.clear
                    .frame(height: 92)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            reachableActionRail(for: tab)
        }
    }

    private func stageHeader(for tab: Tab) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Step \(tabStepIndex(tab))/4", systemImage: tab.icon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())

                Spacer()

                Text("\(Int((stageCompletion(for: tab) * 100).rounded()))%")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
            }

            Text(tab.headline)
                .font(.system(.title3, design: .rounded).weight(.bold))

            ProgressView(value: stageCompletion(for: tab))
                .tint(.white)

            if let blocker = stageShortHint(for: tab) {
                Text(blocker)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(15)
        .background {
            ZStack {
                LinearGradient(
                    colors: [tab.accent, tab.accent.opacity(0.70)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 120, height: 120)
                    .offset(x: 120, y: -60)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .rotationEffect(.degrees(-12))
                    .offset(x: -100, y: 26)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: tab.accent.opacity(0.25), radius: 12, x: 0, y: 7)
    }

    private func reachableActionRail(for tab: Tab) -> some View {
        VStack(spacing: 8) {
            if let hint = stageShortHint(for: tab), isPrimaryActionDisabled(for: tab) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button {
                advanceFrom(stage: tab)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.icon)
                    Text(primaryActionLabel(for: tab))
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(tab.accent)
            .disabled(isPrimaryActionDisabled(for: tab))
            .accessibilityIdentifier("bottom-primary-action")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: model.statusLevel.iconName)
                .foregroundStyle(model.statusLevel.tint)
            Text(model.statusMessage)
                .font(.subheadline)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(model.statusLevel.tint.opacity(0.10))
        )
    }

    private var setupCard: some View {
        card(title: "Profile") {
            if !model.savedProfiles.isEmpty {
                HStack {
                    Picker("Profile", selection: $model.selectedProfileID) {
                        ForEach(model.savedProfiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Load") {
                        model.loadSelectedProfileIntoEditor()
                        syncPresetFromModelWeights()
                    }
                    .buttonStyle(.bordered)
                }
            }

            TextField("Profile name", text: $model.profileName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            pickerRow(title: "Context", icon: "calendar", selection: $model.context) {
                ForEach(ProfileContext.allCases, id: \.self) { value in
                    Text(value.displayTitle).tag(value)
                }
            }

            pickerRow(title: "Hand", icon: "hand.point.up.left", selection: $model.handedness) {
                ForEach(Handedness.allCases, id: \.self) { value in
                    Text(value.displayTitle).tag(value)
                }
            }

            pickerRow(title: "Grip", icon: "iphone", selection: $model.gripMode) {
                ForEach(GripMode.allCases, id: \.self) { value in
                    Text(value.displayTitle).tag(value)
                }
            }

            pickerRow(title: "Style", icon: "wand.and.stars", selection: $selectedPreset) {
                ForEach(OptimizationPreset.allCases) { preset in
                    Text("\(preset.title) · \(preset.shortDescription)").tag(preset)
                }
            }
            .onChange(of: selectedPreset) { _, preset in
                applyPreset(preset)
            }

            HStack {
                Button("Fine Tune") {
                    showTuneSheet = true
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(hasSavedProfile ? "Save & Continue" : "Create & Continue") {
                    saveProfileAndContinue()
                }
                .buttonStyle(.borderedProminent)
                .tint(Tab.setup.accent)
                .disabled(!model.canSubmitProfile)
            }
        }
    }

    private var importCard: some View {
        card(title: "Screens") {
            if model.importSession == nil {
                Button("Start Import Session") {
                    model.startOrResetSession()
                }
                .buttonStyle(.borderedProminent)
                .tint(Tab.importData.accent)
            }

            if let session = model.importSession {
                HStack(spacing: 8) {
                    metricPill(title: "Pages", value: "\(session.pages.count)")
                    metricPill(title: "Apps", value: "\(model.detectedSlots.count)")
                    Spacer()
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Add Screenshot", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tab.importData.accent)

                HStack {
                    Button("Analyze All") {
                        Task {
                            await model.analyzeAllScreenshots()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(session.pages.isEmpty)

                    Button("Reset") {
                        model.startOrResetSession()
                    }
                    .buttonStyle(.bordered)
                }

                if model.hasSlotConflicts {
                    Label("Fix duplicate slots before Plan.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                DisclosureGroup("Edit detected apps (\(model.detectedSlots.count))", isExpanded: $showDetectedAppsEditor) {
                    VStack(spacing: 10) {
                        ForEach(Array(model.detectedSlots.prefix(8).indices), id: \.self) { index in
                            VStack(spacing: 8) {
                                TextField("App name", text: model.bindingForDetectedAppName(index: index))
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)

                                HStack(spacing: 12) {
                                    slotStepper(label: "P\(model.detectedSlots[index].slot.page + 1)") {
                                        model.adjustDetectedSlot(index: index, pageDelta: -1)
                                    } increment: {
                                        model.adjustDetectedSlot(index: index, pageDelta: 1)
                                    }

                                    slotStepper(label: "R\(model.detectedSlots[index].slot.row + 1)") {
                                        model.adjustDetectedSlot(index: index, rowDelta: -1)
                                    } increment: {
                                        model.adjustDetectedSlot(index: index, rowDelta: 1)
                                    }

                                    slotStepper(label: "C\(model.detectedSlots[index].slot.column + 1)") {
                                        model.adjustDetectedSlot(index: index, columnDelta: -1)
                                    } increment: {
                                        model.adjustDetectedSlot(index: index, columnDelta: 1)
                                    }
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                        }
                    }
                    .padding(.top, 8)
                }

                DisclosureGroup("Page order", isExpanded: $showPageList) {
                    VStack(spacing: 8) {
                        ForEach(session.pages) { page in
                            HStack {
                                Text("Page \(page.pageIndex + 1)")
                                    .font(.subheadline)
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
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var planCard: some View {
        card(title: "Plan") {
            HStack(spacing: 8) {
                metricPill(title: "Profile", value: model.activeProfileName ?? "None")
                metricPill(title: "Detected", value: "\(model.detectedSlots.count)")
                Spacer()
            }

            Toggle(isOn: $model.manualUsageEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use manual usage input")
                        .font(.subheadline.weight(.semibold))
                    Text(model.manualUsageEnabled ? "Screenshot + quick edit mode" : "Use native Screen Time access")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Tab.plan.accent)
            .accessibilityIdentifier("manual-usage-toggle")

            if model.manualUsageEnabled {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedUsageItem, matching: .images) {
                        Label("Import Screenshot", systemImage: "chart.bar.doc.horizontal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.selectedProfileID == nil)

                    Button("Edit Minutes") {
                        showManualUsageEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tab.plan.accent)
                    .disabled(model.selectedProfileID == nil)
                }

                if !model.importedUsageEntries.isEmpty {
                    Text("Imported \(model.importedUsageEntries.count) app entries.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
#if canImport(DeviceActivity) && canImport(FamilyControls)
                HStack(spacing: 10) {
                    Button(model.nativeScreenTimeAuthorized ? "Refresh Access" : "Connect Screen Time") {
                        Task {
                            await model.requestNativeScreenTimeAuthorization()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Import Usage") {
                        model.importNativeUsageSnapshot()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tab.plan.accent)
                    .disabled(!model.nativeScreenTimeAuthorized)
                }
#else
                Text("Screen Time API unavailable in this build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
#endif
            }

            if canGeneratePlan {
                Text("Ready to generate a guided rearrangement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let hint = stageShortHint(for: .plan) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

            Button {
                model.generateRecommendationGuide()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate Rearrangement")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Tab.plan.accent)
            .disabled(!canGeneratePlan)

            if let summary = model.simulationSummary {
                HStack(spacing: 8) {
                    metricPill(title: "Score", value: String(format: "%+.3f", summary.aggregateScoreDelta))
                    metricPill(title: "Moves", value: "\(summary.moveCount)")
                    Spacer()
                }
            }

            DisclosureGroup("Inspect output", isExpanded: $showLayoutPreview) {
                VStack(spacing: 10) {
                    ForEach(Array(model.recommendedLayoutAssignments.prefix(8).enumerated()), id: \.offset) { _, assignment in
                        HStack {
                            Text(model.displayName(for: assignment.appID))
                            Spacer()
                            Text(slotLabel(assignment.slot))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !model.recommendationHistory.isEmpty {
                        Divider()
                        ForEach(Array(model.recommendationHistory.prefix(4).enumerated()), id: \.offset) { _, plan in
                            HStack {
                                Text(model.historyLabel(for: plan))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                if plan.id != model.activeRecommendationPlanID {
                                    Button("Compare") {
                                        model.compareAgainstHistory(planID: plan.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var manualUsageSheet: some View {
        NavigationStack {
            List {
                Section("Per-app minutes") {
                    ForEach(model.usageEditorAppNames, id: \.self) { appName in
                        HStack {
                            Text(appName)
                                .lineLimit(1)
                            Spacer()
                            TextField("min", text: model.bindingForUsageMinutes(appName: appName))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 84)
                        }
                    }
                }

                Section {
                    HStack {
                        Button("Load") {
                            model.loadManualUsageSnapshot()
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.selectedProfileID == nil)

                        Spacer()

                        Button("Save") {
                            model.saveManualUsageSnapshot()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Tab.plan.accent)
                        .disabled(model.selectedProfileID == nil || model.usageEditorAppNames.isEmpty)
                    }
                }
            }
            .navigationTitle("Manual Usage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showManualUsageEditor = false
                    }
                }
            }
        }
    }

    private var applyCard: some View {
        card(title: "Checklist") {
            if model.moveSteps.isEmpty {
                EmptyStateRow(icon: "checklist.unchecked", text: "Generate a plan first.")
            } else {
                HStack {
                    Text(model.moveProgressText)
                        .font(.headline.monospacedDigit())
                    Spacer()
                    ProgressView(value: applyProgressValue)
                        .frame(maxWidth: 170)
                        .tint(Tab.apply.accent)
                }

                HStack {
                    Button("Mark Next") {
                        model.markNextMoveStepComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tab.apply.accent)
                    .disabled(model.allMovesCompleted)

                    Button("Reset") {
                        model.resetMoveProgress()
                    }
                    .buttonStyle(.bordered)
                }

                if let nextID = model.nextPendingMoveStepID,
                   let nextIndex = model.moveSteps.firstIndex(where: { $0.id == nextID }) {
                    let step = model.moveSteps[nextIndex]
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(nextIndex + 1). \(model.displayName(for: step.appID))")
                            .font(.subheadline.weight(.semibold))
                        Text("\(slotLabel(step.fromSlot)) -> \(slotLabel(step.toSlot))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )
                }

                DisclosureGroup("All steps", isExpanded: $showAllMoves) {
                    VStack(spacing: 8) {
                        ForEach(Array(model.moveSteps.prefix(24).enumerated()), id: \.offset) { index, step in
                            let isDone = model.completedMoveStepIDs.contains(step.id)
                            HStack {
                                Button {
                                    model.toggleMoveStepCompletion(step.id)
                                } label: {
                                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isDone ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                Text("\(index + 1). \(model.displayName(for: step.appID))")
                                    .lineLimit(1)
                                Spacer()
                                Text(slotLabel(step.toSlot))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var tuneSheet: some View {
        NavigationStack {
            Form {
                Section("Weights") {
                    weightRow(title: "Utility", value: utilityWeightBinding, accent: Tab.setup.accent)
                    weightRow(title: "Flow", value: flowWeightBinding, accent: Tab.setup.accent)
                    weightRow(title: "Aesthetics", value: aestheticsWeightBinding, accent: Tab.setup.accent)
                    weightRow(title: "Move Cost", value: moveCostWeightBinding, accent: Tab.setup.accent)
                }

                Section("Calibration") {
                    if let target = model.calibrationCurrentTarget {
                        Text("Target R\(target.row + 1) C\(target.column + 1)")
                    } else {
                        Text("No session")
                            .foregroundStyle(.secondary)
                    }

                    Button(model.calibrationInProgress ? "Restart Calibration" : "Start Calibration") {
                        model.startCalibration()
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(calibrationCoordinates, id: \.id) { coordinate in
                            Button("\(coordinate.row + 1),\(coordinate.column + 1)") {
                                model.handleCalibrationTap(row: coordinate.row, column: coordinate.column)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(model.calibrationButtonTint(row: coordinate.row, column: coordinate.column))
                            .disabled(!model.calibrationInProgress)
                        }
                    }
                }
            }
            .navigationTitle("Fine Tune")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showTuneSheet = false
                        syncPresetFromModelWeights()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var quickStartSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TabView(selection: $quickStartPage) {
                    ForEach(Array(tutorialCards.enumerated()), id: \.offset) { index, card in
                        VStack(spacing: 14) {
                            Image(systemName: card.icon)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(Tab.setup.accent)
                                .padding(16)
                                .background(Tab.setup.accent.opacity(0.15), in: Circle())

                            Text(card.title)
                                .font(.title3.weight(.bold))
                            Text(card.body)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                        }
                        .tag(index)
                        .padding(.top, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<tutorialCards.count, id: \.self) { index in
                        Capsule()
                            .fill(index == quickStartPage ? Tab.setup.accent : Tab.setup.accent.opacity(0.25))
                            .frame(width: index == quickStartPage ? 20 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: quickStartPage)
                    }
                }

                Button(quickStartPage == tutorialCards.count - 1 ? "Start" : "Next") {
                    if quickStartPage < tutorialCards.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            quickStartPage += 1
                        }
                    } else {
                        quickStartSeen = true
                        showQuickStart = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Tab.setup.accent)

                Button("Skip") {
                    quickStartSeen = true
                    showQuickStart = false
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .navigationTitle("Quick Start")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if quickStartSeen {
                        EmptyView()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.78),
                    selectedTab.accent.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selectedTab.accent.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: selectedTab.accent.opacity(0.14), radius: 10, x: 0, y: 5)
    }

    private func pickerRow<Selection: Hashable, Content: View>(
        title: String,
        icon: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(title, selection: selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private func weightRow(title: String, value: Binding<Double>, accent: Color) -> some View {
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

    private func slotStepper(
        label: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
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

    private func applyPreset(_ preset: OptimizationPreset) {
        selectedPreset = preset
        let weights = preset.weights
        model.utilityWeight = weights.utility
        model.flowWeight = weights.flow
        model.aestheticsWeight = weights.aesthetics
        model.moveCostWeight = weights.moveCost
    }

    private func syncPresetFromModelWeights() {
        selectedPreset = OptimizationPreset.nearest(to: currentGoalWeights)
    }

    private var currentGoalWeights: GoalWeights {
        GoalWeights(
            utility: model.utilityWeight,
            flow: model.flowWeight,
            aesthetics: model.aestheticsWeight,
            moveCost: model.moveCostWeight
        )
    }

    private var utilityWeightBinding: Binding<Double> {
        Binding(
            get: { model.utilityWeight },
            set: { model.utilityWeight = $0 }
        )
    }

    private var flowWeightBinding: Binding<Double> {
        Binding(
            get: { model.flowWeight },
            set: { model.flowWeight = $0 }
        )
    }

    private var aestheticsWeightBinding: Binding<Double> {
        Binding(
            get: { model.aestheticsWeight },
            set: { model.aestheticsWeight = $0 }
        )
    }

    private var moveCostWeightBinding: Binding<Double> {
        Binding(
            get: { model.moveCostWeight },
            set: { model.moveCostWeight = $0 }
        )
    }

    private func saveProfileAndContinue() {
        model.saveProfile()
        if canOpenImport {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .importData
            }
            model.presentStatus("Profile saved.", level: .success)
        }
    }

    private func advanceFrom(stage: Tab) {
        switch stage {
        case .setup:
            if canOpenImport {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .importData
                }
            } else {
                saveProfileAndContinue()
            }

        case .importData:
            guard canOpenImport else {
                if let reason = blockedReason(for: .importData) {
                    model.presentStatus(reason, level: .info)
                }
                return
            }

            if model.importSession == nil {
                model.startOrResetSession()
                return
            }

            if canOpenPlan {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .plan
                }
                return
            }

            guard let pageCount = model.importSession?.pages.count, pageCount > 0 else {
                model.presentStatus("Add at least one screenshot.", level: .info)
                return
            }

            Task {
                await model.analyzeAllScreenshots()
            }

        case .plan:
            guard canOpenPlan else {
                if let reason = blockedReason(for: .plan) {
                    model.presentStatus(reason, level: .info)
                }
                return
            }

            if model.moveSteps.isEmpty {
                model.generateRecommendationGuide()
            }

            if canOpenApply {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .apply
                }
            }

        case .apply:
            guard canOpenApply else {
                if let reason = blockedReason(for: .apply) {
                    model.presentStatus(reason, level: .info)
                }
                return
            }

            if !model.allMovesCompleted {
                model.markNextMoveStepComplete()
            }
        }
    }

    private func primaryActionLabel(for tab: Tab) -> String {
        switch tab {
        case .setup:
            return canOpenImport ? "Continue" : "Save profile"
        case .importData:
            if model.importSession == nil {
                return "Start session"
            }
            if canOpenPlan {
                return "Continue"
            }
            if model.importSession?.pages.isEmpty ?? true {
                return "Add screenshots"
            }
            return "Analyze"
        case .plan:
            return canOpenApply ? "Continue" : "Generate"
        case .apply:
            return model.allMovesCompleted ? "Done" : "Mark next"
        }
    }

    private func isPrimaryActionDisabled(for tab: Tab) -> Bool {
        switch tab {
        case .setup:
            return !(canOpenImport || model.canSubmitProfile)
        case .importData:
            guard canOpenImport else { return true }
            if model.importSession == nil { return false }
            if canOpenPlan { return false }
            return model.importSession?.pages.isEmpty ?? true
        case .plan:
            guard canOpenPlan else { return true }
            if canOpenApply { return false }
            return !canGeneratePlan
        case .apply:
            return !canOpenApply || model.allMovesCompleted
        }
    }

    private func stageShortHint(for tab: Tab) -> String? {
        switch tab {
        case .setup:
            return hasSavedProfile ? nil : "Create one profile to unlock the flow."
        case .importData:
            guard !canOpenPlan else { return nil }
            if model.importSession == nil {
                return "Start session."
            }
            if model.detectedSlots.isEmpty {
                return "Analyze after import."
            }
            if model.hasSlotConflicts {
                return "Resolve slot conflicts."
            }
            return nil
        case .plan:
            if !canGeneratePlan {
                return "Finish Setup + Import first."
            }
            return model.moveSteps.isEmpty ? "Generate your first plan." : nil
        case .apply:
            return canOpenApply ? nil : "Generate a plan first."
        }
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitesting-unlock-tabs")
    }

    private var bypassGuidedTabValidation: Bool {
        isUITesting
    }

    private var hasSavedProfile: Bool {
        model.selectedProfileID != nil || !model.savedProfiles.isEmpty
    }

    private var canOpenImport: Bool {
        hasSavedProfile
    }

    private var canOpenPlan: Bool {
        canOpenImport && model.importSession != nil && !model.detectedSlots.isEmpty && !model.hasSlotConflicts
    }

    private var canGeneratePlan: Bool {
        canOpenPlan && model.selectedProfileID != nil
    }

    private var canOpenApply: Bool {
        !model.moveSteps.isEmpty
    }

    private func canAccess(_ tab: Tab) -> Bool {
        if bypassGuidedTabValidation {
            return true
        }

        switch tab {
        case .setup:
            return true
        case .importData:
            return canOpenImport
        case .plan:
            return canOpenPlan
        case .apply:
            return canOpenApply
        }
    }

    private func blockedReason(for tab: Tab) -> String? {
        switch tab {
        case .setup:
            return nil
        case .importData:
            return canOpenImport ? nil : "Complete Setup first."
        case .plan:
            if !canOpenImport {
                return "Complete Setup first."
            }
            if model.importSession == nil {
                return "Start Import first."
            }
            if model.detectedSlots.isEmpty {
                return "Analyze screenshots first."
            }
            if model.hasSlotConflicts {
                return "Resolve slot conflicts first."
            }
            return nil
        case .apply:
            return canOpenApply ? nil : "Generate a plan first."
        }
    }

    private func firstIncompleteTab() -> Tab {
        if !canOpenImport {
            return .setup
        }
        if !canOpenPlan {
            return .importData
        }
        if !canOpenApply {
            return .plan
        }
        return .apply
    }

    private func tabBarIcon(for tab: Tab) -> String {
        canAccess(tab) ? tab.icon : "lock.fill"
    }

    private var applyProgressValue: Double {
        guard !model.moveSteps.isEmpty else {
            return 0
        }

        return Double(model.completedMoveCount) / Double(model.moveSteps.count)
    }

    private func stageCompletion(for tab: Tab) -> Double {
        switch tab {
        case .setup:
            return hasSavedProfile ? 1.0 : 0.2
        case .importData:
            var score = 0.0
            if model.importSession != nil {
                score += 0.25
            }
            if let pageCount = model.importSession?.pages.count, pageCount > 0 {
                score += 0.25
            }
            if !model.detectedSlots.isEmpty {
                score += 0.35
            }
            if !model.hasSlotConflicts && !model.detectedSlots.isEmpty {
                score += 0.15
            }
            return min(score, 1)
        case .plan:
            return model.moveSteps.isEmpty ? (canGeneratePlan ? 0.5 : 0.1) : 1
        case .apply:
            guard !model.moveSteps.isEmpty else {
                return 0
            }
            return applyProgressValue
        }
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

private struct EmptyStateRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
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
    private let appNameMatcher = AppNameMatcher()
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

    func presentStatus(_ message: String, level: StatusLevel = .info) {
        showStatus(message, level: level)
    }

    func loadSelectedProfileIntoEditor() {
        guard let profile = activeProfile() else {
            showStatus("Select a profile first.", level: .info)
            return
        }

        profileName = profile.name
        context = profile.context
        handedness = profile.handedness
        gripMode = profile.gripMode
        utilityWeight = profile.goalWeights.utility
        flowWeight = profile.goalWeights.flow
        aestheticsWeight = profile.goalWeights.aesthetics
        moveCostWeight = profile.goalWeights.moveCost
        lastCalibrationMap = profile.reachabilityMap

        showStatus("Loaded \"\(profile.name)\" into editor.", level: .success)
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
        let resolvedUsageByDetected = resolvedUsageByDetectedName(
            manualUsageByName: manualUsageByName,
            detectedSlots: sortedDetectedSlots
        )

        for detected in sortedDetectedSlots {
            let canonicalName = canonicalAppName(detected.appName)
            let usageScore = resolvedUsageByDetected[canonicalName] ?? max(0.05, detected.confidence)
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
                .map { detected in
                    var normalized = detected
                    normalized.appName = normalizeDetectedAppName(detected.appName)
                    return normalized
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
        let expectedNames = usageEditorAppNames
        var bestByKey: [String: ScreenTimeUsageEntry] = [:]

        for entry in entries {
            let mappedName = appNameMatcher.bestMatch(
                for: entry.appName,
                against: expectedNames,
                minimumScore: 0.72
            ) ?? entry.appName
            let key = canonicalAppName(mappedName)
            guard !key.isEmpty else {
                continue
            }

            usageDraftByNormalizedName[key] = String(format: "%.0f", entry.minutesPerDay)

            let mappedEntry = ScreenTimeUsageEntry(
                appName: mappedName,
                minutesPerDay: entry.minutesPerDay,
                confidence: entry.confidence
            )
            if let existing = bestByKey[key], existing.confidence >= mappedEntry.confidence {
                continue
            }
            bestByKey[key] = mappedEntry
        }

        importedUsageEntries = bestByKey.values.sorted { lhs, rhs in
            if lhs.minutesPerDay != rhs.minutesPerDay {
                return lhs.minutesPerDay > rhs.minutesPerDay
            }
            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
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

    private func normalizeDetectedAppName(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return text
        }

        return appNameMatcher.canonicalizeToKnownApp(trimmed, minimumScore: 0.88)
    }

    private func resolvedUsageByDetectedName(
        manualUsageByName: [String: Double],
        detectedSlots: [DetectedAppSlot]
    ) -> [String: Double] {
        guard !manualUsageByName.isEmpty else {
            return [:]
        }

        let usageKeys = Array(manualUsageByName.keys)
        var resolved: [String: Double] = [:]

        for detected in detectedSlots {
            let detectedCanonical = canonicalAppName(detected.appName)

            if let exact = manualUsageByName[detectedCanonical] {
                resolved[detectedCanonical] = exact
                continue
            }

            if let best = appNameMatcher.bestMatch(
                for: detectedCanonical,
                against: usageKeys,
                minimumScore: 0.72
            ),
               let value = manualUsageByName[best] {
                resolved[detectedCanonical] = value
            }
        }

        return resolved
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

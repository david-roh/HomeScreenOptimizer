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
import UIKit
import Usage
#if canImport(Vision)
import Vision
#endif

enum VisualPatternMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case colorBands
    case rainbowPath
    case mirrorBalance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colorBands:
            return "Color Bands"
        case .rainbowPath:
            return "Rainbow Path"
        case .mirrorBalance:
            return "Mirror Balance"
        }
    }

    var detail: String {
        switch self {
        case .colorBands:
            return "Groups similar icon colors into clean horizontal bands."
        case .rainbowPath:
            return "Orders icons by hue in a serpentine path."
        case .mirrorBalance:
            return "Places similar colors symmetrically for visual balance."
        }
    }
}

struct RootView: View {
    @StateObject private var model = RootViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedUsageItem: PhotosPickerItem?
    @State private var selectedTab: Tab = .setup
    @State private var selectedPreset: OptimizationPreset = .balanced
    @State private var selectedVisualPattern: VisualPatternMode = .colorBands
    @State private var ignoreContextBaselineOnce = false
    @State private var showTuneSheet = false
    @State private var showManualUsageEditor = false
    @State private var showMappingEditor = false
    @State private var showSetupAdvanced = false
    @State private var showStyleDetailSheet = false
    @State private var showFinalLayoutPreview = false
    @State private var showPageList = false
    @State private var showLayoutPreview = false
    @State private var showAllMoves = false
    @State private var showQuickStart = false
    @State private var quickStartPage = 0
    @State private var fineTuneMode: FineTuneMode = .weights
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

    private enum FineTuneMode: String, CaseIterable, Identifiable {
        case weights
        case calibration

        var id: String { rawValue }
        var title: String {
            switch self {
            case .weights:
                return "Weights"
            case .calibration:
                return "Calibration"
            }
        }
    }

    private typealias OptimizationPreset = OptimizationIntent

    private struct TutorialCard: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private var tutorialCards: [TutorialCard] {
        [
            TutorialCard(icon: "figure.wave", title: "Set up once", body: "Pick hand/grip and choose intent."),
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
        .sheet(isPresented: $showMappingEditor) {
            mappingEditorSheet
        }
        .sheet(isPresented: $showStyleDetailSheet) {
            styleDetailSheet
        }
        .sheet(isPresented: $showFinalLayoutPreview) {
            HomeScreenLayoutPreviewView(model: model)
        }
        .onAppear {
            model.loadProfiles()
            if model.savedProfiles.isEmpty {
                model.applyContextBaseline(for: model.context)
            }
            syncPresetFromModelWeights()
            model.visualPatternMode = selectedVisualPattern
            model.visualModeEnabled = selectedPreset == .visualHarmony
            if !quickStartSeen && !isUITesting {
                showQuickStart = true
            }
        }
        .onChange(of: selectedPreset) { _, preset in
            model.visualModeEnabled = preset == .visualHarmony
            if preset != .visualHarmony {
                selectedVisualPattern = .colorBands
                model.visualPatternMode = .colorBands
            }
        }
        .onChange(of: selectedVisualPattern) { _, pattern in
            model.visualPatternMode = pattern
        }
        .onChange(of: model.context) { _, newContext in
            if ignoreContextBaselineOnce {
                ignoreContextBaselineOnce = false
                return
            }

            model.applyContextBaseline(for: newContext)
            syncPresetFromModelWeights()
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

                if !model.statusMessage.isEmpty, !(tab == .setup && model.statusLevel == .info) {
                    statusBanner
                }

                content()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                Color.clear
                    .frame(height: 76)
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
                HStack(spacing: 10) {
                    Menu {
                        ForEach(model.savedProfiles) { profile in
                            Button {
                                model.selectedProfileID = profile.id
                            } label: {
                                Text(profile.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                            Text(model.activeProfileName ?? "Select profile")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button("Load") {
                        ignoreContextBaselineOnce = true
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

            HStack(spacing: 8) {
                compactSetupPicker(title: "Context", icon: "calendar", selection: $model.context) {
                    ForEach(ProfileContext.allCases, id: \.self) { value in
                        Text(value.displayTitle).tag(value)
                    }
                }

                compactSetupPicker(title: "Hand", icon: "hand.point.up.left", selection: $model.handedness) {
                    ForEach(Handedness.allCases, id: \.self) { value in
                        Text(value.displayTitle).tag(value)
                    }
                }

                compactSetupPicker(title: "Grip", icon: "iphone", selection: $model.gripMode) {
                    ForEach(GripMode.allCases, id: \.self) { value in
                        Text(value.displayTitle).tag(value)
                    }
                }
            }

            if model.context == .custom {
                TextField("Custom context label", text: $model.customContextLabel)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Intent")
                    .font(.subheadline.weight(.semibold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                    ForEach(OptimizationPreset.allCases) { preset in
                            Button {
                                applyPreset(preset)
                            } label: {
                                Label(preset.title, systemImage: preset.iconName)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selectedPreset == preset ? Tab.setup.accent.opacity(0.18) : Color(.tertiarySystemFill))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selectedPreset == preset ? Tab.setup.accent : .clear, lineWidth: 1.2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

            }

            DisclosureGroup("More options", isExpanded: $showSetupAdvanced) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(contextBehaviorHint(for: model.context))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if selectedPreset == .visualHarmony {
                        pickerRow(title: "Visual Pattern", icon: "paintpalette", selection: $selectedVisualPattern) {
                            ForEach(VisualPatternMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        Text(selectedVisualPattern.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !model.dockPinCandidates.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Dock Policy")
                                .font(.subheadline.weight(.semibold))

                            Toggle("Keep current Dock apps sticky", isOn: $model.keepCurrentDockApps)
                                .tint(Tab.setup.accent)
                            Toggle("Prioritize essential apps (Phone, Messages, Maps)", isOn: $model.prioritizeEssentialDockApps)
                                .tint(Tab.setup.accent)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(model.dockPinCandidates, id: \.self) { appName in
                                        let pinned = model.isDockPinned(appName)
                                        Button {
                                            model.toggleDockPin(appName)
                                        } label: {
                                            Label(appName, systemImage: pinned ? "pin.fill" : "pin")
                                                .font(.caption.weight(.semibold))
                                                .lineLimit(1)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(pinned ? Tab.setup.accent.opacity(0.20) : Color(.tertiarySystemFill))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        showStyleDetailSheet = true
                    } label: {
                        Label("How \(selectedPreset.title) works", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tab.setup.accent)
                }
            }

            HStack {
                Button("Fine Tune") {
                    fineTuneMode = .weights
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
                    metricPill(title: "Dock", value: "\(model.detectedSlots.filter { $0.slot.type == .dock }.count)")
                    metricPill(title: "Widgets", value: "\(model.widgetLockedSlots.count)")
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

                if !model.detectedSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detected Apps")
                            .font(.subheadline.weight(.semibold))

                        Text("Review names and position quickly. OCR ignores widget text and separates Dock slots when detected.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Array(model.detectedSlots.prefix(6).indices), id: \.self) { index in
                                let detected = model.detectedSlots[index]
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        detectedIconPreview(for: detected)
                                        Text(detected.appName)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                    }
                                    Text(slotHumanLabel(detected.slot))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        if model.detectedSlots.count > 6 {
                            Text("+\(model.detectedSlots.count - 6) more apps")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button("Edit Mappings") {
                                showMappingEditor = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Tab.importData.accent)
                            .accessibilityIdentifier("edit-mappings")

                            Spacer()

                            Button("Reset to OCR") {
                                model.resetDetectedSlotCorrections()
                            }
                            .buttonStyle(.bordered)
                        }

                        if !model.widgetLockedSlots.isEmpty {
                            Text("Widget cells are locked and excluded from auto-placement.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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

            if !model.recommendedDockAppIDs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dock Suggestions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.recommendedDockAppIDs, id: \.self) { appID in
                                Label(model.displayName(for: appID), systemImage: "dock.rectangle")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Tab.plan.accent.opacity(0.14))
                                    )
                            }
                        }
                    }
                }
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

            if !model.recommendedLayoutAssignments.isEmpty {
                Button {
                    showFinalLayoutPreview = true
                } label: {
                    Label("Preview Final Layout", systemImage: "iphone.gen3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("preview-final-layout")
            }

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

    private var mappingEditorSheet: some View {
        MappingOverlayEditorView(
            model: model,
            accent: Tab.importData.accent
        )
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

                    Button("Preview") {
                        showFinalLayoutPreview = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("preview-final-layout")
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
        VStack(spacing: 12) {
            HStack {
                Text("Fine Tune")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Spacer()
                Button("Done") {
                    showTuneSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Tab.setup.accent)
            }

            Picker("Fine Tune", selection: $fineTuneMode) {
                ForEach(FineTuneMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if fineTuneMode == .weights {
                VStack(alignment: .leading, spacing: 10) {
                    weightRow(
                        title: "Utility",
                        detail: "",
                        value: utilityWeightBinding,
                        accent: Tab.setup.accent
                    )
                    weightRow(
                        title: "Flow",
                        detail: "",
                        value: flowWeightBinding,
                        accent: Tab.setup.accent
                    )
                    weightRow(
                        title: "Aesthetics",
                        detail: "",
                        value: aestheticsWeightBinding,
                        accent: Tab.setup.accent
                    )
                    weightRow(
                        title: "Move Cost",
                        detail: "",
                        value: moveCostWeightBinding,
                        accent: Tab.setup.accent
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(model.calibrationCurrentTarget == nil ? "No active session" : "Tap highlighted target")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(model.calibrationProgressLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Button(model.calibrationInProgress ? "Restart Calibration" : "Start Calibration") {
                        model.startCalibration()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tab.setup.accent)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(calibrationCoordinates, id: \.id) { coordinate in
                            Button("\(coordinate.row + 1),\(coordinate.column + 1)") {
                                model.handleCalibrationTap(row: coordinate.row, column: coordinate.column)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(model.calibrationButtonTint(row: coordinate.row, column: coordinate.column))
                            .disabled(!model.calibrationInProgress)
                            .font(.caption.weight(.semibold))
                            .controlSize(.small)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .presentationDetents([.fraction(0.52), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
        .onDisappear {
            syncPresetFromModelWeights()
        }
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

    private func compactSetupPicker<Selection: Hashable, Content: View>(
        title: String,
        icon: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker(title, selection: selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private func stylePresetCard(_ preset: OptimizationPreset) -> some View {
        let isSelected = selectedPreset == preset

        return Button {
            applyPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(preset.title, systemImage: preset.iconName)
                    .font(.subheadline.weight(.semibold))
                Text(preset.shortDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                isSelected ? Tab.setup.accent.opacity(0.16) : Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Tab.setup.accent : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var styleDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(selectedPreset.title, systemImage: selectedPreset.iconName)
                        .font(.title3.weight(.bold))

                    Text(selectedPreset.engineDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 8) {
                        styleWeightRow(title: "Utility", value: selectedPreset.weights.utility)
                        styleWeightRow(title: "Flow", value: selectedPreset.weights.flow)
                        styleWeightRow(title: "Aesthetics", value: selectedPreset.weights.aesthetics)
                        styleWeightRow(title: "Move Cost", value: selectedPreset.weights.moveCost)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Best for: \(selectedPreset.bestFor)")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Tradeoff: \(selectedPreset.tradeoff)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Intent Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showStyleDetailSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func styleWeightRow(title: String, value: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(Tab.setup.accent.opacity(0.85))
                        .frame(width: geometry.size.width * max(0, min(value, 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private func weightRow(title: String, detail: String, value: Binding<Double>, accent: Color) -> some View {
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
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func detectedIconPreview(for detected: DetectedAppSlot) -> some View {
        Group {
            if let data = model.detectedIconPreviewDataBySlot[detected.slot],
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSymbol(for: detected.appName))
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 26, height: 26)
        .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func fallbackSymbol(for appName: String) -> String {
        let key = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.contains("maps") { return "map.fill" }
        if key.contains("calendar") { return "calendar" }
        if key.contains("photo") { return "photo.fill" }
        if key.contains("message") { return "message.fill" }
        if key.contains("mail") { return "envelope.fill" }
        if key.contains("camera") { return "camera.fill" }
        if key.contains("news") { return "newspaper.fill" }
        if key.contains("fitness") { return "figure.run" }
        if key.contains("health") { return "heart.fill" }
        if key.contains("music") { return "music.note" }
        if key.contains("safari") { return "safari.fill" }
        if key.contains("settings") { return "gearshape.fill" }
        return "app.fill"
    }

    private func slotHumanLabel(_ slot: Slot) -> String {
        if slot.type == .dock {
            return "Page \(slot.page + 1) • Dock \(slot.column + 1)"
        }
        if slot.type == .widgetLocked {
            return "Page \(slot.page + 1) • Widget lock R\(slot.row + 1) C\(slot.column + 1)"
        }
        return "Page \(slot.page + 1) • Row \(slot.row + 1) • Col \(slot.column + 1)"
    }

    private func applyPreset(_ preset: OptimizationPreset) {
        selectedPreset = preset
        model.visualModeEnabled = preset == .visualHarmony
        let weights = preset.weights
        model.utilityWeight = weights.utility
        model.flowWeight = weights.flow
        model.aestheticsWeight = weights.aesthetics
        model.moveCostWeight = weights.moveCost
    }

    private func contextBehaviorHint(for context: ProfileContext) -> String {
        switch context {
        case .workday:
            return "Workday defaults to Reach baseline for faster one-hand access."
        case .weekend:
            return "Weekend defaults to Balanced baseline for mixed use."
        case .custom:
            return "Custom defaults to Balanced baseline; label it and refine intent below."
        }
    }

    private func syncPresetFromModelWeights() {
        selectedPreset = OptimizationPreset.nearest(to: currentGoalWeights)
        model.visualModeEnabled = selectedPreset == .visualHarmony
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
        slotHumanLabel(slot)
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
    @Published var customContextLabel = ""
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
    @Published var widgetLockedSlots: [Slot] = []
    @Published var detectedIconPreviewDataBySlot: [Slot: Data] = [:]
    @Published var calibrationInProgress = false
    @Published var calibrationCurrentTarget: Slot?
    @Published var calibrationProgressLabel = "0/0"
    @Published var lastCalibrationMap = ReachabilityMap()
    @Published var currentLayoutAssignments: [LayoutAssignment] = []
    @Published var recommendedLayoutAssignments: [LayoutAssignment] = []
    @Published var recommendedDockAppIDs: [UUID] = []
    @Published var keepCurrentDockApps = true
    @Published var prioritizeEssentialDockApps = true
    @Published var pinnedDockAppCanonicalNames: Set<String> = []
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
    @Published var visualModeEnabled = false
    @Published var visualPatternMode: VisualPatternMode = .colorBands

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
    private var originalWidgetLockedSlots: [Slot] = []
    private let appGridTopY = 0.15
    private let appGridBottomY = 0.80
    private let dockTopY = 0.84
    private let dockBottomY = 0.98

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
        seedUITestingStateIfRequested()
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

    var dockPinCandidates: [String] {
        usageEditorAppNames
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

    func previewIconData(for appID: UUID) -> Data? {
        let canonical = canonicalAppName(displayName(for: appID))
        guard !canonical.isEmpty else {
            return nil
        }

        if let slot = detectedSlots.first(where: { canonicalAppName($0.appName) == canonical })?.slot {
            return detectedIconPreviewDataBySlot[slot]
        }

        return nil
    }

    func presentStatus(_ message: String, level: StatusLevel = .info) {
        showStatus(message, level: level)
    }

    func applyContextBaseline(for context: ProfileContext) {
        let weights: GoalWeights
        switch context {
        case .workday:
            weights = OptimizationIntent.reachFirst.weights
        case .weekend, .custom:
            weights = OptimizationIntent.balanced.weights
        }

        utilityWeight = weights.utility
        flowWeight = weights.flow
        aestheticsWeight = weights.aesthetics
        moveCostWeight = weights.moveCost
        visualModeEnabled = false
    }

    func loadSelectedProfileIntoEditor() {
        guard let profile = activeProfile() else {
            showStatus("Select a profile first.", level: .info)
            return
        }

        profileName = profile.name
        context = profile.context
        customContextLabel = profile.customContextLabel ?? ""
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

        let resolvedName = resolvedProfileNameForSave()

        let answers = OnboardingAnswers(
            preferredName: resolvedName,
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
        let customLabel = customContextLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.customContextLabel = context == .custom ? (customLabel.isEmpty ? nil : customLabel) : nil
        if !lastCalibrationMap.slotWeights.isEmpty {
            profile.reachabilityMap = lastCalibrationMap
        }

        do {
            try profileRepository.upsert(profile)
            loadProfiles()
            selectedProfileID = profile.id
            profileName = profile.name
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
            widgetLockedSlots = []
            originalWidgetLockedSlots = []
            detectedIconPreviewDataBySlot = [:]
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
            widgetLockedSlots = []
            originalWidgetLockedSlots = []
            detectedIconPreviewDataBySlot = [:]
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
            if lhs.slot.type != rhs.slot.type {
                return lhs.slot.type == .app
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
        let dockRecommendations = recommendDockApps(
            apps: apps,
            assignments: assignments
        )
        recommendedDockAppIDs = dockRecommendations

        let generated = layoutPlanner.generate(
            profile: profile,
            apps: apps,
            currentAssignments: assignments
        )
        var recommendedPlan = generated.recommendedPlan
        if visualModeEnabled {
            recommendedPlan.assignments = applyVisualPattern(
                assignments: recommendedPlan.assignments,
                appNamesByID: appNames,
                mode: visualPatternMode
            )
        }
        if !dockRecommendations.isEmpty {
            recommendedPlan.assignments = applyDockRecommendations(
                assignments: recommendedPlan.assignments,
                dockAppIDs: dockRecommendations
            )
        }
        let planMoves = movePlanBuilder.buildMoves(
            current: assignments,
            target: recommendedPlan.assignments
        )
        let simulation = whatIfSimulation.compare(
            currentScore: generated.currentScore,
            candidateScore: recommendedPlan.scoreBreakdown,
            moveCount: planMoves.count
        )
        let previousPlan = recommendationHistory.first

        currentLayoutAssignments = assignments
        recommendedLayoutAssignments = recommendedPlan.assignments
        moveSteps = planMoves
        simulationSummary = simulation
        appNamesByID = appNames
        activeRecommendationPlanID = recommendedPlan.id
        completedMoveStepIDs = []
        persistGuidedApplyDraft()
        do {
            try layoutPlanRepository.upsert(recommendedPlan)
            loadRecommendationHistoryForSelectedProfile()
        } catch {
            showStatus("Generated guide but failed to save plan history: \(error.localizedDescription)", level: .error)
        }

        if let previousPlan {
            historyComparisonMessage = buildHistoryComparisonMessage(
                currentPlan: recommendedPlan,
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
            planID: recommendedPlan.id,
            payload: [
                "move_count": String(planMoves.count),
                "score_delta": String(format: "%.3f", simulation.aggregateScoreDelta)
            ]
        )
        trackAnalyticsEvent(
            .guidedApplyStarted,
            profileID: profile.id,
            planID: recommendedPlan.id,
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
        let originalSlot = mutable.slot
        let pageUpperBound = max((importSession?.pages.count ?? 1) - 1, 0)
        let rowUpperBound = 5
        let columnUpperBound = 3

        mutable.slot.page = min(max(0, mutable.slot.page + pageDelta), pageUpperBound)
        if mutable.slot.type == .dock {
            mutable.slot.row = 0
        } else {
            mutable.slot.row = min(max(0, mutable.slot.row + rowDelta), rowUpperBound)
        }
        mutable.slot.column = min(max(0, mutable.slot.column + columnDelta), columnUpperBound)
        detectedSlots[index] = mutable

        if originalSlot != mutable.slot, let preview = detectedIconPreviewDataBySlot.removeValue(forKey: originalSlot) {
            detectedIconPreviewDataBySlot[mutable.slot] = preview
        }
    }

    func setDetectedSlot(index: Int, page: Int? = nil, row: Int? = nil, column: Int? = nil, type: SlotType? = nil) {
        guard detectedSlots.indices.contains(index) else {
            return
        }

        let pageUpperBound = max((importSession?.pages.count ?? 1) - 1, 0)
        let rowUpperBound = 5
        let columnUpperBound = 3

        var mutable = detectedSlots[index]
        let originalSlot = mutable.slot
        if let type {
            mutable.slot.type = type
        }
        if let page {
            mutable.slot.page = min(max(0, page), pageUpperBound)
        }
        if mutable.slot.type == .dock {
            mutable.slot.row = 0
        } else if let row {
            mutable.slot.row = min(max(0, row), rowUpperBound)
        }
        if let column {
            mutable.slot.column = min(max(0, column), columnUpperBound)
        }
        if mutable.slot.type == .app {
            removeWidgetLock(for: mutable.slot)
        }
        detectedSlots[index] = mutable

        if originalSlot != mutable.slot, let preview = detectedIconPreviewDataBySlot.removeValue(forKey: originalSlot) {
            detectedIconPreviewDataBySlot[mutable.slot] = preview
        }
    }

    func resetDetectedSlotCorrections() {
        guard !originalDetectedSlots.isEmpty else {
            return
        }

        detectedSlots = originalDetectedSlots
        if let pages = importSession?.pages {
            detectedIconPreviewDataBySlot = buildDetectedIconPreviewMap(from: pages, slots: detectedSlots)
        }
        widgetLockedSlots = originalWidgetLockedSlots
        hydrateUsageDraftFromDetectedApps()
        showStatus("Restored OCR-detected labels and slots.", level: .info)
    }

    func isDockPinned(_ appName: String) -> Bool {
        pinnedDockAppCanonicalNames.contains(canonicalAppName(appName))
    }

    func toggleDockPin(_ appName: String) {
        let canonical = canonicalAppName(appName)
        guard !canonical.isEmpty else {
            return
        }
        if pinnedDockAppCanonicalNames.contains(canonical) {
            pinnedDockAppCanonicalNames.remove(canonical)
        } else {
            pinnedDockAppCanonicalNames.insert(canonical)
        }
    }

    func isWidgetLocked(_ slot: Slot) -> Bool {
        guard slot.type == .app else {
            return false
        }
        return widgetLockedSlots.contains(where: { sameGridPosition($0, slot) })
    }

    func toggleWidgetLock(_ slot: Slot) {
        guard slot.type == .app else {
            return
        }

        if let index = widgetLockedSlots.firstIndex(where: { sameGridPosition($0, slot) }) {
            widgetLockedSlots.remove(at: index)
            showStatus("Unlocked cell R\(slot.row + 1)C\(slot.column + 1).", level: .info)
            return
        }

        widgetLockedSlots.append(Slot(page: slot.page, row: slot.row, column: slot.column, type: .widgetLocked))
        widgetLockedSlots.sort { lhs, rhs in
            if lhs.page != rhs.page { return lhs.page < rhs.page }
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }

        let removedIndices = detectedSlots.indices.filter { index in
            sameGridPosition(detectedSlots[index].slot, slot) && detectedSlots[index].slot.type == .app
        }
        for index in removedIndices.sorted(by: >) {
            let removed = detectedSlots.remove(at: index)
            detectedIconPreviewDataBySlot.removeValue(forKey: removed.slot)
        }
        hydrateUsageDraftFromDetectedApps()
        showStatus("Locked cell as widget zone.", level: .info)
    }

    func addDetectedApp(name: String, page: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showStatus("Enter an app name first.", level: .info)
            return
        }

        let rowRange = 0..<6
        let colRange = 0..<4
        let occupied = Set(detectedSlots.filter { $0.slot.page == page }.map(\.slot))
        let locked = Set(widgetLockedSlots.filter { $0.page == page }.map { Slot(page: $0.page, row: $0.row, column: $0.column, type: .app) })

        var target = rowRange.lazy
            .flatMap { row in colRange.lazy.map { col in Slot(page: page, row: row, column: col, type: .app) } }
            .first { !occupied.contains($0) && !locked.contains($0) }

        if target == nil {
            target = colRange
                .map { Slot(page: page, row: 0, column: $0, type: .dock) }
                .first { !occupied.contains($0) }
        }

        guard let target else {
            showStatus("No free slot on this page. Remove or move an existing app first.", level: .error)
            return
        }

        detectedSlots.append(
            DetectedAppSlot(
                appName: normalizeDetectedAppName(trimmed),
                confidence: 0.55,
                slot: target
            )
        )
        sortDetectedSlots()
        hydrateUsageDraftFromDetectedApps()
        showStatus("Added \"\(trimmed)\" to \(target.type == .dock ? "Dock \(target.column + 1)" : "R\(target.row + 1) C\(target.column + 1)").", level: .success)
    }

    func removeDetectedApp(index: Int) {
        guard detectedSlots.indices.contains(index) else {
            return
        }
        let removed = detectedSlots.remove(at: index)
        detectedIconPreviewDataBySlot.removeValue(forKey: removed.slot)
        hydrateUsageDraftFromDetectedApps()
        showStatus("Removed \"\(removed.appName)\" from mapping.", level: .info)
    }

    func renameDetectedApp(index: Int, name: String) {
        guard detectedSlots.indices.contains(index) else {
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showStatus("App name cannot be empty.", level: .info)
            return
        }

        detectedSlots[index].appName = normalizeDetectedAppName(trimmed)
        sortDetectedSlots()
        hydrateUsageDraftFromDetectedApps()
        showStatus("Renamed app to \"\(trimmed)\".", level: .success)
    }

    func autoResolveConflicts(on page: Int) {
        let indices = detectedSlots.indices.filter { detectedSlots[$0].slot.page == page }
        guard !indices.isEmpty else {
            showStatus("No detected apps on this page.", level: .info)
            return
        }

        var grouped: [String: [Int]] = [:]
        for index in indices {
            grouped[slotIdentity(detectedSlots[index].slot), default: []].append(index)
        }

        let duplicateGroups = grouped.values.filter { $0.count > 1 }
        guard !duplicateGroups.isEmpty else {
            showStatus("No slot conflicts on this page.", level: .success)
            return
        }

        var indicesToMove: [Int] = []

        for group in duplicateGroups {
            let sorted = group.sorted { lhs, rhs in
                if detectedSlots[lhs].confidence != detectedSlots[rhs].confidence {
                    return detectedSlots[lhs].confidence > detectedSlots[rhs].confidence
                }
                return detectedSlots[lhs].appName.localizedCaseInsensitiveCompare(detectedSlots[rhs].appName) == .orderedAscending
            }
            for index in sorted.dropFirst() {
                indicesToMove.append(index)
            }
        }

        let movingSet = Set(indicesToMove)
        var occupiedAfterKeep: Set<String> = []
        for index in indices where !movingSet.contains(index) {
            occupiedAfterKeep.insert(slotIdentity(detectedSlots[index].slot))
        }

        var freeAppSlots: [Slot] = []
        for row in 0..<6 {
            for column in 0..<4 {
                let candidate = Slot(page: page, row: row, column: column, type: .app)
                if occupiedAfterKeep.contains(slotIdentity(candidate)) || isWidgetLocked(candidate) {
                    continue
                }
                freeAppSlots.append(candidate)
            }
        }

        var freeDockSlots: [Slot] = (0..<4).map { Slot(page: page, row: 0, column: $0, type: .dock) }
            .filter { !occupiedAfterKeep.contains(slotIdentity($0)) }

        var moved = 0
        for index in indicesToMove {
            let original = detectedSlots[index].slot

            let resolved: Slot?
            if original.type == .dock {
                resolved = popNearestSlot(to: original, from: &freeDockSlots)
                    ?? popNearestSlot(to: original, from: &freeAppSlots)
            } else {
                resolved = popNearestSlot(to: original, from: &freeAppSlots)
                    ?? popNearestSlot(to: original, from: &freeDockSlots)
            }

            if let resolved {
                setDetectedSlot(
                    index: index,
                    page: resolved.page,
                    row: resolved.row,
                    column: resolved.column,
                    type: resolved.type
                )
                occupiedAfterKeep.insert(slotIdentity(resolved))
                moved += 1
            }
        }

        sortDetectedSlots()
        showStatus("Auto-resolved \(moved) duplicate mapping conflict\(moved == 1 ? "" : "s").", level: moved > 0 ? .success : .info)
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
            var mergedWidgetLockedSlots: [Slot] = []
            var locatedCandidatesByPage: [Int: [LocatedOCRLabelCandidate]] = [:]
            let locatingExtractor = ocrExtractor as? any LayoutOCRLocating

            for page in pages {
                let extracted = try await ocrExtractor.extractAppLabels(from: page.filePath)
                mergedCandidates.append(contentsOf: extracted)

                if let locatingExtractor {
                    let located = try await locatingExtractor.extractLocatedAppLabels(from: page.filePath)
                    locatedCandidatesByPage[page.pageIndex] = located
                    let mapped = gridMapper.map(locatedCandidates: located, page: page.pageIndex)
                    mergedDetectedSlots.append(contentsOf: mapped.apps)
                    mergedWidgetLockedSlots.append(contentsOf: mapped.widgetLockedSlots)
                }
            }

            ocrCandidates = ocrPostProcessor.process(mergedCandidates)
            ocrQuality = ocrPostProcessor.estimateImportQuality(from: ocrCandidates)
            detectedSlots = mergedDetectedSlots
                .map { detected in
                    var normalized = detected
                    normalized.appName = normalizeDetectedAppName(detected.appName)
                    return normalized
                }
            sortDetectedSlots()
            widgetLockedSlots = Array(Set(mergedWidgetLockedSlots))
                .sorted { lhs, rhs in
                    if lhs.page != rhs.page { return lhs.page < rhs.page }
                    if lhs.row != rhs.row { return lhs.row < rhs.row }
                    return lhs.column < rhs.column
                }
            removeLikelyWidgetNoiseCandidates()
            let inferredMissingCount = inferMissingSlotsFromIconOccupancy(
                pages: pages,
                locatedCandidatesByPage: locatedCandidatesByPage
            )
            purgeDockPlaceholders()
            reconcileWidgetLocksWithApps()
            detectedIconPreviewDataBySlot = buildDetectedIconPreviewMap(from: pages, slots: detectedSlots)
            originalDetectedSlots = detectedSlots
            originalWidgetLockedSlots = widgetLockedSlots
            hydrateUsageDraftFromDetectedApps()

            if ocrCandidates.isEmpty {
                showStatus("No likely app labels detected.", level: .info)
            } else {
                let dockCount = detectedSlots.filter { $0.slot.type == .dock }.count
                let widgetCount = widgetLockedSlots.count
                showStatus(
                    "Extracted \(ocrCandidates.count) labels and mapped \(detectedSlots.count) apps (\(dockCount) dock, \(widgetCount) widget cells\(inferredMissingCount > 0 ? ", +\(inferredMissingCount) inferred" : "")).",
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
        recommendedDockAppIDs = []
        moveSteps = []
        simulationSummary = nil
        appNamesByID = [:]
        originalDetectedSlots = []
        originalWidgetLockedSlots = []
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

    private func sortDetectedSlots() {
        detectedSlots = detectedSlots.sorted { lhs, rhs in
            if lhs.slot.page != rhs.slot.page {
                return lhs.slot.page < rhs.slot.page
            }
            if lhs.slot.type != rhs.slot.type {
                return lhs.slot.type == .app
            }
            if lhs.slot.row != rhs.slot.row {
                return lhs.slot.row < rhs.slot.row
            }
            if lhs.slot.column != rhs.slot.column {
                return lhs.slot.column < rhs.slot.column
            }
            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }
    }

    private func slotIdentity(_ slot: Slot) -> String {
        let zone = slot.type == .dock ? "dock" : "app"
        return "\(slot.page):\(zone):\(slot.row):\(slot.column)"
    }

    private func sameGridPosition(_ lhs: Slot, _ rhs: Slot) -> Bool {
        lhs.page == rhs.page && lhs.row == rhs.row && lhs.column == rhs.column
    }

    private func removeWidgetLock(for slot: Slot) {
        widgetLockedSlots.removeAll { locked in
            sameGridPosition(locked, slot)
        }
    }

    private func popNearestSlot(to source: Slot, from slots: inout [Slot]) -> Slot? {
        guard !slots.isEmpty else {
            return nil
        }
        let nearestIndex = slots.indices.min { lhs, rhs in
            let lhsDistance = slotDistance(source, slots[lhs])
            let rhsDistance = slotDistance(source, slots[rhs])
            return lhsDistance < rhsDistance
        }
        guard let nearestIndex else {
            return nil
        }
        return slots.remove(at: nearestIndex)
    }

    private func slotDistance(_ lhs: Slot, _ rhs: Slot) -> Int {
        let typePenalty = lhs.type == rhs.type ? 0 : 2
        return abs(lhs.row - rhs.row) + abs(lhs.column - rhs.column) + typePenalty
    }

    private func resolvedProfileNameForSave() -> String {
        let resolver = ProfileNameResolver(existingNames: savedProfiles.map(\.name))
        return resolver.resolve(
            typedName: profileName,
            context: context,
            customContextLabel: customContextLabel,
            handedness: handedness,
            gripMode: gripMode
        )
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

    private func seedUITestingStateIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-uitesting-seed-flow") else {
            return
        }

        let seededProfile = Profile(
            name: "Workday · Right · One-Hand",
            context: .workday,
            handedness: .right,
            gripMode: .oneHand
        )
        try? profileRepository.upsert(seededProfile)
        savedProfiles = [seededProfile]
        selectedProfileID = seededProfile.id
        profileName = seededProfile.name

        let alphaID = UUID()
        let betaID = UUID()
        let gammaID = UUID()

        appNamesByID = [
            alphaID: "Maps",
            betaID: "News",
            gammaID: "Photos"
        ]

        let slotA = Slot(page: 0, row: 1, column: 1)
        let slotB = Slot(page: 0, row: 1, column: 2)
        let slotC = Slot(page: 0, row: 2, column: 1)

        detectedSlots = [
            DetectedAppSlot(appName: "Maps", confidence: 0.94, slot: slotA),
            DetectedAppSlot(appName: "News", confidence: 0.90, slot: slotB),
            DetectedAppSlot(appName: "Photos", confidence: 0.88, slot: slotC)
        ]
        originalDetectedSlots = detectedSlots

        let seededPage = ScreenshotPage(filePath: "/tmp/hso-uitest-seed.png", pageIndex: 0)
        importSession = ScreenshotImportSession(pages: [seededPage])

        currentLayoutAssignments = [
            LayoutAssignment(appID: alphaID, slot: slotA),
            LayoutAssignment(appID: betaID, slot: slotB),
            LayoutAssignment(appID: gammaID, slot: slotC)
        ]
        recommendedLayoutAssignments = [
            LayoutAssignment(appID: alphaID, slot: Slot(page: 0, row: 4, column: 3)),
            LayoutAssignment(appID: betaID, slot: slotB),
            LayoutAssignment(appID: gammaID, slot: Slot(page: 0, row: 3, column: 2))
        ]
        recommendedDockAppIDs = [alphaID, betaID]
        moveSteps = [
            MoveStep(appID: alphaID, fromSlot: slotA, toSlot: Slot(page: 0, row: 4, column: 3)),
            MoveStep(appID: gammaID, fromSlot: slotC, toSlot: Slot(page: 0, row: 3, column: 2))
        ]
        simulationSummary = SimulationSummary(aggregateScoreDelta: 0.142, moveCount: moveSteps.count)
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

    private func inferMissingSlotsFromIconOccupancy(
        pages: [ScreenshotPage],
        locatedCandidatesByPage: [Int: [LocatedOCRLabelCandidate]],
        rows: Int = 6,
        columns: Int = 4
    ) -> Int {
        guard rows > 0, columns > 0, !pages.isEmpty else {
            return 0
        }

        var pageImages: [Int: CGImage] = [:]
        for page in pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            guard let image = UIImage(contentsOfFile: page.filePath)?.cgImage else {
                continue
            }
            pageImages[page.pageIndex] = image
        }

        var inferredWidgetLocks: Set<Slot> = []
        for page in pages {
            guard let cgImage = pageImages[page.pageIndex] else {
                continue
            }
            inferredWidgetLocks.formUnion(
                detectLikelyWidgetLocks(
                    in: cgImage,
                    page: page.pageIndex,
                    rows: rows,
                    columns: columns
                )
            )
        }
        if !inferredWidgetLocks.isEmpty {
            widgetLockedSlots = Array(Set(widgetLockedSlots).union(inferredWidgetLocks))
                .sorted { lhs, rhs in
                    if lhs.page != rhs.page { return lhs.page < rhs.page }
                    if lhs.row != rhs.row { return lhs.row < rhs.row }
                    return lhs.column < rhs.column
                }
            removeLikelyWidgetNoiseCandidates()
        }

        var occupiedSlotIDs = Set(detectedSlots.map { slotIdentity($0.slot) })
        var canonicalNames = Set(
            detectedSlots
                .map { canonicalAppName($0.appName) }
                .filter { !$0.isEmpty }
        )
        var usageSuggestions = importedUsageEntries
            .map(\.appName)
            .filter { !canonicalNames.contains(canonicalAppName($0)) }
        var inferredCount = 0
        var unlabeledCounter = 1
        var usedLocatedLabelIDs: Set<String> = []

        for page in pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            guard let cgImage = pageImages[page.pageIndex] else {
                continue
            }

            let occupancy = likelyOccupiedSlots(
                in: UIImage(cgImage: cgImage),
                page: page.pageIndex,
                rows: rows,
                columns: columns
            )
            let located = locatedCandidatesByPage[page.pageIndex] ?? []

            for entry in occupancy {
                let slot = entry.slot
                guard !occupiedSlotIDs.contains(slotIdentity(slot)) else {
                    continue
                }
                if slot.type == .app, isWidgetLocked(slot) {
                    continue
                }

                var candidateName: String?

                if slot.type == .app,
                   let locatedHint = bestSlotLabelHint(
                       for: slot,
                       from: located,
                       rows: rows,
                       columns: columns,
                       usedLabelIDs: &usedLocatedLabelIDs
                   ) {
                    candidateName = locatedHint
                }

                if candidateName == nil, slot.type == .app {
                    candidateName = recognizeSlotLabelHint(
                        for: slot,
                        in: cgImage,
                        rows: rows,
                        columns: columns
                    )
                }

                if candidateName == nil, slot.type == .app {
                    candidateName = classifyAppIconHint(
                        for: slot,
                        in: cgImage,
                        rows: rows,
                        columns: columns
                    )
                }

                if candidateName == nil, slot.type == .dock {
                    candidateName = classifyDockIconHint(
                        for: slot,
                        in: cgImage,
                        rows: rows,
                        columns: columns
                    )
                }

                if candidateName == nil, !usageSuggestions.isEmpty {
                    candidateName = usageSuggestions.removeFirst()
                }

                if candidateName == nil {
                    if slot.type == .dock {
                        continue
                    }
                    let lowConfidenceTopRow = slot.row <= 1 && entry.score < 0.48
                    let lowConfidenceAnyRow = entry.score < 0.24
                    if lowConfidenceTopRow || lowConfidenceAnyRow {
                        continue
                    }
                    candidateName = "Unlabeled \(unlabeledCounter)"
                    unlabeledCounter += 1
                }

                let normalizedName = normalizeDetectedAppName(candidateName ?? "")
                let canonical = canonicalAppName(normalizedName)
                if !canonical.isEmpty, canonicalNames.contains(canonical) {
                    continue
                }

                if !canonical.isEmpty {
                    canonicalNames.insert(canonical)
                }
                occupiedSlotIDs.insert(slotIdentity(slot))
                detectedSlots.append(
                    DetectedAppSlot(
                        appName: normalizedName,
                        confidence: min(max(entry.score, 0.22), 0.58),
                        slot: slot
                    )
                )
                inferredCount += 1
            }
        }

        if inferredCount > 0 {
            sortDetectedSlots()
        }
        collapseDuplicateCanonicalDetections()
        return inferredCount
    }

    private func removeLikelyWidgetNoiseCandidates() {
        let lowerGridNames = Set(
            detectedSlots
                .filter { $0.slot.type == .app && $0.slot.row >= 2 }
                .map { canonicalAppName($0.appName) }
                .filter { !$0.isEmpty }
        )
        let lowerGridNameList = Array(lowerGridNames)

        detectedSlots.removeAll { detected in
            guard detected.slot.type == .app else {
                return false
            }
            let canonical = canonicalAppName(detected.appName)
            if canonical.isEmpty {
                return false
            }
            if isWidgetLocked(detected.slot) {
                return true
            }
            if isLikelyWidgetNoiseName(canonical) {
                return true
            }
            if lowerGridNames.contains(canonical), detected.slot.row <= 1 {
                return true
            }
            if detected.slot.row <= 1,
               let matched = appNameMatcher.bestMatch(for: canonical, against: lowerGridNameList, minimumScore: 0.86),
               canonical != matched {
                return true
            }
            return false
        }
        collapseDuplicateCanonicalDetections()
        sortDetectedSlots()
    }

    private func collapseDuplicateCanonicalDetections() {
        var grouped: [String: [Int]] = [:]
        for index in detectedSlots.indices {
            let canonical = canonicalAppName(detectedSlots[index].appName)
            guard !canonical.isEmpty else {
                continue
            }
            if let clusterKey = bestCanonicalClusterKey(for: canonical, in: grouped.keys) {
                grouped[clusterKey, default: []].append(index)
            } else {
                grouped[canonical, default: []].append(index)
            }
        }

        var toRemove: Set<Int> = []
        for (_, indices) in grouped where indices.count > 1 {
            let sorted = indices.sorted { lhs, rhs in
                let left = duplicateCandidateRank(detectedSlots[lhs])
                let right = duplicateCandidateRank(detectedSlots[rhs])
                if left != right {
                    return left > right
                }
                return detectedSlots[lhs].confidence > detectedSlots[rhs].confidence
            }
            guard let keep = sorted.first else {
                continue
            }
            for index in sorted where index != keep {
                let slot = detectedSlots[index].slot
                if slot.type == .app, slot.row <= 1 {
                    widgetLockedSlots.append(
                        Slot(page: slot.page, row: slot.row, column: slot.column, type: .widgetLocked)
                    )
                }
                toRemove.insert(index)
            }
        }

        if !toRemove.isEmpty {
            detectedSlots = detectedSlots.enumerated().compactMap { index, item in
                toRemove.contains(index) ? nil : item
            }
            widgetLockedSlots = Array(Set(widgetLockedSlots)).sorted { lhs, rhs in
                if lhs.page != rhs.page { return lhs.page < rhs.page }
                if lhs.row != rhs.row { return lhs.row < rhs.row }
                return lhs.column < rhs.column
            }
        }
    }

    private func bestCanonicalClusterKey(
        for canonical: String,
        in keys: Dictionary<String, [Int]>.Keys
    ) -> String? {
        var bestKey: String?
        var bestScore = 0.0
        for key in keys {
            let score = appNameMatcher.similarity(canonical, key)
            if score > bestScore {
                bestScore = score
                bestKey = key
            }
        }
        return bestScore >= 0.92 ? bestKey : nil
    }

    private func purgeDockPlaceholders() {
        detectedSlots.removeAll { detected in
            guard detected.slot.type == .dock else {
                return false
            }
            let canonical = canonicalAppName(detected.appName)
            let placeholder = canonical.hasPrefix("dock slot") || canonical.hasPrefix("unlabeled")
            return placeholder && detected.confidence < 0.75
        }
        sortDetectedSlots()
    }

    private func reconcileWidgetLocksWithApps() {
        let appSlotsByConfidence = Dictionary(uniqueKeysWithValues: detectedSlots.map { ($0.slot, $0.confidence) })
        widgetLockedSlots = widgetLockedSlots.filter { locked in
            let appSlot = Slot(page: locked.page, row: locked.row, column: locked.column, type: .app)
            guard let confidence = appSlotsByConfidence[appSlot] else {
                return true
            }
            return confidence < 0.86
        }
        widgetLockedSlots = Array(Set(widgetLockedSlots)).sorted { lhs, rhs in
            if lhs.page != rhs.page { return lhs.page < rhs.page }
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }
    }

    private func duplicateCandidateRank(_ detected: DetectedAppSlot) -> Double {
        var score = detected.confidence
        if detected.slot.type == .app {
            score += 0.10
            score += Double(detected.slot.row) * 0.04
        } else {
            score += 0.02
        }
        if isWidgetLocked(detected.slot) {
            score -= 0.40
        }
        return score
    }

    private func isLikelyWidgetNoiseName(_ canonicalName: String) -> Bool {
        let key = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            return true
        }

        let exactNoise: Set<String> = [
            "sun", "mon", "tue", "wed", "thu", "fri", "sat",
            "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
            "today", "tomorrow", "yesterday", "no events", "no events today", "search", "widget"
        ]
        if exactNoise.contains(key) {
            return true
        }
        if key.range(of: #"^\d{1,2}$"#, options: .regularExpression) != nil {
            return true
        }
        let fragments = [
            "weather", "calendar widget", "batteries", "screen time", "reminders due", "event"
        ]
        return fragments.contains(where: { key.contains($0) })
    }

    private func detectLikelyWidgetLocks(
        in image: CGImage,
        page: Int,
        rows: Int,
        columns: Int
    ) -> Set<Slot> {
#if canImport(Vision)
        guard rows > 0, columns > 0 else {
            return []
        }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 32
        request.minimumSize = 0.14
        request.minimumAspectRatio = 0.70
        request.maximumAspectRatio = 2.00
        request.minimumConfidence = 0.55
        request.quadratureTolerance = 18.0

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let gridHeight = max(appGridBottomY - appGridTopY, 0.0001)
        let cellWidth = 1.0 / Double(columns)
        let cellHeight = gridHeight / Double(rows)
        let minimumWidgetArea = cellWidth * cellHeight * 2.8

        var locked: Set<Slot> = []
        for observation in request.results ?? [] {
            let rect = observation.boundingBox
            let normalizedTopRect = CGRect(
                x: rect.minX,
                y: 1.0 - rect.maxY,
                width: rect.width,
                height: rect.height
            )

            if normalizedTopRect.maxY > appGridBottomY + 0.02 {
                continue
            }
            if normalizedTopRect.minY < appGridTopY - 0.05 {
                continue
            }
            let maxWidgetRowStart = appGridTopY + (cellHeight * 3.2)
            if normalizedTopRect.minY > maxWidgetRowStart {
                continue
            }
            if Double(normalizedTopRect.width * normalizedTopRect.height) < minimumWidgetArea {
                continue
            }
            if normalizedTopRect.width < CGFloat(cellWidth * 1.45) || normalizedTopRect.height < CGFloat(cellHeight * 1.45) {
                continue
            }

            for row in 0..<rows {
                for column in 0..<columns {
                    let cellRect = CGRect(
                        x: Double(column) * cellWidth,
                        y: appGridTopY + (Double(row) * cellHeight),
                        width: cellWidth,
                        height: cellHeight
                    )
                    let overlap = cellRect.intersection(normalizedTopRect)
                    guard !overlap.isNull else {
                        continue
                    }
                    let overlapRatio = (overlap.width * overlap.height) / (cellRect.width * cellRect.height)
                    if overlapRatio >= 0.45 {
                        locked.insert(Slot(page: page, row: row, column: column, type: .widgetLocked))
                    }
                }
            }
        }

        return locked
#else
        _ = image
        _ = page
        _ = rows
        _ = columns
        return []
#endif
    }

    private func bestSlotLabelHint(
        for slot: Slot,
        from candidates: [LocatedOCRLabelCandidate],
        rows: Int,
        columns: Int,
        usedLabelIDs: inout Set<String>
    ) -> String? {
        guard slot.type == .app, rows > 0, columns > 0 else {
            return nil
        }

        let gridHeight = max(appGridBottomY - appGridTopY, 0.0001)
        let cellHeight = gridHeight / Double(rows)
        let cellWidth = 1.0 / Double(columns)
        let expectedCenterX = (Double(slot.column) + 0.5) * cellWidth
        let expectedCenterYFromTop = appGridTopY + (Double(slot.row) * cellHeight) + (cellHeight * 0.82)

        var bestText: String?
        var bestScore = -Double.greatestFiniteMagnitude

        for candidate in candidates {
            let normalized = normalizeDetectedAppName(candidate.text)
            let canonical = canonicalAppName(normalized)
            if canonical.isEmpty || isLikelyWidgetNoiseName(canonical) {
                continue
            }

            let labelID = locatedLabelID(candidate)
            if usedLabelIDs.contains(labelID) {
                continue
            }

            let yFromTop = 1.0 - min(max(candidate.centerY, 0), 1)
            let x = min(max(candidate.centerX, 0), 1)
            let deltaX = abs(x - expectedCenterX)
            let deltaY = abs(yFromTop - expectedCenterYFromTop)
            if deltaX > (cellWidth * 0.62) || deltaY > (cellHeight * 0.88) {
                continue
            }

            let compactnessPenalty = max(0, (candidate.boxWidth - (cellWidth * 0.90))) * 2.4
            let score = candidate.confidence - (deltaX * 1.25) - (deltaY * 2.2) - compactnessPenalty
            if score > bestScore {
                bestScore = score
                bestText = normalized
            }
        }

        guard let bestText, bestScore >= 0.17 else {
            return nil
        }
        if let matched = candidates.first(where: { normalizeDetectedAppName($0.text) == bestText }) {
            usedLabelIDs.insert(locatedLabelID(matched))
        }
        return bestText
    }

    private func locatedLabelID(_ candidate: LocatedOCRLabelCandidate) -> String {
        "\(canonicalAppName(candidate.text))::\(String(format: "%.3f", candidate.centerX))::\(String(format: "%.3f", candidate.centerY))"
    }

    private func recognizeSlotLabelHint(
        for slot: Slot,
        in image: CGImage,
        rows: Int,
        columns: Int
    ) -> String? {
#if canImport(Vision)
        guard slot.type == .app,
              let labelRect = labelCropRectForSlot(
                  slot: slot,
                  imageWidth: CGFloat(image.width),
                  imageHeight: CGFloat(image.height),
                  rows: rows,
                  columns: columns
              ) else {
            return nil
        }

        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let cropRect = labelRect.integral.intersection(imageBounds)
        guard !cropRect.isNull, cropRect.width > 8, cropRect.height > 8,
              let crop = image.cropping(to: cropRect) else {
            return nil
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.14
        let handler = VNImageRequestHandler(cgImage: crop, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let top = request.results?.first?.topCandidates(1).first else {
            return nil
        }

        let text = normalizeDetectedAppName(top.string.trimmingCharacters(in: .whitespacesAndNewlines))
        let canonical = canonicalAppName(text)
        guard !canonical.isEmpty, !isLikelyWidgetNoiseName(canonical), top.confidence >= 0.24 else {
            return nil
        }

        return text
#else
        _ = slot
        _ = image
        _ = rows
        _ = columns
        return nil
#endif
    }

    private func classifyDockIconHint(
        for slot: Slot,
        in image: CGImage,
        rows: Int,
        columns: Int
    ) -> String? {
#if canImport(Vision)
        guard slot.type == .dock,
              let iconRect = iconCropRectForSlot(
                  slot: slot,
                  imageWidth: CGFloat(image.width),
                  imageHeight: CGFloat(image.height),
                  rows: rows,
                  columns: columns
              ) else {
            return nil
        }

        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let cropRect = iconRect.integral.intersection(imageBounds)
        guard !cropRect.isNull, cropRect.width > 8, cropRect.height > 8,
              let crop = image.cropping(to: cropRect) else {
            return nil
        }
        return classifyIconHint(from: crop, minimumConfidence: 0.16)
#else
        _ = slot
        _ = image
        _ = rows
        _ = columns
        return nil
#endif
    }

    private func classifyAppIconHint(
        for slot: Slot,
        in image: CGImage,
        rows: Int,
        columns: Int
    ) -> String? {
#if canImport(Vision)
        guard slot.type == .app,
              let iconRect = iconCropRectForSlot(
                  slot: slot,
                  imageWidth: CGFloat(image.width),
                  imageHeight: CGFloat(image.height),
                  rows: rows,
                  columns: columns
              ) else {
            return nil
        }

        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let cropRect = iconRect.integral.intersection(imageBounds)
        guard !cropRect.isNull, cropRect.width > 8, cropRect.height > 8,
              let crop = image.cropping(to: cropRect) else {
            return nil
        }

        return classifyIconHint(from: crop, minimumConfidence: 0.18)
#else
        _ = slot
        _ = image
        _ = rows
        _ = columns
        return nil
#endif
    }

    private func classifyIconHint(
        from crop: CGImage,
        minimumConfidence: VNConfidence
    ) -> String? {
#if canImport(Vision)
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: crop, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let mapping: [(needle: String, app: String)] = [
            ("compass", "Safari"),
            ("browser", "Safari"),
            ("speech", "Messages"),
            ("chat", "Messages"),
            ("bubble", "Messages"),
            ("envelope", "Mail"),
            ("phone", "Phone"),
            ("telephone", "Phone"),
            ("map", "Maps"),
            ("navigation", "Maps"),
            ("calendar", "Calendar"),
            ("date", "Calendar"),
            ("photo", "Photos"),
            ("image", "Photos"),
            ("newspaper", "News"),
            ("news", "News"),
            ("camera", "Camera"),
            ("wallet", "Wallet"),
            ("heart", "Health"),
            ("health", "Health"),
            ("gear", "Settings"),
            ("settings", "Settings"),
            ("reminder", "Reminders"),
            ("check", "Reminders"),
            ("folder", "Files"),
            ("document", "Files"),
            ("music", "Music"),
            ("contact", "Contacts"),
            ("person", "Contacts"),
            ("fitness", "Fitness")
        ]

        for result in request.results?.prefix(12) ?? [] {
            let key = result.identifier.lowercased()
            guard result.confidence >= minimumConfidence else {
                continue
            }
            if let match = mapping.first(where: { key.contains($0.needle) }) {
                return match.app
            }
        }
        return nil
#else
        _ = crop
        _ = minimumConfidence
        return nil
#endif
    }

    private func labelCropRectForSlot(
        slot: Slot,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        rows: Int,
        columns: Int
    ) -> CGRect? {
        guard slot.type == .app, rows > 0, columns > 0 else {
            return nil
        }

        let appGridTop = imageHeight * appGridTopY
        let appGridBottom = imageHeight * appGridBottomY
        let appGridHeight = max(1, appGridBottom - appGridTop)
        let cellWidth = imageWidth / CGFloat(columns)
        let cellHeight = appGridHeight / CGFloat(rows)
        let row = max(0, min(rows - 1, slot.row))
        let col = max(0, min(columns - 1, slot.column))

        return CGRect(
            x: CGFloat(col) * cellWidth + (cellWidth * 0.06),
            y: appGridTop + CGFloat(row) * cellHeight + (cellHeight * 0.62),
            width: cellWidth * 0.88,
            height: cellHeight * 0.28
        )
    }

    private func likelyOccupiedSlots(
        in image: UIImage,
        page: Int,
        rows: Int,
        columns: Int
    ) -> [(slot: Slot, score: Double)] {
        guard let cgImage = image.cgImage else {
            return []
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        var appScores: [(slot: Slot, score: Double)] = []
        var dockScores: [(slot: Slot, score: Double)] = []

        for row in 0..<rows {
            for column in 0..<columns {
                let slot = Slot(page: page, row: row, column: column, type: .app)
                guard let score = occupancyScore(
                    for: slot,
                    in: cgImage,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    rows: rows,
                    columns: columns
                ) else {
                    continue
                }
                appScores.append((slot: slot, score: score))
            }
        }

        for column in 0..<columns {
            let slot = Slot(page: page, row: 0, column: column, type: .dock)
            guard let score = occupancyScore(
                for: slot,
                in: cgImage,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                rows: rows,
                columns: columns
            ) else {
                continue
            }
            dockScores.append((slot: slot, score: score))
        }

        let appThreshold = occupancyThreshold(
            scores: appScores.map(\.score),
            minimum: 0.165,
            sigmaScale: 0.66
        )
        let dockThreshold = occupancyThreshold(
            scores: dockScores.map(\.score),
            minimum: 0.155,
            sigmaScale: 0.58
        )

        var selectedApps = appScores
            .filter { $0.score >= appThreshold }
            .map { (slot: $0.slot, score: $0.score) }
        if selectedApps.count < 6 {
            let fallbackThreshold = max(0.145, appThreshold - 0.055)
            for entry in appScores.sorted(by: { $0.score > $1.score }) where entry.score >= fallbackThreshold {
                if selectedApps.contains(where: { $0.slot == entry.slot }) {
                    continue
                }
                selectedApps.append((slot: entry.slot, score: entry.score))
                if selectedApps.count >= 6 {
                    break
                }
            }
        }

        var selectedDock = dockScores
            .filter { $0.score >= dockThreshold }
            .map { (slot: $0.slot, score: $0.score) }
        if selectedDock.count < 2 {
            let fallbackThreshold = max(0.13, dockThreshold - 0.07)
            for entry in dockScores.sorted(by: { $0.score > $1.score }) where entry.score >= fallbackThreshold {
                if selectedDock.contains(where: { $0.slot == entry.slot }) {
                    continue
                }
                selectedDock.append((slot: entry.slot, score: entry.score))
                if selectedDock.count >= 2 {
                    break
                }
            }
        }

        var selected = selectedApps
        selected.append(contentsOf: selectedDock)

        return selected.sorted { lhs, rhs in
            if lhs.slot.type != rhs.slot.type {
                return lhs.slot.type == .app
            }
            if lhs.slot.page != rhs.slot.page {
                return lhs.slot.page < rhs.slot.page
            }
            if lhs.slot.row != rhs.slot.row {
                return lhs.slot.row < rhs.slot.row
            }
            return lhs.slot.column < rhs.slot.column
        }
    }

    private func occupancyScore(
        for slot: Slot,
        in image: CGImage,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        rows: Int,
        columns: Int
    ) -> Double? {
        guard let rawRect = iconCropRectForSlot(
            slot: slot,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            rows: rows,
            columns: columns
        ) else {
            return nil
        }

        let imageBounds = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        let cropRect = rawRect.integral.intersection(imageBounds)
        guard !cropRect.isNull, cropRect.width > 8, cropRect.height > 8,
              let crop = image.cropping(to: cropRect) else {
            return nil
        }
        return occupancyScore(for: crop)
    }

    private func occupancyScore(for crop: CGImage) -> Double? {
        let sampleWidth = 44
        let sampleHeight = 44
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(crop, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var luminance = [Double](repeating: 0, count: sampleWidth * sampleHeight)
        var sumL = 0.0
        var sumL2 = 0.0
        var sumR = 0.0
        var sumG = 0.0
        var sumB = 0.0
        var sumR2 = 0.0
        var sumG2 = 0.0
        var sumB2 = 0.0
        var sumSaturation = 0.0

        for idx in 0..<(sampleWidth * sampleHeight) {
            let base = idx * bytesPerPixel
            let r = Double(pixels[base]) / 255.0
            let g = Double(pixels[base + 1]) / 255.0
            let b = Double(pixels[base + 2]) / 255.0
            let l = (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
            luminance[idx] = l

            let maxChannel = max(r, max(g, b))
            let minChannel = min(r, min(g, b))
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0

            sumL += l
            sumL2 += l * l
            sumR += r
            sumG += g
            sumB += b
            sumR2 += r * r
            sumG2 += g * g
            sumB2 += b * b
            sumSaturation += saturation
        }

        let count = Double(sampleWidth * sampleHeight)

        let meanL = sumL / count
        let varianceL = max(0, (sumL2 / count) - (meanL * meanL))
        let varianceR = max(0, (sumR2 / count) - pow(sumR / count, 2))
        let varianceG = max(0, (sumG2 / count) - pow(sumG / count, 2))
        let varianceB = max(0, (sumB2 / count) - pow(sumB / count, 2))
        let colorVariance = (varianceR + varianceG + varianceB) / 3.0
        let meanSaturation = sumSaturation / count

        var edge = 0.0
        var edgeCount = 0
        for row in 0..<(sampleHeight - 1) {
            for column in 0..<(sampleWidth - 1) {
                let index = (row * sampleWidth) + column
                edge += abs(luminance[index] - luminance[index + 1])
                edge += abs(luminance[index] - luminance[index + sampleWidth])
                edgeCount += 2
            }
        }
        let meanEdge = edgeCount > 0 ? edge / Double(edgeCount) : 0

        return (meanEdge * 0.64) + (colorVariance * 0.95) + (varianceL * 0.44) + (meanSaturation * 0.28)
    }

    private func occupancyThreshold(scores: [Double], minimum: Double, sigmaScale: Double) -> Double {
        guard !scores.isEmpty else {
            return .greatestFiniteMagnitude
        }

        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.reduce(0) { partial, score in
            let delta = score - mean
            return partial + (delta * delta)
        } / Double(scores.count)
        let sigma = sqrt(max(variance, 0))
        return max(minimum, mean + (sigma * sigmaScale))
    }

    private func buildDetectedIconPreviewMap(
        from pages: [ScreenshotPage],
        slots: [DetectedAppSlot],
        rows: Int = 6,
        columns: Int = 4
    ) -> [Slot: Data] {
        guard rows > 0, columns > 0 else {
            return [:]
        }

        let pagesByIndex = Dictionary(uniqueKeysWithValues: pages.map { ($0.pageIndex, $0) })
        var previews: [Slot: Data] = [:]

        for detected in slots {
            guard let page = pagesByIndex[detected.slot.page],
                  let image = UIImage(contentsOfFile: page.filePath),
                  let cgImage = image.cgImage else {
                continue
            }

            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)
            let cellWidth = width / CGFloat(columns)
            let cellHeight = height / CGFloat(rows)
            let imageBounds = CGRect(x: 0, y: 0, width: width, height: height)

            let candidateRects: [CGRect] = [
                iconCropRectFromLabel(
                    for: detected,
                    imageWidth: width,
                    imageHeight: height,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                ),
                iconCropRectFromSlot(
                    for: detected,
                    imageWidth: width,
                    imageHeight: height,
                    rows: rows,
                    columns: columns
                )
            ]
            .compactMap { $0?.integral.intersection(imageBounds) }
            .filter { !$0.isNull && $0.width > 1 && $0.height > 1 }

            for cropRect in candidateRects {
                guard let crop = cgImage.cropping(to: cropRect) else {
                    continue
                }

                let previewImage = UIImage(cgImage: crop)
                if let data = previewImage.pngData() {
                    previews[detected.slot] = data
                    break
                }
            }
        }

        return previews
    }

    private func iconCropRectFromLabel(
        for detected: DetectedAppSlot,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> CGRect? {
        guard let centerXNorm = detected.labelCenterX,
              let centerYNorm = detected.labelCenterY else {
            return nil
        }

        let clampedX = min(max(centerXNorm, 0), 0.9999)
        let clampedY = min(max(centerYNorm, 0), 0.9999)
        let labelCenterX = CGFloat(clampedX) * imageWidth
        let labelCenterYFromTop = CGFloat(1.0 - clampedY) * imageHeight

        let labelWidth = max(CGFloat(detected.labelBoxWidth ?? 0) * imageWidth, cellWidth * 0.34)
        let labelHeight = max(CGFloat(detected.labelBoxHeight ?? 0) * imageHeight, cellHeight * 0.11)

        let minSide = min(cellWidth * 0.55, cellHeight * 0.48)
        let maxSide = min(cellWidth * 0.92, cellHeight * 0.84)
        let iconSide = max(minSide, min(maxSide, labelWidth * 1.25))
        let iconCenterY = labelCenterYFromTop - (labelHeight * 0.72) - (iconSide * 0.52)

        return CGRect(
            x: labelCenterX - (iconSide / 2),
            y: iconCenterY - (iconSide / 2),
            width: iconSide,
            height: iconSide
        )
    }

    private func iconCropRectFromSlot(
        for detected: DetectedAppSlot,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        rows: Int,
        columns: Int
    ) -> CGRect? {
        iconCropRectForSlot(
            slot: detected.slot,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            rows: rows,
            columns: columns
        )
    }

    private func iconCropRectForSlot(
        slot: Slot,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        rows: Int,
        columns: Int
    ) -> CGRect? {
        guard rows > 0, columns > 0 else {
            return nil
        }

        let appGridTop = imageHeight * appGridTopY
        let appGridBottom = imageHeight * appGridBottomY
        let appGridHeight = max(1, appGridBottom - appGridTop)
        let appCellHeight = appGridHeight / CGFloat(rows)
        let appCellWidth = imageWidth / CGFloat(columns)

        if slot.type == .dock {
            let dockTop = imageHeight * dockTopY
            let dockBottom = imageHeight * dockBottomY
            let dockHeight = max(1, dockBottom - dockTop)
            let iconSide = min(appCellWidth * 0.70, dockHeight * 0.74)
            return CGRect(
                x: CGFloat(slot.column) * appCellWidth + (appCellWidth - iconSide) / 2,
                y: dockTop + (dockHeight - iconSide) / 2,
                width: iconSide,
                height: iconSide
            )
        }

        let rowFromTop = max(0, min(rows - 1, slot.row))
        return CGRect(
            x: CGFloat(slot.column) * appCellWidth + (appCellWidth * 0.14),
            y: appGridTop + CGFloat(rowFromTop) * appCellHeight + (appCellHeight * 0.06),
            width: appCellWidth * 0.72,
            height: appCellHeight * 0.62
        )
    }

    private func applyVisualPattern(
        assignments: [LayoutAssignment],
        appNamesByID: [UUID: String],
        mode: VisualPatternMode
    ) -> [LayoutAssignment] {
        guard assignments.count > 1 else {
            return assignments
        }

        let orderedSlots = visualSlotOrder(from: assignments.map(\.slot), mode: mode)
        let orderedAppIDs = assignments
            .map(\.appID)
            .sorted { lhs, rhs in
                let lhsName = appNamesByID[lhs] ?? ""
                let rhsName = appNamesByID[rhs] ?? ""
                let lhsKey = visualSortKey(for: lhsName, mode: mode)
                let rhsKey = visualSortKey(for: rhsName, mode: mode)
                if lhsKey.0 != rhsKey.0 {
                    return lhsKey.0 < rhsKey.0
                }
                return lhsKey.1 < rhsKey.1
            }

        guard orderedAppIDs.count == orderedSlots.count else {
            return assignments
        }

        return zip(orderedAppIDs, orderedSlots).map { appID, slot in
            LayoutAssignment(appID: appID, slot: slot)
        }
    }

    private func recommendDockApps(apps: [AppItem], assignments: [LayoutAssignment]) -> [UUID] {
        guard !apps.isEmpty else {
            return []
        }

        let slotByAppID = Dictionary(uniqueKeysWithValues: assignments.map { ($0.appID, $0.slot) })

        let ranked = apps.sorted { lhs, rhs in
            let lhsUsage = lhs.usageScore ?? 0
            let rhsUsage = rhs.usageScore ?? 0

            let lhsBoost = dockPriorityBoost(for: lhs.displayName, currentlyInDock: slotByAppID[lhs.id]?.type == .dock)
            let rhsBoost = dockPriorityBoost(for: rhs.displayName, currentlyInDock: slotByAppID[rhs.id]?.type == .dock)

            let lhsScore = (lhsUsage * 0.78) + lhsBoost
            let rhsScore = (rhsUsage * 0.78) + rhsBoost
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return Array(ranked.prefix(4).map(\.id))
    }

    private func dockPriorityBoost(for appName: String, currentlyInDock: Bool) -> Double {
        let key = canonicalAppName(appName)
        let essentialDockTerms = ["phone", "messages", "safari", "mail", "camera", "wallet", "maps"]
        let essentialBoost = prioritizeEssentialDockApps && essentialDockTerms.contains(where: { key.contains($0) }) ? 0.22 : 0.0
        let keepDockBoost = keepCurrentDockApps && currentlyInDock ? 0.12 : 0.0
        let pinnedBoost = pinnedDockAppCanonicalNames.contains(key) ? 0.70 : 0.0
        return essentialBoost + keepDockBoost + pinnedBoost
    }

    private func applyDockRecommendations(
        assignments: [LayoutAssignment],
        dockAppIDs: [UUID]
    ) -> [LayoutAssignment] {
        guard !assignments.isEmpty, !dockAppIDs.isEmpty else {
            return assignments
        }

        let assignmentSlots = assignments.map { $0.slot }
        let dockSlots = assignmentSlots
            .filter { $0.type == .dock }
            .sorted { lhs, rhs in lhs.column < rhs.column }
        guard !dockSlots.isEmpty else {
            return assignments
        }

        var mutable = assignments
        var slotByAppID = Dictionary(uniqueKeysWithValues: mutable.map { ($0.appID, $0.slot) })

        for (dockIndex, dockSlot) in dockSlots.enumerated() {
            guard dockIndex < dockAppIDs.count else {
                break
            }
            let desiredAppID = dockAppIDs[dockIndex]
            guard let currentSlotForDesired = slotByAppID[desiredAppID] else {
                continue
            }

            guard let occupantID = slotByAppID.first(where: { $0.value == dockSlot })?.key else {
                continue
            }

            if occupantID == desiredAppID {
                continue
            }

            if let desiredIndex = mutable.firstIndex(where: { $0.appID == desiredAppID }) {
                mutable[desiredIndex].slot = dockSlot
            }

            if let occupantIndex = mutable.firstIndex(where: { $0.appID == occupantID }) {
                mutable[occupantIndex].slot = currentSlotForDesired
            }

            slotByAppID[desiredAppID] = dockSlot
            slotByAppID[occupantID] = currentSlotForDesired
        }

        return mutable
    }

    private func visualSlotOrder(from slots: [Slot], mode: VisualPatternMode) -> [Slot] {
        switch mode {
        case .colorBands:
            return slots.sorted { lhs, rhs in
                if lhs.page != rhs.page { return lhs.page < rhs.page }
                if lhs.row != rhs.row { return lhs.row > rhs.row }
                return lhs.column < rhs.column
            }

        case .rainbowPath:
            return slots.sorted { lhs, rhs in
                if lhs.page != rhs.page { return lhs.page < rhs.page }
                if lhs.row != rhs.row { return lhs.row > rhs.row }
                if lhs.row % 2 == 0 {
                    return lhs.column < rhs.column
                }
                return lhs.column > rhs.column
            }

        case .mirrorBalance:
            let centerRow = 2.5
            let centerCol = 1.5
            return slots.sorted { lhs, rhs in
                if lhs.page != rhs.page { return lhs.page < rhs.page }

                let lhsDistance = abs(Double(lhs.row) - centerRow) + abs(Double(lhs.column) - centerCol)
                let rhsDistance = abs(Double(rhs.row) - centerRow) + abs(Double(rhs.column) - centerCol)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                if lhs.row != rhs.row { return lhs.row > rhs.row }
                return lhs.column < rhs.column
            }
        }
    }

    private func visualSortKey(for appName: String, mode: VisualPatternMode) -> (Int, String) {
        let normalized = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let seed = deterministicVisualSeed(for: normalized)
        let colorBucket = canonicalColorBucket(for: normalized, fallback: seed % 8)

        switch mode {
        case .colorBands:
            return (colorBucket, normalized)
        case .rainbowPath:
            return (seed % 360, normalized)
        case .mirrorBalance:
            return ((colorBucket * 10) + (normalized.count % 10), normalized)
        }
    }

    private func canonicalColorBucket(for appName: String, fallback: Int) -> Int {
        if appName.contains("maps") { return 2 }      // green/blue
        if appName.contains("calendar") { return 1 }  // red
        if appName.contains("photos") { return 5 }    // rainbow
        if appName.contains("news") { return 1 }      // red
        if appName.contains("health") { return 1 }    // pink/red
        if appName.contains("mail") { return 3 }      // blue
        if appName.contains("messages") { return 2 }  // green
        if appName.contains("settings") { return 0 }  // gray
        if appName.contains("camera") { return 0 }    // gray
        if appName.contains("music") { return 4 }     // magenta
        return fallback
    }

    private func deterministicVisualSeed(for text: String) -> Int {
        text.unicodeScalars.reduce(7) { partial, scalar in
            ((partial * 31) + Int(scalar.value)) % 10007
        }
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

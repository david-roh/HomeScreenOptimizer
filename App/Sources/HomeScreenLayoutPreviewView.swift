import Core
import SwiftUI
import UIKit

struct HomeScreenLayoutPreviewView: View {
    @ObservedObject var model: RootViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage = 0
    @State private var showMovedOnly = false
    @State private var transitionProgress = 0.0
    @State private var mode: PreviewMode = .recommended

    private let rows = 6
    private let columns = 4

    private enum PreviewMode: String, CaseIterable, Identifiable {
        case current
        case recommended
        case transition

        var id: String { rawValue }

        var title: String {
            switch self {
            case .current:
                return "Current"
            case .recommended:
                return "Recommended"
            case .transition:
                return "Transition"
            }
        }
    }

    private var previewModel: PreviewLayoutModel {
        PreviewLayoutModel(
            currentAssignments: model.currentLayoutAssignments,
            recommendedAssignments: model.recommendedLayoutAssignments,
            widgetLockedSlots: model.widgetLockedSlots
        )
    }

    private var pageIndices: [Int] {
        previewModel.pageIndices
    }

    private var movedAppIDs: Set<UUID> {
        previewModel.movedAppIDs
    }

    private var beforeAssignments: [LayoutAssignment] {
        previewModel.assignments(on: selectedPage, phase: .current, movedOnly: showMovedOnly)
    }

    private var afterAssignments: [LayoutAssignment] {
        previewModel.assignments(on: selectedPage, phase: .recommended, movedOnly: showMovedOnly)
    }

    private var suggestedDockAppIDs: [UUID] {
        let recommendedHasDock = model.recommendedLayoutAssignments.contains { assignment in
            assignment.slot.page == selectedPage && assignment.slot.type == .dock
        }
        return recommendedHasDock ? [] : model.recommendedDockAppIDs
    }

    private var movedNames: [String] {
        movedAppIDs
            .map(model.displayName(for:))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    controlsCard

                    switch mode {
                    case .current:
                        PhoneLayoutCanvas(
                            title: "Current Layout",
                            subtitle: "What your imported screen currently represents.",
                            assignments: beforeAssignments,
                            widgetLockedSlots: previewModel.widgetLockedSlots.filter { $0.page == selectedPage },
                            movedAppIDs: movedAppIDs,
                            rows: rows,
                            columns: columns,
                            appName: model.displayName(for:),
                            iconData: model.previewIconData(for:),
                            suggestedDockAppIDs: []
                        )
                    case .recommended:
                        PhoneLayoutCanvas(
                            title: "Recommended Layout",
                            subtitle: "Where the optimizer wants each app after reordering.",
                            assignments: afterAssignments,
                            widgetLockedSlots: previewModel.widgetLockedSlots.filter { $0.page == selectedPage },
                            movedAppIDs: movedAppIDs,
                            rows: rows,
                            columns: columns,
                            appName: model.displayName(for:),
                            iconData: model.previewIconData(for:),
                            suggestedDockAppIDs: suggestedDockAppIDs
                        )
                    case .transition:
                        transitionCard
                    }

                    if !movedNames.isEmpty {
                        movedAppsCard
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Final Layout Preview")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("final-layout-preview")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedPage = pageIndices.first ?? 0
                transitionProgress = 0
                mode = .recommended
            }
        }
    }

    private var controlsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Picker("Page", selection: $selectedPage) {
                    ForEach(pageIndices, id: \.self) { page in
                        Text("Page \(page + 1)").tag(page)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Toggle("Moved only", isOn: $showMovedOnly)
                    .labelsHidden()
                    .accessibilityIdentifier("preview-moved-only-toggle")
                Text("Moved only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Mode", selection: $mode) {
                ForEach(PreviewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var movedAppsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moved Apps")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(movedNames.prefix(8)), id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var transitionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Transition")
                    .font(.headline)
                Spacer()
                Button("Animate") {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        transitionProgress = transitionProgress < 0.5 ? 1 : 0
                    }
                }
                .buttonStyle(.bordered)
            }

            TransitionLayoutCanvas(
                progress: transitionProgress,
                current: beforeAssignments,
                recommended: afterAssignments,
                rows: rows,
                columns: columns,
                appName: model.displayName(for:),
                iconData: model.previewIconData(for:)
            )

            Slider(value: $transitionProgress, in: 0...1)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PhoneLayoutCanvas: View {
    let title: String
    let subtitle: String
    let assignments: [LayoutAssignment]
    let widgetLockedSlots: [Slot]
    let movedAppIDs: Set<UUID>
    let rows: Int
    let columns: Int
    let appName: (UUID) -> String
    let iconData: (UUID) -> Data?
    let suggestedDockAppIDs: [UUID]

    private var gridAssignments: [LayoutAssignment] {
        assignments.filter { $0.slot.type != .dock }
    }

    private var dockAssignments: [LayoutAssignment] {
        assignments
            .filter { $0.slot.type == .dock }
            .sorted { $0.slot.column < $1.slot.column }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let frame = CGRect(origin: .zero, size: proxy.size)
                let cellWidth = frame.width / CGFloat(columns)
                let cellHeight = (frame.height * 0.78) / CGFloat(rows)
                let gridTop = frame.height * 0.08
                let dockRect = CGRect(
                    x: frame.width * 0.08,
                    y: frame.height * 0.84,
                    width: frame.width * 0.84,
                    height: frame.height * 0.12
                )
                let dockCellWidth = dockRect.width / CGFloat(columns)

                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )

                    ForEach(widgetLockedSlots, id: \.self) { slot in
                        let x = (CGFloat(slot.column) + 0.5) * cellWidth
                        let y = gridTop + (CGFloat(slot.row) + 0.5) * cellHeight
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gray.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.gray.opacity(0.34), lineWidth: 1)
                            )
                            .frame(width: max(cellWidth - 10, 24), height: max(cellHeight - 10, 18))
                            .overlay(
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            )
                            .position(x: x, y: y)
                    }

                    ForEach(gridAssignments, id: \.appID) { assignment in
                        let x = (CGFloat(assignment.slot.column) + 0.5) * cellWidth
                        let y = gridTop + (CGFloat(assignment.slot.row) + 0.5) * cellHeight
                        let moved = movedAppIDs.contains(assignment.appID)

                        VStack(spacing: 2) {
                            iconView(for: assignment.appID)
                                .frame(width: min(34, cellWidth * 0.70), height: min(34, cellWidth * 0.70))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(moved ? Color.orange : .clear, lineWidth: 1.5)
                                )

                            Text(appName(assignment.appID))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(width: max(cellWidth - 4, 26))
                        }
                        .position(x: x, y: y)
                    }

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.32))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                        )
                        .frame(width: dockRect.width, height: dockRect.height)
                        .position(x: dockRect.midX, y: dockRect.midY)

                    ForEach(0..<columns, id: \.self) { column in
                        let fallbackAppID = suggestedDockAppIDs.indices.contains(column) ? suggestedDockAppIDs[column] : nil
                        let assignment = dockAssignments.first(where: { $0.slot.column == column })
                        if let appID = assignment?.appID ?? fallbackAppID {
                            let moved = movedAppIDs.contains(appID)
                            iconView(for: appID)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(moved ? Color.orange : .clear, lineWidth: 1.4)
                                )
                                .position(
                                    x: dockRect.minX + (CGFloat(column) + 0.5) * dockCellWidth,
                                    y: dockRect.midY
                                )
                        }
                    }
                }
            }
            .frame(height: 420)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func iconView(for appID: UUID) -> some View {
        if let data = iconData(appID),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: fallbackSymbol(for: appName(appID)))
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(.secondary)
                .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
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
        if key.contains("health") { return "heart.fill" }
        if key.contains("music") { return "music.note" }
        if key.contains("settings") { return "gearshape.fill" }
        return "app.fill"
    }
}

private struct TransitionLayoutCanvas: View {
    let progress: Double
    let current: [LayoutAssignment]
    let recommended: [LayoutAssignment]
    let rows: Int
    let columns: Int
    let appName: (UUID) -> String
    let iconData: (UUID) -> Data?

    private var currentByID: [UUID: Slot] {
        Dictionary(uniqueKeysWithValues: current.filter { $0.slot.type != .dock }.map { ($0.appID, $0.slot) })
    }

    private var recommendedByID: [UUID: Slot] {
        Dictionary(uniqueKeysWithValues: recommended.filter { $0.slot.type != .dock }.map { ($0.appID, $0.slot) })
    }

    private var appIDs: [UUID] {
        Array(Set(currentByID.keys).union(recommendedByID.keys))
            .sorted { lhs, rhs in
                appName(lhs).localizedCaseInsensitiveCompare(appName(rhs)) == .orderedAscending
            }
    }

    var body: some View {
        GeometryReader { proxy in
            let frame = CGRect(origin: .zero, size: proxy.size)
            let cellWidth = frame.width / CGFloat(columns)
            let cellHeight = frame.height / CGFloat(rows)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))

                ForEach(appIDs, id: \.self) { appID in
                    if let from = currentByID[appID] ?? recommendedByID[appID],
                       let to = recommendedByID[appID] ?? currentByID[appID] {
                        let fromPoint = CGPoint(
                            x: (CGFloat(from.column) + 0.5) * cellWidth,
                            y: (CGFloat(from.row) + 0.5) * cellHeight
                        )
                        let toPoint = CGPoint(
                            x: (CGFloat(to.column) + 0.5) * cellWidth,
                            y: (CGFloat(to.row) + 0.5) * cellHeight
                        )
                        let x = fromPoint.x + ((toPoint.x - fromPoint.x) * progress)
                        let y = fromPoint.y + ((toPoint.y - fromPoint.y) * progress)

                        icon(appID: appID)
                            .frame(width: min(28, cellWidth * 0.70), height: min(28, cellWidth * 0.70))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .frame(height: 280)
    }

    @ViewBuilder
    private func icon(appID: UUID) -> some View {
        if let data = iconData(appID),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .padding(5)
                .foregroundStyle(.secondary)
                .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

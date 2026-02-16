import Core
import SwiftUI
import UIKit

struct HomeScreenLayoutPreviewView: View {
    @ObservedObject var model: RootViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage = 0
    @State private var showMovedOnly = false
    @State private var transitionProgress = 0.0

    private let rows = 6
    private let columns = 4

    private var previewModel: PreviewLayoutModel {
        PreviewLayoutModel(
            currentAssignments: model.currentLayoutAssignments,
            recommendedAssignments: model.recommendedLayoutAssignments
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        Picker("Page", selection: $selectedPage) {
                            ForEach(pageIndices, id: \.self) { page in
                                Text("Page \(page + 1)").tag(page)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("Moved Only", isOn: $showMovedOnly)
                            .toggleStyle(.switch)
                            .accessibilityIdentifier("preview-moved-only-toggle")
                    }

                    HStack(spacing: 12) {
                        PhoneLayoutCanvas(
                            title: "Current",
                            assignments: beforeAssignments,
                            movedAppIDs: movedAppIDs,
                            rows: rows,
                            columns: columns,
                            appName: model.displayName(for:),
                            iconData: model.previewIconData(for:)
                        )

                        PhoneLayoutCanvas(
                            title: "Recommended",
                            assignments: afterAssignments,
                            movedAppIDs: movedAppIDs,
                            rows: rows,
                            columns: columns,
                            appName: model.displayName(for:),
                            iconData: model.previewIconData(for:)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Transition")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Animate") {
                                withAnimation(.easeInOut(duration: 0.6)) {
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
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(16)
            }
            .navigationTitle("Final Layout Preview")
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
            }
        }
    }
}

private struct PhoneLayoutCanvas: View {
    let title: String
    let assignments: [LayoutAssignment]
    let movedAppIDs: Set<UUID>
    let rows: Int
    let columns: Int
    let appName: (UUID) -> String
    let iconData: (UUID) -> Data?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            GeometryReader { proxy in
                let frame = CGRect(origin: .zero, size: proxy.size)
                let cellWidth = frame.width / CGFloat(columns)
                let cellHeight = frame.height / CGFloat(rows)

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color(.quaternaryLabel), lineWidth: 0.8)
                        )

                    ForEach(assignments, id: \.appID) { assignment in
                        let x = (CGFloat(assignment.slot.column) + 0.5) * cellWidth
                        let y = (CGFloat(assignment.slot.row) + 0.5) * cellHeight
                        let moved = movedAppIDs.contains(assignment.appID)

                        VStack(spacing: 2) {
                            iconView(for: assignment.appID)
                                .frame(width: min(28, cellWidth * 0.62), height: min(28, cellWidth * 0.62))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(moved ? Color.orange.opacity(0.9) : .clear, lineWidth: 1.4)
                                )

                            Text(appName(assignment.appID))
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .frame(width: max(cellWidth - 2, 26))
                        }
                        .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 310)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func iconView(for appID: UUID) -> some View {
        if let data = iconData(appID),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: fallbackSymbol(for: appName(appID)))
                .resizable()
                .scaledToFit()
                .padding(6)
                .foregroundStyle(.secondary)
                .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
        Dictionary(uniqueKeysWithValues: current.map { ($0.appID, $0.slot) })
    }

    private var recommendedByID: [UUID: Slot] {
        Dictionary(uniqueKeysWithValues: recommended.map { ($0.appID, $0.slot) })
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
                    .fill(Color(.secondarySystemBackground))

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

                        VStack(spacing: 2) {
                            icon(appID: appID)
                                .frame(width: min(24, cellWidth * 0.58), height: min(24, cellWidth * 0.58))
                            Text(appName(appID))
                                .font(.system(size: 7, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .frame(width: max(cellWidth - 4, 20))
                        }
                        .position(x: x, y: y)
                    }
                }
            }
        }
        .frame(height: 260)
    }

    @ViewBuilder
    private func icon(appID: UUID) -> some View {
        if let data = iconData(appID),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .padding(5)
                .foregroundStyle(.secondary)
                .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

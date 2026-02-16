import Core
import Ingestion
import SwiftUI
import UIKit

struct MappingGridGeometry {
    let rows: Int
    let columns: Int

    func markerPoint(for slot: Slot, in imageRect: CGRect) -> CGPoint {
        let cellWidth = imageRect.width / CGFloat(columns)
        let cellHeight = imageRect.height / CGFloat(rows)
        return CGPoint(
            x: imageRect.minX + (CGFloat(slot.column) + 0.5) * cellWidth,
            y: imageRect.minY + (CGFloat(slot.row) + 0.5) * cellHeight
        )
    }

    func slot(for point: CGPoint, in imageRect: CGRect, page: Int) -> Slot? {
        guard imageRect.contains(point), imageRect.width > 0, imageRect.height > 0 else {
            return nil
        }

        let normalizedX = (point.x - imageRect.minX) / imageRect.width
        let normalizedY = (point.y - imageRect.minY) / imageRect.height
        let column = Int(normalizedX * CGFloat(columns))
        let row = Int(normalizedY * CGFloat(rows))

        guard (0..<rows).contains(row), (0..<columns).contains(column) else {
            return nil
        }

        return Slot(page: page, row: row, column: column)
    }
}

struct MappingOverlayEditorView: View {
    @ObservedObject var model: RootViewModel
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage = 0
    @State private var selectedAppIndex: Int?
    @State private var showListMode = false

    private let rows = 6
    private let columns = 4
    private var geometry: MappingGridGeometry {
        MappingGridGeometry(rows: rows, columns: columns)
    }

    private var sortedPages: [ScreenshotPage] {
        (model.importSession?.pages ?? []).sorted { $0.pageIndex < $1.pageIndex }
    }

    private var pageIndices: [Int] {
        let indices = sortedPages.map(\.pageIndex)
        return indices.isEmpty ? [0] : indices
    }

    private var pageIndicesSet: Set<Int> {
        Set(pageIndices)
    }

    private var currentPageImage: UIImage? {
        guard let page = sortedPages.first(where: { $0.pageIndex == selectedPage }) else {
            return nil
        }
        return UIImage(contentsOfFile: page.filePath)
    }

    private var indicesOnSelectedPage: [Int] {
        model.detectedSlots.indices.filter { index in
            model.detectedSlots[index].slot.page == selectedPage
        }
    }

    private var conflictSlotsOnSelectedPage: Set<Slot> {
        var counts: [Slot: Int] = [:]

        for index in indicesOnSelectedPage {
            var key = model.detectedSlots[index].slot
            key.type = .app
            counts[key, default: 0] += 1
        }

        return Set(counts.compactMap { entry in
            entry.value > 1 ? entry.key : nil
        })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Picker("Mode", selection: $showListMode) {
                        Text("Overlay").tag(false)
                        Text("List").tag(true)
                    }
                    .pickerStyle(.segmented)

                    Picker("Page", selection: $selectedPage) {
                        ForEach(pageIndices, id: \.self) { page in
                            Text("Page \(page + 1)").tag(page)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if !conflictSlotsOnSelectedPage.isEmpty {
                    Label("Conflicts detected on this page. Move duplicates until red cells disappear.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if showListMode {
                    listFallback
                } else {
                    overlayEditor
                }

                chipStrip
            }
            .padding(16)
            .navigationTitle("Edit Mappings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        model.resetDetectedSlotCorrections()
                        if !pageIndicesSet.contains(selectedPage) {
                            selectedPage = pageIndices.first ?? 0
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedPage = pageIndices.first ?? 0
                selectedAppIndex = indicesOnSelectedPage.first
            }
            .onChange(of: selectedPage) { _, _ in
                if let selectedAppIndex, !indicesOnSelectedPage.contains(selectedAppIndex) {
                    self.selectedAppIndex = indicesOnSelectedPage.first
                }
            }
        }
    }

    private var overlayEditor: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemFill))

            GeometryReader { proxy in
                let canvasRect = CGRect(origin: .zero, size: proxy.size)
                let imageRect = fittedImageRect(in: canvasRect, image: currentPageImage)

                ZStack {
                    if let currentPageImage {
                        Image(uiImage: currentPageImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: canvasRect.width, height: canvasRect.height)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.title2)
                            Text("Add a screenshot to use overlay mapping")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if imageRect.width > 0, imageRect.height > 0 {
                        gridLayer(in: imageRect)

                        ForEach(indicesOnSelectedPage, id: \.self) { index in
                            markerView(index: index, in: imageRect)
                        }

                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        guard let selectedAppIndex,
                                              let slot = geometry.slot(for: value.location, in: imageRect, page: selectedPage) else {
                                            return
                                        }
                                        applySlot(slot, to: selectedAppIndex)
                                    }
                            )
                    }
                }
            }
        }
        .frame(minHeight: 360)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }

    private var listFallback: some View {
        List {
            Section("Detected Apps") {
                ForEach(indicesOnSelectedPage, id: \.self) { index in
                    let detected = model.detectedSlots[index]

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            detectedIconPreview(for: detected)
                            TextField("App name", text: model.bindingForDetectedAppName(index: index))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                        }

                        HStack {
                            Picker("Row", selection: Binding(
                                get: { model.detectedSlots[index].slot.row },
                                set: { model.setDetectedSlot(index: index, row: $0) }
                            )) {
                                ForEach(0..<rows, id: \.self) { row in
                                    Text("Row \(row + 1)").tag(row)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Col", selection: Binding(
                                get: { model.detectedSlots[index].slot.column },
                                set: { model.setDetectedSlot(index: index, column: $0) }
                            )) {
                                ForEach(0..<columns, id: \.self) { column in
                                    Text("Col \(column + 1)").tag(column)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var chipStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap an app, then tap a cell. You can also drag a marker to reassign.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(indicesOnSelectedPage, id: \.self) { index in
                        let detected = model.detectedSlots[index]
                        Button {
                            selectedAppIndex = index
                        } label: {
                            HStack(spacing: 6) {
                                detectedIconPreview(for: detected)
                                Text(detected.appName)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                (selectedAppIndex == index ? accent.opacity(0.18) : Color(.tertiarySystemFill)),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedAppIndex == index ? accent : .clear, lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func gridLayer(in imageRect: CGRect) -> some View {
        ZStack {
            let cellWidth = imageRect.width / CGFloat(columns)
            let cellHeight = imageRect.height / CGFloat(rows)

            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<columns, id: \.self) { column in
                    let slot = Slot(page: selectedPage, row: row, column: column)
                    let isConflict = conflictSlotsOnSelectedPage.contains(slot)

                    Rectangle()
                        .stroke(isConflict ? Color.red.opacity(0.8) : Color.white.opacity(0.35), lineWidth: isConflict ? 1.4 : 0.8)
                        .background(isConflict ? Color.red.opacity(0.12) : Color.clear)
                        .frame(width: cellWidth, height: cellHeight)
                        .position(
                            x: imageRect.minX + (CGFloat(column) + 0.5) * cellWidth,
                            y: imageRect.minY + (CGFloat(row) + 0.5) * cellHeight
                        )
                }
            }
        }
    }

    private func markerView(index: Int, in imageRect: CGRect) -> some View {
        let slot = model.detectedSlots[index].slot
        let point = geometry.markerPoint(for: slot, in: imageRect)
        let isSelected = selectedAppIndex == index

        return VStack(spacing: 2) {
            detectedIconPreview(for: model.detectedSlots[index])
                .frame(width: 24, height: 24)

            Text(model.detectedSlots[index].appName)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(width: 56)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((isSelected ? accent.opacity(0.22) : Color(.systemBackground).opacity(0.82)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? accent : Color.white.opacity(0.45), lineWidth: isSelected ? 1.4 : 0.8)
        )
        .position(point)
        .onTapGesture {
            selectedAppIndex = index
        }
        .gesture(
            DragGesture(minimumDistance: 6)
                .onEnded { value in
                    let destination = CGPoint(
                        x: point.x + value.translation.width,
                        y: point.y + value.translation.height
                    )
                    guard let slot = geometry.slot(for: destination, in: imageRect, page: selectedPage) else {
                        return
                    }
                    applySlot(slot, to: index)
                }
        )
    }

    private func applySlot(_ slot: Slot, to index: Int) {
        model.setDetectedSlot(
            index: index,
            page: slot.page,
            row: slot.row,
            column: slot.column
        )
    }

    private func fittedImageRect(in container: CGRect, image: UIImage?) -> CGRect {
        guard let image, image.size.width > 0, image.size.height > 0,
              container.width > 0, container.height > 0 else {
            return container.insetBy(dx: 1, dy: 1)
        }

        let imageAspect = image.size.width / image.size.height
        let containerAspect = container.width / container.height

        if imageAspect > containerAspect {
            let fittedHeight = container.width / imageAspect
            let y = container.minY + (container.height - fittedHeight) / 2
            return CGRect(x: container.minX, y: y, width: container.width, height: fittedHeight)
        }

        let fittedWidth = container.height * imageAspect
        let x = container.minX + (container.width - fittedWidth) / 2
        return CGRect(x: x, y: container.minY, width: fittedWidth, height: container.height)
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
                    .padding(4)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

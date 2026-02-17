import Core
import Ingestion
import SwiftUI
import UIKit

@MainActor
private enum MappingImageCache {
    private static let dataCache = NSCache<NSString, UIImage>()
    private static let fileCache = NSCache<NSString, UIImage>()

    static func image(from data: Data) -> UIImage? {
        let key = dataKey(for: data) as NSString
        if let cached = dataCache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(data: data) else {
            return nil
        }
        dataCache.setObject(image, forKey: key)
        return image
    }

    static func image(contentsOfFile path: String) -> UIImage? {
        let key = path as NSString
        if let cached = fileCache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        fileCache.setObject(image, forKey: key)
        return image
    }

    private static func dataKey(for data: Data) -> String {
        var hasher = Hasher()
        hasher.combine(data.count)
        for byte in data.prefix(128) {
            hasher.combine(byte)
        }
        return String(hasher.finalize())
    }
}

struct MappingGridGeometry {
    let rows: Int
    let columns: Int
    let appTopInsetRatio: CGFloat
    let appBottomInsetRatio: CGFloat
    let dockTopInsetRatio: CGFloat
    let dockBottomInsetRatio: CGFloat

    init(
        rows: Int,
        columns: Int,
        appTopInsetRatio: CGFloat = 0.15,
        appBottomInsetRatio: CGFloat = 0.20,
        dockTopInsetRatio: CGFloat = 0.84,
        dockBottomInsetRatio: CGFloat = 0.98
    ) {
        self.rows = rows
        self.columns = columns
        self.appTopInsetRatio = appTopInsetRatio
        self.appBottomInsetRatio = appBottomInsetRatio
        self.dockTopInsetRatio = dockTopInsetRatio
        self.dockBottomInsetRatio = dockBottomInsetRatio
    }

    func appGridRect(in imageRect: CGRect) -> CGRect {
        let top = imageRect.minY + (imageRect.height * appTopInsetRatio)
        let bottom = imageRect.maxY - (imageRect.height * appBottomInsetRatio)
        return CGRect(
            x: imageRect.minX,
            y: top,
            width: imageRect.width,
            height: max(1, bottom - top)
        )
    }

    func dockRect(in imageRect: CGRect) -> CGRect {
        let top = imageRect.minY + (imageRect.height * dockTopInsetRatio)
        let bottom = imageRect.minY + (imageRect.height * dockBottomInsetRatio)
        return CGRect(
            x: imageRect.minX + (imageRect.width * 0.04),
            y: top,
            width: imageRect.width * 0.92,
            height: max(1, bottom - top)
        )
    }

    func markerPoint(for slot: Slot, in imageRect: CGRect) -> CGPoint {
        if slot.type == .dock {
            let dockRect = dockRect(in: imageRect)
            let dockCellWidth = dockRect.width / CGFloat(columns)
            return CGPoint(
                x: dockRect.minX + (CGFloat(slot.column) + 0.5) * dockCellWidth,
                y: dockRect.midY
            )
        }

        let gridRect = appGridRect(in: imageRect)
        let cellWidth = gridRect.width / CGFloat(columns)
        let cellHeight = gridRect.height / CGFloat(rows)
        return CGPoint(
            x: gridRect.minX + (CGFloat(slot.column) + 0.5) * cellWidth,
            y: gridRect.minY + (CGFloat(slot.row) + 0.5) * cellHeight
        )
    }

    func slot(for point: CGPoint, in imageRect: CGRect, page: Int) -> Slot? {
        guard imageRect.contains(point), imageRect.width > 0, imageRect.height > 0 else {
            return nil
        }

        let dockRect = dockRect(in: imageRect)
        if dockRect.contains(point) {
            let normalizedDockX = (point.x - dockRect.minX) / max(dockRect.width, 1)
            let dockColumn = Int(normalizedDockX * CGFloat(columns))
            guard (0..<columns).contains(dockColumn) else {
                return nil
            }
            return Slot(page: page, row: 0, column: dockColumn, type: .dock)
        }

        let gridRect = appGridRect(in: imageRect)
        guard gridRect.contains(point) else {
            return nil
        }
        let normalizedX = (point.x - gridRect.minX) / gridRect.width
        let normalizedY = (point.y - gridRect.minY) / gridRect.height
        let column = Int(normalizedX * CGFloat(columns))
        let row = Int(normalizedY * CGFloat(rows))
        guard (0..<rows).contains(row), (0..<columns).contains(column) else {
            return nil
        }

        return Slot(page: page, row: row, column: column, type: .app)
    }
}

struct MappingOverlayEditorView: View {
    @ObservedObject var model: RootViewModel
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage = 0
    @State private var selectedAppIndex: Int?
    @State private var showListMode = false
    @State private var widgetLockMode = false
    @State private var showAddAppPrompt = false
    @State private var addAppName = ""
    @State private var renameAppIndex: Int?
    @State private var renameAppName = ""
    @State private var showRenamePrompt = false
    @State private var markerFilter: MarkerFilter = .review

    private enum MappingZone: String, CaseIterable, Identifiable {
        case grid
        case dock

        var id: String { rawValue }
        var title: String {
            switch self {
            case .grid:
                return "Grid"
            case .dock:
                return "Dock"
            }
        }
    }

    private enum MarkerFilter: String, CaseIterable, Identifiable {
        case review
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .review:
                return "Review"
            case .all:
                return "All"
            }
        }
    }

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
        return MappingImageCache.image(contentsOfFile: page.filePath)
    }

    private var indicesOnSelectedPage: [Int] {
        model.detectedSlots.indices.filter { index in
            model.detectedSlots[index].slot.page == selectedPage
        }
    }

    private var conflictSlotsOnSelectedPage: Set<Slot> {
        var counts: [Slot: Int] = [:]

        for index in indicesOnSelectedPage {
            let key = model.detectedSlots[index].slot
            counts[key, default: 0] += 1
        }

        return Set(counts.compactMap { entry in
            entry.value > 1 ? entry.key : nil
        })
    }

    private var reviewIndicesOnSelectedPage: [Int] {
        indicesOnSelectedPage.filter { index in
            let detected = model.detectedSlots[index]
            let name = detected.appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return detected.confidence < 0.72
                || name.hasPrefix("unlabeled")
                || conflictSlotsOnSelectedPage.contains(detected.slot)
        }
    }

    private var visibleIndicesOnSelectedPage: [Int] {
        if markerFilter == .all {
            return indicesOnSelectedPage
        }
        return reviewIndicesOnSelectedPage.isEmpty ? indicesOnSelectedPage : reviewIndicesOnSelectedPage
    }

    private var widgetSlotsOnSelectedPage: [Slot] {
        model.widgetLockedSlots.filter { $0.page == selectedPage }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Picker("Mode", selection: $showListMode) {
                        Text("Overlay").tag(false)
                        Text("List").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if !showListMode {
                        Picker("Markers", selection: $markerFilter) {
                            ForEach(MarkerFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Picker("Page", selection: $selectedPage) {
                            ForEach(pageIndices, id: \.self) { page in
                                Text("Page \(page + 1)").tag(page)
                            }
                        }
                        .pickerStyle(.menu)

                        Spacer()

                        Button {
                            widgetLockMode.toggle()
                        } label: {
                            Label(widgetLockMode ? "Widgets On" : "Widgets", systemImage: widgetLockMode ? "square.grid.2x2.fill" : "square.grid.2x2")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if !conflictSlotsOnSelectedPage.isEmpty {
                    Label("Conflicts detected on this page. Move duplicates until red cells disappear.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !conflictSlotsOnSelectedPage.isEmpty || widgetLockMode {
                    HStack {
                        if !conflictSlotsOnSelectedPage.isEmpty {
                            Button("Auto Fix Conflicts") {
                                model.autoResolveConflicts(on: selectedPage)
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        if widgetLockMode {
                            Text("Tap a cell to lock/unlock widget area.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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
            .alert("Add Missing App", isPresented: $showAddAppPrompt) {
                TextField("App name", text: $addAppName)
                Button("Cancel", role: .cancel) {
                    addAppName = ""
                }
                Button("Add") {
                    model.addDetectedApp(name: addAppName, page: selectedPage)
                    addAppName = ""
                }
            } message: {
                Text("Add an app that OCR missed, then place it on the overlay.")
            }
            .alert("Rename App", isPresented: $showRenamePrompt) {
                TextField("App name", text: $renameAppName)
                Button("Cancel", role: .cancel) {
                    renameAppName = ""
                    renameAppIndex = nil
                }
                Button("Save") {
                    if let renameAppIndex {
                        model.renameDetectedApp(index: renameAppIndex, name: renameAppName)
                    }
                    renameAppName = ""
                    renameAppIndex = nil
                }
            } message: {
                Text("Update the detected app name for this marker.")
            }
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
                    Button {
                        showAddAppPrompt = true
                    } label: {
                        Image(systemName: "plus")
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
                selectedAppIndex = nil
            }
            .onChange(of: selectedPage) { _, _ in
                if let selectedAppIndex, !indicesOnSelectedPage.contains(selectedAppIndex) {
                    self.selectedAppIndex = nil
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

                        ForEach(visibleIndicesOnSelectedPage, id: \.self) { index in
                            markerView(index: index, in: imageRect)
                        }

                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        guard let slot = geometry.slot(for: value.location, in: imageRect, page: selectedPage) else {
                                            return
                                        }
                                        if widgetLockMode, slot.type == .app {
                                            model.toggleWidgetLock(slot)
                                            return
                                        }
                                        guard let selectedAppIndex else {
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
                            Picker("Zone", selection: zoneBinding(for: index)) {
                                ForEach(MappingZone.allCases) { zone in
                                    Text(zone.title).tag(zone)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Row", selection: rowBinding(for: index)) {
                                ForEach(0..<rows, id: \.self) { row in
                                    Text("Row \(row + 1)").tag(row)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(isDockSlot(at: index))
                            .opacity(isDockSlot(at: index) ? 0.5 : 1.0)

                            Picker("Col", selection: columnBinding(for: index)) {
                                ForEach(0..<columns, id: \.self) { column in
                                    Text("Col \(column + 1)").tag(column)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack {
                            Button("Remove") {
                                model.removeDetectedApp(index: index)
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var chipStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select app chip, then tap grid. Drag marker to reposition. Bottom glass band is Dock.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        showAddAppPrompt = true
                    } label: {
                        Label("Add App", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(visibleIndicesOnSelectedPage, id: \.self) { index in
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
                        .contextMenu {
                            Button {
                                beginRename(index: index)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                model.removeDetectedApp(index: index)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func gridLayer(in imageRect: CGRect) -> some View {
        let appRect = geometry.appGridRect(in: imageRect)
        let dockRect = geometry.dockRect(in: imageRect)
        let cellWidth = appRect.width / CGFloat(columns)
        let cellHeight = appRect.height / CGFloat(rows)
        let dockCellWidth = dockRect.width / CGFloat(columns)

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                .frame(width: appRect.width, height: appRect.height)
                .position(x: appRect.midX, y: appRect.midY)

            appGridCells(appRect: appRect, cellWidth: cellWidth, cellHeight: cellHeight)
            widgetBadges(appRect: appRect, cellWidth: cellWidth, cellHeight: cellHeight)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.46), lineWidth: 0.9)
                )
                .frame(width: dockRect.width, height: dockRect.height)
                .position(x: dockRect.midX, y: dockRect.midY)

            dockCells(dockRect: dockRect, dockCellWidth: dockCellWidth)
        }
    }

    private func appGridCells(appRect: CGRect, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        ForEach(0..<rows, id: \.self) { row in
            ForEach(0..<columns, id: \.self) { column in
                let slot = Slot(page: selectedPage, row: row, column: column, type: .app)
                let isConflict = conflictSlotsOnSelectedPage.contains(slot)
                let isWidgetLocked = model.isWidgetLocked(slot)
                let stroke = isConflict ? Color.red.opacity(0.8) : (isWidgetLocked ? Color.orange.opacity(0.82) : Color.white.opacity(0.35))
                let fill = isConflict ? Color.red.opacity(0.12) : (isWidgetLocked ? Color.orange.opacity(0.16) : Color.clear)
                let width = isConflict ? 1.4 : (isWidgetLocked ? 1.2 : 0.8)

                Rectangle()
                    .stroke(stroke, lineWidth: width)
                    .background(fill)
                    .frame(width: cellWidth, height: cellHeight)
                    .position(
                        x: appRect.minX + (CGFloat(column) + 0.5) * cellWidth,
                        y: appRect.minY + (CGFloat(row) + 0.5) * cellHeight
                    )
            }
        }
    }

    private func widgetBadges(appRect: CGRect, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        ForEach(widgetSlotsOnSelectedPage, id: \.self) { slot in
            let x = appRect.minX + (CGFloat(slot.column) + 0.5) * cellWidth
            let y = appRect.minY + (CGFloat(slot.row) + 0.5) * cellHeight
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 9, weight: .semibold))
                .padding(5)
                .background(Color.orange.opacity(0.30), in: Circle())
                .foregroundStyle(.orange)
                .position(x: x, y: y)
        }
    }

    private func dockCells(dockRect: CGRect, dockCellWidth: CGFloat) -> some View {
        ForEach(0..<columns, id: \.self) { column in
            let slot = Slot(page: selectedPage, row: 0, column: column, type: .dock)
            let isConflict = conflictSlotsOnSelectedPage.contains(slot)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isConflict ? Color.red.opacity(0.92) : Color.white.opacity(0.45), lineWidth: isConflict ? 1.5 : 0.9)
                .frame(width: dockCellWidth - 6, height: dockRect.height - 10)
                .position(
                    x: dockRect.minX + (CGFloat(column) + 0.5) * dockCellWidth,
                    y: dockRect.midY
                )
        }
    }

    private func markerView(index: Int, in imageRect: CGRect) -> some View {
        let slot = model.detectedSlots[index].slot
        let point = geometry.markerPoint(for: slot, in: imageRect)
        let isSelected = selectedAppIndex == index
        let isDock = slot.type == .dock

        return ZStack(alignment: .top) {
            Circle()
                .fill(isDock ? accent.opacity(0.28) : (isSelected ? accent.opacity(0.24) : Color(.systemBackground).opacity(0.88)))
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .stroke(isSelected ? accent : Color.white.opacity(0.55), lineWidth: isSelected ? 1.6 : 0.9)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)

            detectedIconPreview(for: model.detectedSlots[index])
                .frame(width: 22, height: 22)

            if isSelected {
                Text(isDock ? "\(model.detectedSlots[index].appName) · Dock" : model.detectedSlots[index].appName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(accent.opacity(0.45), lineWidth: 0.8)
                    )
                    .offset(y: -24)
            }
        }
        .position(point)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedAppIndex == index {
                beginRename(index: index)
            } else {
                selectedAppIndex = index
            }
        }
        .gesture(
            DragGesture(minimumDistance: 6)
                .onEnded { value in
                    guard !widgetLockMode else {
                        return
                    }
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
            column: slot.column,
            type: slot.type
        )
    }

    private func beginRename(index: Int) {
        guard model.detectedSlots.indices.contains(index) else {
            return
        }
        renameAppIndex = index
        renameAppName = model.detectedSlots[index].appName
        showRenamePrompt = true
    }

    private func zoneBinding(for index: Int) -> Binding<MappingZone> {
        Binding(
            get: {
                model.detectedSlots[index].slot.type == .dock ? .dock : .grid
            },
            set: { newZone in
                model.setDetectedSlot(
                    index: index,
                    row: newZone == .dock ? 0 : model.detectedSlots[index].slot.row,
                    type: newZone == .dock ? .dock : .app
                )
            }
        )
    }

    private func rowBinding(for index: Int) -> Binding<Int> {
        Binding(
            get: { model.detectedSlots[index].slot.row },
            set: { model.setDetectedSlot(index: index, row: $0) }
        )
    }

    private func columnBinding(for index: Int) -> Binding<Int> {
        Binding(
            get: { model.detectedSlots[index].slot.column },
            set: { model.setDetectedSlot(index: index, column: $0) }
        )
    }

    private func isDockSlot(at index: Int) -> Bool {
        model.detectedSlots[index].slot.type == .dock
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
               let image = MappingImageCache.image(from: data) {
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

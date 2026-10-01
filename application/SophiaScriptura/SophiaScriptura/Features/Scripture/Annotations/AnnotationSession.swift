import Foundation
import Observation
import PencilKit

@MainActor @Observable final class AnnotationSession {
    enum Mode: String, CaseIterable { case hidden = "Read Hidden", visible = "Read Visible", draw = "Draw" }
    private(set) var snapshot = AnnotationSnapshot()
    private(set) var reopenGeneration = 0
    private(set) var groupID: UUID?
    private(set) var loaded = false
    private(set) var loading = false
    private(set) var layoutAvailable = false
    private(set) var dirty = false
    private(set) var saving = false
    private(set) var failed = false
    private(set) var notice = ""
    var mode: Mode = .visible
    var marginExpanded = false
    var toolsVisible = false
    var paletteCollapsed = false
    var active = true
    var usingTool = false
    var flush: (() -> Void)?
    var undo: (() -> Void)?
    var redo: (() -> Void)?
    var clear: (() -> Void)?
    private var saveTask: Task<Void, Never>?
    private var editVersion = 0
    private var strokeWaiters: [CheckedContinuation<Void, Never>] = []
    private let repository: any AnnotationRepository
    var group: AnnotationGroup? { snapshot.groups.first { $0.id == groupID } }
    var selected: AnnotationLayer? { group?.layers.first { $0.id == group?.selectedLayerID && $0.deletedAt == nil } }
    var selectedLayout: AnnotationLayout? { selected?.layout ?? group?.layout }
    var liveLayers: [AnnotationLayer] { group?.layers.filter { $0.deletedAt == nil } ?? [] }
    struct LayerChoice: Identifiable {
        let groupID: UUID
        let layer: AnnotationLayer
        let layout: AnnotationLayout
        var id: UUID { layer.id }
    }
    func layers(for document: ChapterDocument) -> [LayerChoice] {
        snapshot.groups.filter { $0.source.editionID == document.editionID && $0.source.book == document.book && $0.source.chapter == document.chapter }
            .flatMap { group in group.layers.filter { $0.deletedAt == nil }.map { LayerChoice(groupID: group.id, layer: $0, layout: $0.layout ?? group.layout) } }
    }
    func deletedLayers(for document: ChapterDocument) -> [LayerChoice] {
        snapshot.groups.filter { $0.source.editionID == document.editionID && $0.source.book == document.book && $0.source.chapter == document.chapter }
            .flatMap { group in group.layers.filter { $0.deletedAt != nil }.map { LayerChoice(groupID: group.id, layer: $0, layout: $0.layout ?? group.layout) } }
    }
    var canTransition: Bool { loaded && !usingTool && !saving && !dirty && !failed }
    init(repository: any AnnotationRepository = AnnotationFileRepository(directory: AnnotationFileRepository.defaultDirectory())) { self.repository = repository }
    func open(_ document: ChapterDocument?) async {
        if !loaded {
            guard !loading else { return }
            loading = true; defer { loading = false }
            do {
                let value = try await repository.load(); snapshot = value.snapshot; loaded = true; failed = false
                notice = value.recovered ? "Recovered the previous good annotation save. Original files retained." : "Undo history starts when a layer is opened."
            } catch { failed = true; notice = error.localizedDescription; return }
        }
        guard let document else { groupID = nil; layoutAvailable = false; return }
        let candidates = snapshot.groups.filter { $0.source.editionID == document.editionID && $0.source.book == document.book && $0.source.chapter == document.chapter }
        groupID = candidates.last(where: { $0.source == AnnotationSource(document) })?.id ?? candidates.last?.id
        refreshLayout(for: document)
    }
    private func refreshLayout(for document: ChapterDocument) {
        layoutAvailable = group.flatMap { group in selectedLayout.map { AnnotationRenderer.matches($0, source: group.source, document: document) } } ?? false
    }
    private func changed() {
        editVersion += 1; dirty = true; failed = false; notice = "Autosaving…"
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, !self.usingTool else { return }
            await self.save()
        }
    }
    func updateDrawing(_ data: Data, layerID: UUID) {
        guard let g = snapshot.groups.firstIndex(where: { $0.id == groupID }),
              let l = snapshot.groups[g].layers.firstIndex(where: { $0.id == layerID }),
              snapshot.groups[g].layers[l].drawing != data else { return }
        snapshot.groups[g].layers[l].drawing = data; snapshot.groups[g].layers[l].revision += 1
        snapshot.groups[g].layers[l].updatedAt = Date(); changed()
    }
    func save() async {
        guard loaded, !usingTool, !saving else { return }
        flush?()
        guard dirty else { return }
        saveTask?.cancel(); saving = true; notice = "Saving…"
        let version = editVersion, value = snapshot
        do {
            let saved = try await repository.save(value, expectedRevision: value.revision)
            snapshot.revision = saved.revision
            if version == editVersion { dirty = false; failed = false; notice = "Saved automatically" }
        } catch { failed = true; notice = "Save failed. Handwriting retained in memory. " + error.localizedDescription }
        saving = false
        if dirty && !failed && !usingTool { await save() }
    }
    func beginStroke() { usingTool = true; toolsVisible = false }
    func finishStroke() {
        usingTool = false
        let waiting = strokeWaiters; strokeWaiters.removeAll()
        waiting.forEach { $0.resume() }
    }
    func prepareForNavigation() async -> Bool {
        if usingTool { await withCheckedContinuation { strokeWaiters.append($0) } }
        if saving {
            while saving { try? await Task.sleep(for: .milliseconds(20)) }
        }
        await save()
        return canTransition
    }
    func transition(_ action: @escaping @MainActor () -> Void) async {
        guard await prepareForNavigation() else { return }
        action()
    }
    func create(document: ChapterDocument, preferences: ReaderPreferences, width: Double) async {
        guard loaded, !usingTool, !saving else { return }
        await save(); guard canTransition else { return }
        if group == nil || group?.source != AnnotationSource(document) || group?.layout.surroundingSpace == false {
            let value = AnnotationGroup(source: AnnotationSource(document), layout: AnnotationRenderer.measure(document, preferences: preferences, width: width))
            snapshot.groups.append(value); groupID = value.id
        }
        guard let g = snapshot.groups.firstIndex(where: { $0.id == groupID }), snapshot.groups[g].source == AnnotationSource(document) else {
            notice = "Scripture source unavailable for a new layer."; return
        }
        let nextName = snapshot.groups.filter { $0.source.editionID == document.editionID && $0.source.book == document.book && $0.source.chapter == document.chapter }
            .flatMap(\.layers).count + 1
        var layer = AnnotationLayer(name: "Study \(nextName)", drawing: PKDrawing().dataRepresentation())
        layer.layout = AnnotationRenderer.measure(document, preferences: preferences, width: width)
        layer.appearance = AnnotationLayerAppearance(preferences)
        snapshot.groups[g].layers.append(layer); snapshot.groups[g].selectedLayerID = layer.id
        refreshLayout(for: document); mode = .draw; toolsVisible = false; paletteCollapsed = false; changed(); await save()
    }
    func select(_ id: UUID) async {
        await transition { [self] in
            guard let g = snapshot.groups.firstIndex(where: { $0.id == groupID }), snapshot.groups[g].layers.contains(where: { $0.id == id && $0.deletedAt == nil }) else { return }
            snapshot.groups[g].selectedLayerID = id; changed()
        }
        await save()
    }
    func select(_ choice: LayerChoice, document: ChapterDocument, reader: ReaderSession) async {
        guard await prepareForNavigation() else { return }
        guard let g = snapshot.groups.firstIndex(where: { $0.id == choice.groupID }),
              let l = snapshot.groups[g].layers.firstIndex(where: { $0.id == choice.id && $0.deletedAt == nil }) else { return }
        groupID = choice.groupID
        snapshot.groups[g].selectedLayerID = choice.id
        refreshLayout(for: document)
        toolsVisible = false
        changed(); await save()
        restoreSelectedAppearance(reader: reader)
    }
    private var pendingAppearanceRestore: ReaderPreferences?
    func restoreSelectedAppearance(reader: ReaderSession) {
        guard let appearance = selected?.appearance else { return }
        let restored = appearance.applying(to: reader.preferences)
        if restored != reader.preferences {
            pendingAppearanceRestore = restored
            reader.updatePreferences(restored)
        }
    }
    func appearanceChanged(to preferences: ReaderPreferences, document: ChapterDocument, width: Double) async {
        if pendingAppearanceRestore == preferences { pendingAppearanceRestore = nil; return }
        pendingAppearanceRestore = nil
        guard await prepareForNavigation(), group?.source == AnnotationSource(document), selected != nil else { return }
        guard let g = snapshot.groups.firstIndex(where: { $0.id == groupID }),
              let l = snapshot.groups[g].layers.firstIndex(where: { $0.id == selected?.id }) else { return }
        let layout = AnnotationRenderer.measure(document, preferences: preferences, width: width)
        let appearance = AnnotationLayerAppearance(preferences)
        guard snapshot.groups[g].layers[l].layout != layout || snapshot.groups[g].layers[l].appearance != appearance else { return }
        let hasInk = (try? PKDrawing(data: snapshot.groups[g].layers[l].drawing))?.strokes.isEmpty == false
        snapshot.groups[g].layers[l].layout = layout
        snapshot.groups[g].layers[l].appearance = appearance
        snapshot.groups[g].layers[l].updatedAt = Date()
        refreshLayout(for: document)
        if hasInk { notice = "Font updated for this layer. Existing marks may need adjustment." }
        changed(); await save()
        if hasInk { notice = "Font updated for this layer. Existing marks may need adjustment." }
    }
    func rename(_ name: String) async {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !name.isEmpty else { return }
        await transition { [self] in
            guard let g = snapshot.groups.firstIndex(where: { $0.id == groupID }), let l = snapshot.groups[g].layers.firstIndex(where: { $0.id == selected?.id }) else { return }
            snapshot.groups[g].layers[l].name = name; snapshot.groups[g].layers[l].updatedAt = Date(); changed()
        }; await save()
    }
    func deleteSelected() async {
        await transition { [self] in
            guard let g = snapshot.groups.firstIndex(where: { $0.id == groupID }), let l = snapshot.groups[g].layers.firstIndex(where: { $0.id == selected?.id }) else { return }
            snapshot.groups[g].layers[l].deletedAt = Date()
            snapshot.groups[g].selectedLayerID = snapshot.groups[g].layers.first { $0.deletedAt == nil }?.id
            if snapshot.groups[g].selectedLayerID == nil { mode = .hidden }
            changed()
        }; await save()
    }
    func restoreLayer(_ id: UUID, document: ChapterDocument? = nil) async {
        await transition { [self] in
            guard let g = snapshot.groups.firstIndex(where: { $0.layers.contains(where: { $0.id == id && $0.deletedAt != nil }) }),
                  let l = snapshot.groups[g].layers.firstIndex(where: { $0.id == id }) else { return }
            groupID = snapshot.groups[g].id
            snapshot.groups[g].layers[l].deletedAt = nil; snapshot.groups[g].selectedLayerID = id
            if let document { refreshLayout(for: document) }
            mode = .visible; changed()
        }; await save()
    }
    func export() async throws -> Data {
        await save(); guard canTransition else { throw AnnotationError.interrupted }
        return try await repository.exportArchive()
    }
    func restore(_ data: Data, document: ChapterDocument?) async {
        await save(); guard !usingTool, !saving, (!loaded || canTransition) else { return }
        saving = true
        do {
            let restored = try await repository.restoreArchive(data, expectedRevision: snapshot.revision)
            reopenGeneration += 1
            snapshot = restored
            notice = "Annotation backup restored. Previous annotations retained for recovery."
            failed = false; loaded = true
        } catch { notice = error.localizedDescription }
        saving = false; await open(document)
    }
    func preRestoreArchive() async throws -> Data {
        await save(); guard canTransition else { throw AnnotationError.interrupted }
        return try await repository.exportPreRestoreArchive()
    }
    func report(_ error: Error) { notice = error.localizedDescription }
}

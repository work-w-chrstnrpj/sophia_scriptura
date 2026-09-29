import SwiftUI
import PencilKit

@MainActor
final class CanvasExperimentSession: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case select = "Select", draw = "Draw", pan = "Pan"
        var id: String { rawValue }
    }
    @Published private(set) var document: CanvasFixture?
    @Published var selection: Set<CanvasFixture.ObjectID> = [.text]
    @Published var mode: Mode = .select
    @Published var fingerDrawing = false
    @Published var erasing = false
    @Published var busy = false
    @Published var interacting = false
    @Published var zoom: CGFloat = 1
    @Published private(set) var message = "Opening sample…"
    @Published private(set) var loadError: String?
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var viewportRequest = UUID()
    var requestedZoom: CGFloat?
    var requestedObject: CanvasFixture.ObjectID?
    var flushInk: (() -> Void)?

    private let store: CanvasFixtureStore
    private var history = CanvasHistory()
    private var revision = 0
    private var saveTask: Task<Void, Never>?

    init(store: CanvasFixtureStore? = nil) {
        var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SP006", isDirectory: true)
        #if DEBUG
        // UI tests use a UUID-scoped disposable fixture, never the owner's sample.
        if let value = ProcessInfo.processInfo.environment["SP006_UI_TEST_FIXTURE"],
           let id = UUID(uuidString: value) {
            directory = directory.appendingPathComponent("UITests").appendingPathComponent(id.uuidString)
        }
        #endif
        self.store = store ?? CanvasFixtureStore(url: directory.appendingPathComponent("canvas-fixture-v1.json"))
    }

    func open() async {
        guard document == nil else { return }
        busy = true
        defer { busy = false }
        do {
            if let loaded = try await store.load() {
                document = loaded
                message = "Saved sample reopened"
            } else {
                let sample = CanvasSample.make()
                try await store.save(sample)
                document = sample
                message = "Sample ready · changes save locally"
            }
            loadError = nil
        } catch {
            // Never silently seed over a damaged existing fixture.
            loadError = "The sample could not be opened. Its saved file has not been replaced."
            message = "Could not open sample"
        }
    }

    func select(_ id: CanvasFixture.ObjectID, add: Bool) {
        guard let document else { return }
        let unit = document.members(of: [id])
        if add {
            if unit.isSubset(of: selection) { selection.subtract(unit) } else { selection.formUnion(unit) }
        } else { selection = unit }
    }

    func commit(_ candidate: CanvasFixture) {
        guard let old = document, candidate != old else { return }
        history.record(old)
        document = candidate
        changed()
    }

    @discardableResult
    func updateInk(_ data: Data, newTransaction: Bool) -> Bool {
        guard var candidate = document, candidate.drawing != data else { return false }
        if newTransaction { history.record(candidate) }
        candidate.drawing = data
        document = candidate
        changed()
        return true
    }

    func nudge(_ delta: CGSize) {
        guard var candidate = document else { return }
        candidate.move(selection, by: delta)
        commit(candidate)
    }

    func group() {
        guard var candidate = document else { return }
        candidate.group(selection)
        commit(candidate)
        selection = candidate.members(of: selection)
    }

    func ungroup() {
        guard var candidate = document else { return }
        candidate.ungroup(selection)
        commit(candidate)
    }

    func updateText(_ text: String) {
        guard var candidate = document else { return }
        candidate.text = String(text.prefix(500))
        commit(candidate)
    }

    func undo() {
        flushInk?()
        guard let current = document, let previous = history.undo(current) else { return }
        document = previous
        selection = previous.members(of: selection)
        changed()
    }

    func redo() {
        flushInk?()
        guard let current = document, let next = history.redo(current) else { return }
        document = next
        selection = next.members(of: selection)
        changed()
    }

    private func changed() {
        revision += 1
        canUndo = !history.undoStack.isEmpty
        canRedo = !history.redoStack.isEmpty
        message = "Unsaved changes"
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard let self else { return }
            _ = await self.saveNow()
        }
    }

    @discardableResult
    func saveNow() async -> Bool {
        guard let snapshot = document else { return false }
        let savingRevision = revision
        message = "Saving sample…"
        do {
            try await store.save(snapshot, revision: savingRevision)
            if savingRevision == revision { message = "Saved on this iPad" }
            return true
        } catch {
            if savingRevision == revision { message = "Save failed · edits remain open; try Save again" }
            return false
        }
    }

    func saveAndReopen() async {
        flushInk?()
        saveTask?.cancel()
        busy = true
        defer { busy = false }
        guard await saveNow() else { return }
        do {
            guard let restored = try await store.load() else { throw FixtureError.invalidContent }
            document = restored
            history = CanvasHistory()
            canUndo = false
            canRedo = false
            message = "Reopened from disk · text, ink, image and groups restored"
        } catch { message = "Reopen failed · your open sample is preserved" }
    }

    func testDamagedRestore() async {
        flushInk?()
        saveTask?.cancel()
        busy = true
        defer { busy = false }
        guard await saveNow(), let before = document else { return }
        do {
            _ = try await store.restore(Data("{damaged fixture".utf8))
            message = "Unexpected result · damaged fixture was accepted"
        } catch {
            do {
                let after = try await store.load()
                message = after == before ? "Damaged restore rejected · saved sample unchanged" : "Saved sample differs · check the fixture"
            } catch { message = "Could not verify the saved sample" }
        }
    }

    func focus(_ object: CanvasFixture.ObjectID = .text) {
        requestedObject = object
        requestedZoom = nil
        viewportRequest = UUID()
    }

    func changeZoom(_ value: CGFloat) {
        requestedObject = nil
        requestedZoom = min(2, max(0.5, value))
        viewportRequest = UUID()
    }
}

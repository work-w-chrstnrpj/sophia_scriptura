#if DEBUG
import SwiftUI
import PencilKit

/// Disposable experiment data only. Never reads or writes production study stores.
@MainActor
final class InkValidationSession: ObservableObject {
    enum Mode: String, CaseIterable { case hidden = "Hidden", visible = "Visible", draw = "Draw" }
    @Published var mode: Mode = .visible
    @Published var layer = 0
    @Published var rules = true
    @Published var narrow = false
    @Published var reading = false
    @Published var unavailable = false
    @Published private(set) var layoutMismatch = false
    private var restoredSignature: String?
    @Published var usingTool = false
    @Published var notice = "Disposable WEB experiment; use test handwriting only."
    @Published var generation = 0
    var drawings = [PKDrawing(), PKDrawing()]
    var undo: (() -> Void)?
    var redo: (() -> Void)?
    var flush: (() -> Void)?
    var signature = ""
    let url: URL
    struct Snapshot: Codable { let signature: String; let drawings: [Data] }
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SP008-disposable/ink.json")
    }
    func save() {
        guard !usingTool else { return }
        flush?()
        do {
            let snapshot = Snapshot(signature: restoredSignature ?? signature, drawings: drawings.map { $0.dataRepresentation() })
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            notice = "Saved both test layers."
        } catch { notice = "Save failed; current ink remains in memory." }
    }
    func reopen() {
        guard !usingTool else { return }
        do {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
            guard snapshot.drawings.count == 2 else { throw CocoaError(.fileReadCorruptFile) }
            let restored = try snapshot.drawings.map { try PKDrawing(data: $0) }
            drawings = restored
            restoredSignature = snapshot.signature
            layoutMismatch = snapshot.signature != signature
            reading = false
            mode = .visible
            generation += 1
            notice = layoutMismatch ? "Layout mismatch: ink retained; background unavailable." : "Reopened both test layers; history starts here."
        } catch { notice = "Reopen failed; file and current ink left intact." }
    }
}
#endif

#if DEBUG
import Darwin
import UIKit
import PencilKit

/// Opt-in, bounded physical-device diagnostic. Requires a disposable UI-test fixture.
/// Reports numeric metrics only; never records note content or drawing bytes.
@MainActor
final class CanvasMemoryProbe: NSObject {
    static var isEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["SP006_MEMORY_PROBE"] == "1"
            && UUID(uuidString: environment["SP006_UI_TEST_FIXTURE"] ?? "") != nil
    }

    private struct Sample: Codable {
        let phase: String
        let elapsedSeconds: Double
        let footprintBytes: UInt64?
        let kernelStatus: Int32
        let strokes: Int
    }
    private struct Report: Codable {
        let completed: Bool
        let osVersion: String
        let memoryWarnings: Int
        let savesSucceeded: Bool
        let samples: [Sample]
    }
    private var samples: [Sample] = []
    private var warnings = 0
    private var savesSucceeded = true
    private let started = ProcessInfo.processInfo.systemUptime

    @objc private func memoryWarning() { warnings += 1 }

    func run(_ session: CanvasExperimentSession) async {
        guard Self.isEnabled, session.document != nil else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(memoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        defer { NotificationCenter.default.removeObserver(self) }
        do {
            try await Task.sleep(for: .seconds(5))
            try sample("baseline", session)
            let seed = try PKDrawing(data: CanvasSample.make().drawing)
            for cycle in 1...3 {
                for step in 0..<20 {
                    try Task.checkCancellation()
                    guard let document = session.document else { return }
                    var drawing = try PKDrawing(data: document.drawing)
                    // Fixed, small 61-point sample strokes; not simulated Pencil input.
                    let shifted = seed.transformed(using: CGAffineTransform(
                        translationX: CGFloat(step % 5) * 20,
                        y: CGFloat(step / 5) * 60 + CGFloat(cycle) * 20))
                    drawing.strokes.append(contentsOf: shifted.strokes)
                    session.updateInk(drawing.dataRepresentation(), newTransaction: true)
                    session.nudge(CGSize(width: step.isMultiple(of: 2) ? 20 : -20, height: 0))
                    session.undo()
                    session.redo()
                    session.changeZoom([0.5, 1.0, 2.0][step % 3])
                    try await Task.sleep(for: .seconds(1))
                    try sample("cycle-\(cycle)-step-\(step + 1)", session)
                }
                if !(await session.saveNow()) { savesSucceeded = false }
                try await Task.sleep(for: .seconds(10))
                try sample("cycle-\(cycle)-idle", session)
            }
            session.changeZoom(1)
            try await Task.sleep(for: .seconds(15))
            try sample("final-idle", session)
            try writeReport(completed: true)
            print("SP006_MEMORY_PROBE completed")
        } catch {
            try? writeReport(completed: false)
            print("SP006_MEMORY_PROBE incomplete")
        }
    }

    private func sample(_ phase: String, _ session: CanvasExperimentSession) throws {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let drawing = try session.document.map { try PKDrawing(data: $0.drawing) }
        samples.append(Sample(phase: phase,
            elapsedSeconds: ProcessInfo.processInfo.systemUptime - started,
            footprintBytes: status == KERN_SUCCESS ? info.phys_footprint : nil,
            kernelStatus: status, strokes: drawing?.strokes.count ?? 0))
        try writeReport(completed: false)
    }

    private func writeReport(completed: Bool) throws {
        guard let value = ProcessInfo.processInfo.environment["SP006_UI_TEST_FIXTURE"],
              let id = UUID(uuidString: value) else { return }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SP006/Diagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let report = Report(completed: completed, osVersion: UIDevice.current.systemVersion,
                            memoryWarnings: warnings, savesSucceeded: savesSucceeded, samples: samples)
        try JSONEncoder().encode(report).write(to: directory.appendingPathComponent(id.uuidString + ".json"),
                                             options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
#endif

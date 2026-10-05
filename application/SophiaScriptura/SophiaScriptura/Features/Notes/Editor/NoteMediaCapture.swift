import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import Vision
import VisionKit

enum NoteScanMode: String, Identifiable {
    case text, document
    var id: String { rawValue }
}

@MainActor final class NoteAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var recording = false
    private var recorder: AVAudioRecorder?
    private var file: URL?
    var onFinish: ((Data) -> Void)?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("note-audio-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        guard recorder.record() else { throw NotesError.invalid }
        self.recorder = recorder
        file = url
        recording = true
    }

    func stop() {
        recorder?.stop()
        recording = false
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor in
            self.recorder = nil
            self.file = nil
            self.recording = false
            guard flag, let data = try? Data(contentsOf: url), !data.isEmpty else { return }
            try? FileManager.default.removeItem(at: url)
            self.onFinish?(data)
        }
    }
}

enum NoteCapture {
    static var canTakePhoto: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    static var canScan: Bool { VNDocumentCameraViewController.isSupported }
}

enum NoteTextScan {
    static func recognize(_ images: [UIImage]) async -> String {
        let bitmaps: [CGImage] = images.compactMap(\.cgImage)
        return await Task.detached(priority: .userInitiated) {
            var pages: [String] = []
            for bitmap in bitmaps {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                try? VNImageRequestHandler(cgImage: bitmap, options: [:]).perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                if !lines.isEmpty { pages.append(lines.joined(separator: "\n")) }
            }
            return pages.joined(separator: "\n\n")
        }.value
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (Data) -> Void
        init(onImage: @escaping (Data) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.85)
            picker.dismiss(animated: true) { if let image { self.onImage(image) } }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    var onPages: ([UIImage]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPages: onPages) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onPages: ([UIImage]) -> Void
        init(onPages: @escaping ([UIImage]) -> Void) { self.onPages = onPages }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            controller.dismiss(animated: true) { self.onPages(images) }
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { controller.dismiss(animated: true) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { controller.dismiss(animated: true) }
    }
}

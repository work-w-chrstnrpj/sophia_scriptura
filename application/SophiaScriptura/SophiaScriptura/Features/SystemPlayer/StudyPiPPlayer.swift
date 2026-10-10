import AVKit
import Combine
import SwiftUI

/// Projection only. MusicSession and ActivityStore remain the command/data owners.
struct StudyPiPState: Equatable {
    var musicTitle: String?
    var musicPlaying = false
    var activity: ActivitySystemProjection?
    var hasContent: Bool { musicTitle != nil || activity != nil }
    var isPlaying: Bool { musicTitle != nil ? musicPlaying : activity?.isRunning == true }
    var controlLabel: String { musicTitle != nil ? "Play/Pause controls music" : "Play/Pause controls Activity" }
    func columns(at now: Date) -> [(String, String)] {
        var result: [(String, String)] = []
        if let musicTitle { result.append(("Music · \(musicPlaying ? "Playing" : "Paused")", musicTitle)) }
        if let activity {
            let raw = activity.elapsed(at: now)
            let seconds = raw.isFinite ? Int(min(max(0, raw), 359_999)) : 0
            result.append(("Activity · \(activity.isRunning ? "Running" : "Paused")", String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)))
        }
        return result
    }
}

@MainActor
final class StudyPiPPlayer: NSObject, ObservableObject, @preconcurrency AVPictureInPictureControllerDelegate, @preconcurrency AVPictureInPictureSampleBufferPlaybackDelegate {
    @Published private(set) var isEnabled = true
    @Published private(set) var isActive = false
    @Published private(set) var isPossible = false
    @Published private(set) var notice: String?
    let surface = StudyPiPSurface()
    private var controller: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private var timer: Timer?
    @Published private var state = StudyPiPState()
    private weak var music: MusicSession?
    private var subscription: AnyCancellable?
    var aspectRatio: CGFloat { state.musicTitle != nil && state.activity != nil ? 640 / 220 : 400 / 220 }
    private var previewVisible = false
    private var setPlaying: ((Bool) -> Void)?
    var restore: (() -> Void)?

    override init() {
        super.init()
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            notice = "Picture in Picture is not supported on this device."
            return
        }
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        if let timebase {
            CMTimebaseSetTime(timebase, time: CMClockGetTime(CMClockGetHostTimeClock()))
            CMTimebaseSetRate(timebase, rate: 1)
            surface.displayLayer.controlTimebase = timebase
        }
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: surface.displayLayer, playbackDelegate: self)
        let pip = AVPictureInPictureController(contentSource: source)
        pip.delegate = self
        pip.requiresLinearPlayback = true
        // Explicit opt-in. The user starts PiP from the visible preview before going Home.
        pip.canStartPictureInPictureAutomaticallyFromInline = false
        controller = pip
        possibleObservation = pip.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] pip, _ in
            let possible = pip.isPictureInPicturePossible
            Task { @MainActor in self?.isPossible = possible }
        }
    }

    /// Combine remains live during PiP; do not depend on background SwiftUI redraws.
    func bind(music: MusicSession, activity: ActivityStore) {
        guard self.music !== music else { return }
        self.music = music
        subscription = Publishers.CombineLatest(music.$snapshot, activity.$committedProjection)
            .receive(on: RunLoop.main)
            .sink { [weak self, weak music, weak activity] snapshot, projection in
                guard let self, let music else { return }
                let title = snapshot.hasStartedPlayback ? music.tracks.first(where: { $0.id == snapshot.selectedTrackID })?.title : nil
                self.update(StudyPiPState(musicTitle: title, musicPlaying: snapshot.phase == .playing, activity: projection)) { [weak music, weak activity] playing in
                    if music?.showsNowActiveItem == true { music?.handle(playing ? .play : .pause) }
                    else if activity?.snapshot.draft != nil {
                        if playing { activity?.resume() } else { activity?.pause() }
                    }
                }
            }
    }

    deinit { timer?.invalidate() }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        guard !enabled else { return }
        previewVisible = false
        controller?.stopPictureInPicture()
        stopFrames()
        music?.setPictureInPictureActive(false)
    }

    func update(_ value: StudyPiPState, setPlaying: @escaping (Bool) -> Void) {
        state = value
        self.setPlaying = setPlaying
        if !value.hasContent {
            controller?.stopPictureInPicture()
            stopFrames()
        } else if previewVisible || isActive { startFrames() }
        render()
        controller?.invalidatePlaybackState()
    }

    func preview(_ visible: Bool) {
        guard isEnabled else { return }
        previewVisible = visible
        if visible && state.hasContent {
            // iPadOS evaluates PiP eligibility before Start can become enabled.
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                music?.setPictureInPictureActive(true)
                startFrames()
            } catch { notice = "Picture in Picture could not prepare its playback session." }
        } else if !isActive {
            stopFrames()
            music?.setPictureInPictureActive(false)
        }
    }

    func start() {
        guard isEnabled else {
            notice = "Picture in Picture is turned off in Settings."
            return
        }
        guard state.hasContent, isPossible, let controller else {
            notice = "PiP is not ready. Keep this preview open and try again."
            return
        }
        notice = nil
        // No silent audio or second media player. This activates the legitimate PiP
        // presentation session; MusicSession continues to own actual music playback.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            startFrames()
            controller.startPictureInPicture()
        } catch { notice = "Picture in Picture could not start. Your study session is unchanged." }
    }

    private func startFrames() {
        guard isEnabled, timer == nil else { return }
        render()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    private func stopFrames() { timer?.invalidate(); timer = nil }

    private func render() {
        guard isEnabled, state.hasContent, previewVisible || isActive else { return }
        let size = CGSize(width: state.musicTitle != nil && state.activity != nil ? 640 : 400, height: 220)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.08, green: 0.09, blue: 0.1, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let columns = state.columns(at: Date())
            let width = size.width / CGFloat(max(1, columns.count))
            for (index, column) in columns.enumerated() {
                let x = CGFloat(index) * width + 22
                (column.0 as NSString).draw(in: CGRect(x: x, y: 58, width: width - 44, height: 28), withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: UIColor.lightGray])
                let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
                (column.1 as NSString).draw(in: CGRect(x: x, y: 98, width: width - 44, height: 75), withAttributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold), .foregroundColor: UIColor.white, .paragraphStyle: paragraph])
                if index > 0 {
                    UIColor.darkGray.setFill()
                    context.fill(CGRect(x: CGFloat(index) * width, y: 54, width: 1, height: 116))
                }
            }
        }
        enqueue(image, size: size)
    }

    private func enqueue(_ image: UIImage, size: CGSize) {
        let layer = surface.displayLayer
        if layer.status == .failed { layer.flush() }
        guard layer.isReadyForMoreMediaData else { return }
        var pixel: CVPixelBuffer?
        let options: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]]
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, options as CFDictionary, &pixel) == kCVReturnSuccess, let pixel else { return }
        CVPixelBufferLockBaseAddress(pixel, [])
        defer { CVPixelBufferUnlockBaseAddress(pixel, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue), let cgImage = image.cgImage else { return }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        var description: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescriptionOut: &description) == noErr, let description else { return }
        var timing = CMSampleTimingInfo(duration: CMTime(seconds: 1, preferredTimescale: 600), presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixel, formatDescription: description, sampleTiming: &timing, sampleBufferOut: &sample) == noErr, let sample else { return }
        layer.enqueue(sample)
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        guard isEnabled else { pictureInPictureController.stopPictureInPicture(); return }
        isActive = true; music?.setPictureInPictureActive(true); startFrames()
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isActive = false
        music?.setPictureInPictureActive(false)
        if !previewVisible { stopFrames() }
        // Closing PiP never stops music or finishes Activity.
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        notice = "iPadOS could not open PiP. Music and Activity remain available in Sophia."
        isActive = false
        music?.setPictureInPictureActive(false)
        if !previewVisible { stopFrames() }
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        guard isEnabled, let restore else { completionHandler(false); return }
        restore()
        completionHandler(true)
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) { if isEnabled { setPlaying?(playing) } }
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange { CMTimeRange(start: .zero, duration: .positiveInfinity) }
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { !state.isPlaying }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) { completionHandler() }
}

final class StudyPiPSurface: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
    override init(frame: CGRect) { super.init(frame: frame); displayLayer.videoGravity = .resizeAspect; backgroundColor = .black }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { nil }
}

struct StudyPiPPreviewSurface: UIViewRepresentable {
    let player: StudyPiPPlayer
    func makeUIView(context: Context) -> StudyPiPSurface { player.surface }
    func updateUIView(_ view: StudyPiPSurface, context: Context) {}
}

struct StudyPiPSheet: View {
    @ObservedObject var player: StudyPiPPlayer
    var controlLabel: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                StudyPiPPreviewSurface(player: player).aspectRatio(player.aspectRatio, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityLabel("Floating music and Activity status")
                Text(controlLabel).font(.headline)
                Text("Open PiP, then return Home. iPadOS chooses its size and placement. Return to Sophia for separate controls.").foregroundStyle(.secondary)
                Button("Open Picture in Picture", systemImage: "pip.enter") { player.start() }.buttonStyle(.borderedProminent).disabled(!player.isEnabled || !player.isPossible || player.isActive).accessibilityIdentifier("study.pip.start")
                if player.isActive { Label("PiP is open. You can return Home.", systemImage: "checkmark.circle") }
                if let notice = player.notice { Text(notice).foregroundStyle(.secondary) }
                Spacer()
            }.padding(24).navigationTitle("Floating Player").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { player.preview(true) }
        .onDisappear { player.preview(false) }
    }
}

import SwiftUI
import UIKit

/// Observes direct-finger pans from UIKit and SwiftUI surfaces without recognizing a
/// competing gesture, cancelling touches, or accepting Apple Pencil input.
struct ScrollActivityObserver: UIViewRepresentable {
    let onActivity: () -> Void
    func makeUIView(context: Context) -> ScrollActivityView { ScrollActivityView(onActivity: onActivity) }
    func updateUIView(_ view: ScrollActivityView, context: Context) { view.observer.onActivity = onActivity }
    static func dismantleUIView(_ view: ScrollActivityView, coordinator: Void) { view.detach() }
}

final class ScrollActivityView: UIView {
    let observer = FingerActivityRecognizer()
    private weak var observedWindow: UIWindow?
    init(onActivity: @escaping () -> Void) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        observer.onActivity = onActivity
    }
    required init?(coder: NSCoder) { fatalError("Use init(onActivity:)") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        detach()
        guard let window else { return }
        window.addGestureRecognizer(observer)
        observedWindow = window
    }
    func detach() {
        observedWindow?.removeGestureRecognizer(observer)
        observedWindow = nil
    }
}

final class FingerActivityRecognizer: UIGestureRecognizer {
    var onActivity: (() -> Void)?
    private var locations: [UITouch: CGPoint] = [:]
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }
    convenience init() { self.init(target: nil, action: nil) }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { locations[touch] = touch.location(in: view) }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        var moved = false
        for touch in touches {
            let current = touch.location(in: view)
            if let prior = locations[touch], hypot(current.x - prior.x, current.y - prior.y) >= 10 {
                moved = true
                locations[touch] = current
            }
        }
        if moved { onActivity?() }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { locations.removeValue(forKey: touch) }
        if locations.isEmpty { state = .failed }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    override func reset() { super.reset(); locations.removeAll() }
}

import SwiftUI
import UIKit

/// Observes direct-finger pans from UIKit and SwiftUI surfaces without recognizing a
/// competing gesture, cancelling touches, or accepting Apple Pencil input.
struct ScrollActivityObserver: UIViewRepresentable {
    let onActivity: () -> Void
    var onVerticalActivity: (() -> Void)? = nil
    func makeUIView(context: Context) -> ScrollActivityView { ScrollActivityView(onActivity: onActivity, onVerticalActivity: onVerticalActivity) }
    func updateUIView(_ view: ScrollActivityView, context: Context) {
        view.observer.onActivity = onActivity
        view.observer.onVerticalActivity = onVerticalActivity
    }
    static func dismantleUIView(_ view: ScrollActivityView, coordinator: Void) { view.detach() }
}

final class ScrollActivityView: UIView {
    let observer = FingerActivityRecognizer()
    private weak var observedWindow: UIWindow?
    init(onActivity: @escaping () -> Void, onVerticalActivity: (() -> Void)? = nil) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        observer.onActivity = onActivity
        observer.onVerticalActivity = onVerticalActivity
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
    var onVerticalActivity: (() -> Void)?
    private var origins: [UITouch: CGPoint] = [:]
    private var reportedVertical = false
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
        for touch in touches {
            locations[touch] = touch.location(in: view)
            origins[touch] = touch.location(in: view)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        var moved = false
        for touch in touches {
            let current = touch.location(in: view)
            if !reportedVertical, let origin = origins[touch] {
                let dx = current.x - origin.x, dy = current.y - origin.y
                if abs(dy) >= 10 && abs(dy) > abs(dx) * 1.2 {
                    reportedVertical = true
                    onVerticalActivity?()
                }
            }
            if let prior = locations[touch], hypot(current.x - prior.x, current.y - prior.y) >= 10 {
                moved = true
                locations[touch] = current
            }
        }
        if moved { onActivity?() }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches { locations.removeValue(forKey: touch); origins.removeValue(forKey: touch) }
        if locations.isEmpty { state = .failed }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    override func reset() { super.reset(); locations.removeAll(); origins.removeAll(); reportedVertical = false }
}

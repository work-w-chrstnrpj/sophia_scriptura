import SwiftUI

/// Full-screen companion overlay that forwards touches outside interactive SwiftUI content.
struct CompanionOverlayPassthrough<Content: View>: UIViewControllerRepresentable {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> CompanionOverlayViewController<Content> {
        CompanionOverlayViewController(rootView: content)
    }

    func updateUIViewController(_ controller: CompanionOverlayViewController<Content>, context: Context) {
        controller.hosting.rootView = content
    }
}

final class CompanionOverlayViewController<Content: View>: UIViewController {
    let hosting: UIHostingController<Content>
    private let passthroughView = PassthroughRootView()

    init(rootView: Content) {
        hosting = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = passthroughView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hosting)
        passthroughView.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: passthroughView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: passthroughView.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: passthroughView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: passthroughView.bottomAnchor)
        ])
        hosting.view.backgroundColor = .clear
        hosting.didMove(toParent: self)
    }
}

private final class PassthroughRootView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit === self { return nil }
        if let hostingRoot = subviews.first, hit === hostingRoot { return nil }
        return hit
    }
}

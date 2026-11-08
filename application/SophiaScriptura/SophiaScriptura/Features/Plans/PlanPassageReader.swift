import SwiftUI

/// Composes the same reader and PencilKit surfaces used by the Scripture tab.
struct PlanPassageReader: View {
    let reader: ReaderSession
    let document: ChapterDocument
    let annotations: AnnotationSession
    let scope: PlanAnnotationScope
    let layerName: String
    let focus: [Int]?
    @State private var changingMode = false
    @State private var width = 760.0

    private var canUseLayer: Bool {
        annotations.planScope == scope && annotations.group?.source == AnnotationSource(document)
            && annotations.layoutAvailable
    }
    private var showingInk: Bool { canUseLayer && annotations.mode != .hidden }
    private var drawing: Bool { showingInk && annotations.mode == .draw }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if showingInk {
                    Label(layerName, systemImage: "square.3.layers.3d")
                        .lineLimit(1).font(.footnote)
                    Spacer()
                    if drawing {
                        Button("Tools", systemImage: "paintbrush.pointed") { annotations.showDrawingTools() }
                            .disabled(annotations.usingTool)
                        Button("Undo", systemImage: "arrow.uturn.backward") { annotations.undo?() }
                            .disabled(annotations.usingTool)
                        Button("Redo", systemImage: "arrow.uturn.forward") { annotations.redo?() }
                            .disabled(annotations.usingTool)
                    }
                    Button(drawing ? "Read" : "Hide Ink", systemImage: drawing ? "book" : "eye.slash") {
                        Task { await changeMode(drawing ? .visible : .hidden) }
                    }
                } else if canUseLayer {
                    Button("Show Ink", systemImage: "eye") { Task { await changeMode(.visible) } }
                }
                if !drawing {
                    Button("Draw", systemImage: "pencil.tip") { Task { await changeMode(.draw) } }
                        .disabled(annotations.planScope != scope || (annotations.group != nil && !canUseLayer))
                        .accessibilityIdentifier("plans.draw")
                }
            }
            .buttonStyle(CollectionSecondaryButtonStyle())
            .disabled(changingMode)
            .padding(.horizontal, 16)
            if annotations.failed {
                Button("Retry saving ink") { Task { _ = await annotations.prepareForNavigation() } }
                    .font(.footnote)
            }
            if showingInk {
                AnnotationSurface(document: document, preferences: reader.preferences, reader: reader,
                    session: annotations,
                    stateToken: "\(annotations.mode)|\(annotations.toolsVisible)|\(annotations.saving)",
                    planFocusVerses: focus, isPlanSurface: true)
                    .id(annotations.reopenGeneration)
            } else {
                ReaderTextSurface(document: document, preferences: reader.preferences,
                    targetVerse: reader.targetVerse, navigationID: reader.navigationID,
                    restorationLocation: reader.restorationLocation, onVerse: { _ in },
                    onVisibleLocation: reader.visibleLocation, onChapterSwipe: { _ in },
                    authorizeQuote: reader.authorizeQuote, planFocusVerses: focus,
                    emphasisVerses: reader.emphasisVerses)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = min(max($0, 320), 960) }
        .frame(maxWidth: 960).frame(maxWidth: .infinity)
    }

    private func changeMode(_ mode: AnnotationSession.Mode) async {
        guard !changingMode, annotations.planScope == scope else { return }
        changingMode = true
        defer { changingMode = false }
        if annotations.group == nil, mode == .draw {
            await annotations.createPlanLayer(document: document, preferences: reader.preferences, width: width, name: layerName)
        } else if await annotations.prepareForNavigation(), canUseLayer {
            annotations.mode = mode
            annotations.toolsVisible = mode == .draw
        }
    }
}

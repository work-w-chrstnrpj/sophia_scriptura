import SwiftUI

struct CanvasExperimentView: View {
    @StateObject private var session = CanvasExperimentSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingText = false
    @State private var draft = ""

    private var controlsDisabled: Bool { session.busy || session.interacting || editingText }

    var body: some View {
        Group {
            if session.document != nil {
                VStack(spacing: 0) {
                    controls
                    CanvasExperimentSurface(session: session)
                        .accessibilityIdentifier("canvas.surface")
                    objectControls
                    Text(session.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("canvas.status")
                }
            } else if let error = session.loadError {
                ContentUnavailableView {
                    Label("Sample unavailable", systemImage: "exclamationmark.triangle")
                } description: { Text(error) } actions: {
                    Button("Retry") { Task { await session.open() } }
                }
            } else { ProgressView("Opening canvas sample…") }
        }
        .navigationTitle("Canvas experiment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await session.open()
            #if DEBUG
            if CanvasMemoryProbe.isEnabled { await CanvasMemoryProbe().run(session) }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.flushInk?()
                Task { await session.saveNow() }
            }
        }
        .onDisappear {
            session.flushInk?()
            Task { await session.saveNow() }
        }
        .sheet(isPresented: $editingText) { textEditor }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack { modePicker; Spacer(); historyButtons; zoomButtons }
                VStack(alignment: .leading) {
                    modePicker
                    HStack { historyButtons; Spacer(); zoomButtons }
                }
            }
            if session.mode == .draw {
                HStack {
                    Text("Finger drawing")
                    Spacer()
                    Toggle(isOn: $session.fingerDrawing) { Text("Finger drawing") }
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("Finger drawing")
                    Toggle("Eraser", isOn: $session.erasing)
                        .toggleStyle(.button)
                }
                Text(session.fingerDrawing ? "Draw with a finger or Pencil; use two fingers to pan." : "Draw with Apple Pencil; use a finger to pan.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Ink area: 1,100 × 800 pt. This experiment moves all handwriting as one object.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .disabled(controlsDisabled)
    }

    private var modePicker: some View {
        Picker("Canvas mode", selection: $session.mode) {
            ForEach(CanvasExperimentSession.Mode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }

    private var historyButtons: some View {
        HStack {
            Button { session.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .accessibilityLabel("Undo document edit")
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!session.canUndo)
            Button { session.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .accessibilityLabel("Redo document edit")
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!session.canRedo)
        }
        .buttonStyle(.bordered)
    }

    private var zoomButtons: some View {
        HStack(spacing: 6) {
            Button { session.changeZoom(session.zoom - 0.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .accessibilityLabel("Zoom out")
            Text(session.zoom, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit().font(.footnote).frame(minWidth: 38)
            Button { session.changeZoom(session.zoom + 0.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .accessibilityLabel("Zoom in")
            Button("Return") { session.focus() }.accessibilityLabel("Return to study")
        }
        .buttonStyle(.bordered)
    }

    private var objectControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack { objectButtons; Spacer(); persistenceMenu }
                VStack(alignment: .leading) { objectButtons; persistenceMenu }
            }
            ViewThatFits(in: .horizontal) {
                HStack { editButtons; Spacer(); moveButtons }
                VStack(alignment: .leading) { editButtons; moveButtons }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
        .disabled(controlsDisabled)
    }

    private var objectButtons: some View {
        HStack {
            ForEach(CanvasFixture.ObjectID.allCases) { object in
                Button {
                    session.select(object, add: true)
                    if session.selection.contains(object) { session.focus(object) }
                } label: {
                    Label(object.title, systemImage: session.selection.contains(object) ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.bordered)
                .accessibilityAddTraits(session.selection.contains(object) ? .isSelected : [])
                .accessibilityIdentifier("canvas.select.\(object.rawValue)")
                .contextMenu { Button("Show \(object.title)") { session.focus(object) } }
            }
        }
    }

    private var editButtons: some View {
        HStack {
            Button("Group") { session.group() }.disabled(session.selection.count < 2)
                .accessibilityIdentifier("canvas.group")
            Button("Ungroup") { session.ungroup() }
                .disabled(!(session.document?.objects.contains { session.selection.contains($0.id) && $0.group != nil } ?? false))
            Button("Edit text") {
                draft = session.document?.text ?? ""
                editingText = true
            }.disabled(!session.selection.contains(.text))
        }.buttonStyle(.bordered)
    }

    private var moveButtons: some View {
        HStack {
            nudge("arrow.left", "Move selected objects left", CGSize(width: -20, height: 0))
            nudge("arrow.up", "Move selected objects up", CGSize(width: 0, height: -20))
            nudge("arrow.down", "Move selected objects down", CGSize(width: 0, height: 20))
            nudge("arrow.right", "Move selected objects right", CGSize(width: 20, height: 0))
        }.disabled(session.selection.isEmpty).buttonStyle(.bordered)
    }

    private func nudge(_ symbol: String, _ label: String, _ delta: CGSize) -> some View {
        Button { session.nudge(delta) } label: { Image(systemName: symbol) }
            .accessibilityLabel(label)
    }

    private var persistenceMenu: some View {
        Menu {
            Button("Save now") { session.flushInk?(); Task { await session.saveNow() } }
            Button("Save and reopen") { Task { await session.saveAndReopen() } }
            Button("Check damaged restore") { Task { await session.testDamagedRestore() } }
        } label: { Label("Sample", systemImage: "externaldrive") }
            .accessibilityIdentifier("canvas.sample")
    }

    private var textEditor: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Existing handwriting keeps its position when text wraps differently.")
                    .font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $draft)
                    .accessibilityLabel("Observation text")
                    .onChange(of: draft) { _, value in if value.count > 500 { draft = String(value.prefix(500)) } }
                Text("\(draft.count)/500 characters").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Edit observation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingText = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { session.updateText(draft); editingText = false }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

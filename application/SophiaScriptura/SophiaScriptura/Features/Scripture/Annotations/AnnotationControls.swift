import SwiftUI
import UniformTypeIdentifiers

private struct AnnotationEyeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.45))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.45))
        return path
    }
}

private struct AnnotationEyeSymbol: View {
    let filledPupil: Bool
    var body: some View {
        ZStack {
            AnnotationEyeOutline().stroke(.primary, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            Circle()
                .fill(filledPupil ? Color.primary : Color.clear)
                .overlay(Circle().stroke(.primary, lineWidth: filledPupil ? 0 : 1.7))
                .frame(width: 6, height: 6)
        }
        .frame(width: 21, height: 14)
        .frame(width: 24, height: 24)
    }
}

struct AnnotationArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents, bytes.count <= AnnotationFileRepository.archiveLimit else { throw AnnotationError.tooLarge }
        data = bytes
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct AnnotationControls: View {
    @Environment(\.appTheme) private var theme
    @Bindable var annotations: AnnotationSession
    let reader: ReaderSession
    let width: Double
    @Binding var confirmDeleteLayer: Bool
    var openChapterHub: (() -> Void)? = nil
    @State private var rename = false
    @State private var name = ""
    @State private var showLayers = false
    @State private var showModes = false
    @State private var showDeleted = false
    @State private var exported: AnnotationArchiveDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var replacement: Data?
    @State private var confirmRestore = false
    var body: some View {
        VStack(spacing: 4) {
            ViewThatFits(in: .horizontal) {
                toolbar(compact: false)
                toolbar(compact: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .disabled(annotations.usingTool || annotations.saving)
            if annotations.failed {
                Button(annotations.loaded ? "Retry save" : "Retry opening") {
                    Task { if annotations.loaded { await annotations.save() } else { await annotations.open(reader.document) } }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
            }
        }
        .alert("Rename layer", isPresented: $rename) {
            TextField("Name", text: $name)
            Button("Save") { Task { await annotations.rename(name) } }; Button("Cancel", role: .cancel) { }
        }
        .fileExporter(isPresented: $exporting, document: exported, contentType: .json, defaultFilename: "Sophia-annotations") { result in
            if case .failure(let error) = result { annotations.report(error) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= AnnotationFileRepository.archiveLimit else { throw AnnotationError.tooLarge }
                replacement = try Data(contentsOf: url); confirmRestore = true
            } catch { annotations.report(error) }
        }
        .alert("Replace annotations from backup?", isPresented: $confirmRestore) {
            Button("Replace annotations", role: .destructive) {
                guard let data = replacement else { return }; replacement = nil
                Task {
                    await annotations.restore(data, document: reader.document)
                    annotations.restoreSelectedAppearance(reader: reader)
                }
            }
            Button("Cancel", role: .cancel) { replacement = nil }
        } message: { Text("This replaces all Scripture annotations, including deleted layers. A recovery copy is retained. This is an ink-only backup; Bible text and other app data are excluded.") }
    }
    private func controlLabel(_ title: String, icon: String, compact: Bool) -> some View {
        Group {
            if compact { Image(systemName: icon).accessibilityLabel(title) }
            else { Label(title, systemImage: icon).lineLimit(1) }
        }.frame(minWidth: 44, minHeight: 44)
    }
    private func appearanceLabel(_ choice: AnnotationSession.LayerChoice) -> String {
        let preset = choice.layer.appearance?.presetID.flatMap(ScriptureAppearance.init(rawValue:))
        let name = preset?.title ?? (choice.layer.appearance?.typeface == "Georgia" ? ScriptureAppearance.oldPaper.title : nil)
            ?? choice.layer.appearance?.typeface ?? choice.layout.fontName
        return "\(name), \(Int(choice.layout.fontSize.rounded())) pt"
    }
    private func layerActionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }
    @ViewBuilder private func modeSymbol(_ mode: AnnotationSession.Mode) -> some View {
        switch mode {
        case .visible: AnnotationEyeSymbol(filledPupil: true)
        case .hidden: AnnotationEyeSymbol(filledPupil: false)
        case .draw: Image(systemName: "pencil.tip.crop.circle").frame(width: 24, height: 24)
        }
    }
    private func modeControlLabel(_ mode: AnnotationSession.Mode, compact: Bool) -> some View {
        HStack(spacing: 8) {
            modeSymbol(mode)
            if !compact { Text(mode.rawValue).lineLimit(1) }
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(mode.rawValue)
    }
    private var modePicker: some View {
        VStack(spacing: 4) {
            ForEach(AnnotationSession.Mode.allCases, id: \.self) { mode in
                Button {
                    showModes = false
                    Task { await annotations.applyMode(mode, reader: reader) }
                } label: {
                    HStack(spacing: 10) {
                        modeSymbol(mode)
                        Text(mode.rawValue)
                        Spacer(minLength: 8)
                        if annotations.mode == mode { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                    }
                    .frame(minHeight: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 230)
        .presentationCompactAdaptation(.popover)
    }
    private var layerPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Annotation layers").font(.headline).padding(.horizontal, 10)
                if let document = reader.document {
                    ForEach(annotations.layers(for: document)) { choice in
                        let selected = annotations.selected?.id == choice.id
                        Button {
                            showLayers = false
                            Task { await annotations.select(choice, document: document, reader: reader) }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(choice.layer.name)
                                        .fontWeight(selected ? .semibold : .regular)
                                        .foregroundStyle(selected ? Color.accentColor : Color.primary)
                                    Text(appearanceLabel(choice)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                            }
                            .padding(10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.layer.name)
                        .accessibilityValue(appearanceLabel(choice))
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manage layers").font(.caption).foregroundStyle(.secondary)
                        Button { showLayers = false; create() } label: {
                            layerActionLabel("New layer", icon: "plus.circle.fill")
                                .foregroundStyle(Color(theme.palette.paper))
                        }
                        .buttonStyle(.borderedProminent)
                        if annotations.selected != nil {
                            Button { showLayers = false; name = ""; rename = true } label: {
                                layerActionLabel("Rename layer", icon: "pencil")
                            }
                            .buttonStyle(.bordered)
                            Button(role: .destructive) { showLayers = false; confirmDeleteLayer = true } label: {
                                layerActionLabel("Delete layer", icon: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                    let deleted = annotations.deletedLayers(for: document)
                    if !deleted.isEmpty {
                        Button("Recently Deleted") { showDeleted.toggle() }
                        if showDeleted {
                            ForEach(deleted) { choice in
                                Button("Restore \(choice.layer.name)") {
                                    showLayers = false
                                    Task {
                                        await annotations.restoreLayer(choice.id, document: document)
                                        annotations.restoreSelectedAppearance(reader: reader)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(width: 340, height: min(520, CGFloat(260 + (reader.document.map { annotations.layers(for: $0).count } ?? 0) * 66)))
        .presentationCompactAdaptation(.popover)
    }
    private func toolbar(compact: Bool) -> some View {
        HStack(spacing: compact ? 12 : 16) {
                    Button { showLayers = true } label: {
                        controlLabel(annotations.selected?.name ?? "Annotations", icon: "square.3.layers.3d", compact: compact)
                    }
                    .popover(isPresented: $showLayers, arrowEdge: .top) { layerPicker }
                    .accessibilityIdentifier("annotation.layers").disabled(!annotations.loaded)

                    if annotations.group != nil {
                        Button { showModes = true } label: { modeControlLabel(annotations.mode, compact: compact) }
                        .popover(isPresented: $showModes, arrowEdge: .top) { modePicker }
                        .accessibilityIdentifier("annotation.mode")
                        .accessibilityLabel(annotations.mode.rawValue)
                        if annotations.mode != .hidden {
                        Button {
                            annotations.marginExpanded.toggle()
                        } label: { controlLabel("Margin", icon: annotations.marginExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", compact: compact) }
                        .accessibilityIdentifier("annotation.margin")
                        .accessibilityValue(annotations.marginExpanded ? "On" : "Off")
                        }
                    }
                    Menu {
                        if annotations.selected != nil {
                            Button("Undo ink", systemImage: "arrow.uturn.backward") { annotations.undo?() }
                            Button("Redo ink", systemImage: "arrow.uturn.forward") { annotations.redo?() }
                            Button("Clear ink", role: .destructive) { annotations.clear?() }
                                .disabled(annotations.mode == .hidden)
                            Divider()
                        }
                        Button("Export annotation backup") {
                            Task {
                                do { exported = AnnotationArchiveDocument(data: try await annotations.export()); exporting = true }
                                catch { annotations.report(error) }
                            }
                        }
                        Button("Restore annotation backup…") { importing = true }
                        Button("Recover annotations from before last restore…") {
                            Task {
                                do { replacement = try await annotations.preRestoreArchive(); confirmRestore = true }
                                catch { annotations.report(error) }
                            }
                        }
                    } label: { controlLabel("Actions", icon: "ellipsis.circle", compact: compact) }
                    .accessibilityIdentifier("annotation.backup")

                    if let openChapterHub {
                        Button(action: openChapterHub) {
                            Label("Chapter", systemImage: "rectangle.stack")
                                .lineLimit(1).frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityIdentifier("scripture.chapterHub")
                        .accessibilityLabel("Chapter hub")
                    }

        }.buttonStyle(.borderless).font(.subheadline)
    }
    private func create() {
        guard let document = reader.document else { return }
        Task { await annotations.create(document: document, preferences: reader.preferences, width: width) }
    }
}

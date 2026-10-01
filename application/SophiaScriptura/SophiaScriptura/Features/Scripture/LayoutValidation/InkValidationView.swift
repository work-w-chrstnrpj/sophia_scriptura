#if DEBUG
import SwiftUI

struct InkValidationView: View {
    @StateObject private var session = InkValidationSession()
    @State private var document: ChapterDocument?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 8) {
            Text("SP-008 · Pencil geometry experiment").font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack { modeControls; actionControls }
                VStack { modeControls; actionControls }
            }.disabled(session.usingTool)
            ScrollView(.horizontal) {
                HStack {
                    Toggle("Margin rules", isOn: $session.rules)
                    Toggle("Narrow viewport", isOn: $session.narrow)
                    Toggle("Larger reading view", isOn: $session.reading)
                    Toggle("Unavailable background", isOn: $session.unavailable)
                }.toggleStyle(.button)
            }.disabled(session.usingTool)
            Text(session.notice).font(.caption).accessibilityIdentifier("sp008.status")
            if let document {
                if session.reading {
                    ScrollView {
                        Text("Reading layout — annotations remain in original layout").font(.headline)
                        Text(ChapterTextMap(document: document).text).font(.system(size: 32)).textSelection(.enabled)
                    }.padding()
                } else {
                    HStack(spacing: 0) {
                        InkValidationSurface(session: session, document: document)
                        if session.narrow { Color.secondary.opacity(0.12).frame(width: 220).overlay(Text("Panel fixture")) }
                    }
                }
            } else { Text(error ?? "Loading bundled WEB…") }
        }.padding(8)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                do { document = try await BundledScriptureRepository().chapter(book: "JHN", number: 3) }
                catch { self.error = "Bundled chapter unavailable." }
            }
    }
    private var modeControls: some View {
        HStack {
            Picker("Mode", selection: $session.mode) {
                ForEach(InkValidationSession.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).frame(maxWidth: 300)
            Picker("Layer", selection: $session.layer) { Text("Study 1").tag(0); Text("Study 2").tag(1) }
        }
    }
    private var actionControls: some View {
        HStack {
            Button("Undo") { session.undo?() }
            Button("Redo") { session.redo?() }
            Button("Save") { session.save() }
            Button("Reopen") { session.reopen() }
        }.buttonStyle(.bordered)
    }
}
#endif

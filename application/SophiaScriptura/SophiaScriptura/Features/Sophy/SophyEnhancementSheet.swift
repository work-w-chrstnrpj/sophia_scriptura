import SwiftUI

struct SophyEnhancementSheet: View {
    @ObservedObject var sophy: SophySession
    @ObservedObject var companion: CompanionSession
    var notes: NotesSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tones = [("casual", "Casual / Personal"), ("professional", "Professional / Formal"), ("creative", "Creative / Poetic"), ("academic", "Academic"), ("devotional", "Devotional")]
    var body: some View {
        NavigationStack {
            Form {
                Section("Original text") {
                    if let selection = sophy.enhancementSelection { Text(selection.text).textSelection(.enabled) }
                    else { TextField("Paste or type text to enhance", text: $sophy.enhancementText, axis: .vertical).lineLimit(4...12) }
                }
                Section("Enhance with Sophy") {
                    Picker("Operation", selection: $sophy.enhancementOperation) { ForEach(SophyEnhancementOperation.allCases) { Text($0.title).tag($0) } }.accessibilityIdentifier("sophy.enhance.operation")
                    if sophy.enhancementOperation == .tone {
                        Picker("Tone", selection: $sophy.enhancementTone) { ForEach(tones, id: \.0) { Text($0.1).tag($0.0) } }.accessibilityIdentifier("sophy.enhance.tone")
                    }
                    if sophy.enhancementOperation == .rate {
                        Picker("Rate", selection: $sophy.enhancementRating) { Text("Grammar").tag("grammar"); Text("Idea").tag("idea"); Text("Both").tag("both") }.accessibilityIdentifier("sophy.enhance.rating")
                    }
                    Text(sophy.routeLabel == "Choose a provider in Settings"
                        ? "Choose a provider and model in Settings before sending text."
                        : "Sends only this text to \(sophy.routeLabel). Your surrounding note and other study material are excluded.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if sophy.enhancementSelection?.requiresConsent == true {
                        Toggle("I consent to sending this protected selection for this request", isOn: $sophy.enhancementConsent)
                    }
                    Button(sophy.enhancement == nil ? "Generate suggestion" : "Generate again") {
                        Task { await sophy.generateEnhancement(companion: companion, notes: notes) }
                    }.disabled(sophy.isWorking || sophy.enhancementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (sophy.enhancementSelection?.requiresConsent == true && !sophy.enhancementConsent))
                }.disabled(sophy.isWorking)
                if sophy.phase == .enhancing { ProgressView("Reviewing your writing…") }
                if let review = sophy.enhancement {
                    Section(review.isRating ? "Feedback" : "Suggested text") {
                        if !review.isRating { Text(review.replacement).textSelection(.enabled) }
                        Text(review.feedback).textSelection(.enabled)
                        if let grammar = review.scores?.grammar { LabeledContent("Grammar", value: String(format: "%.1f / 10", grammar)) }
                        if let idea = review.scores?.idea { LabeledContent("Idea", value: String(format: "%.1f / 10", idea)) }
                        Button(review.isRating ? "Copy feedback" : "Copy suggestion") { sophy.copyEnhancement(notes: notes) }
                        if !review.isRating, review.selection != nil {
                            Button("Replace selection") { sophy.applyEnhancement(notes: notes) }
                                .accessibilityIdentifier("sophy.enhance.replace")
                        }
                    }
                }
                if let notice = sophy.notice { Section { Text(notice).font(.callout).foregroundStyle(.secondary) } }
            }
            .navigationTitle("Enhance with Sophy").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") {
                if sophy.isWorking { sophy.cancel() } else { sophy.dismissEnhancement() }
            } } }
            .onChange(of: sophy.enhancementOperation) { _, _ in invalidate() }
            .onChange(of: sophy.enhancementTone) { _, _ in invalidate() }
            .onChange(of: sophy.enhancementRating) { _, _ in invalidate() }
            .onChange(of: sophy.enhancementText) { _, _ in invalidate() }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: sophy.enhancement != nil)

        }
    }
    private func invalidate() { sophy.enhancement = nil; sophy.enhancementConsent = false }
}

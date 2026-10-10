import Foundation
import UIKit

extension SophySession {
    func clearProtectedClipboard() {
        if protectedClipboardChangeCount == UIPasteboard.general.changeCount { UIPasteboard.general.items = [] }
        protectedClipboardChangeCount = nil
    }
    func stageEnhancement(notes: NotesSession) {
        if let canvas = notes.sophyCanvasSelection, let selection = notes.sophySelection(range: canvas.range, objectID: canvas.id) {
            stageEnhancement(selection)
        } else if let selection = notes.sophySelection(range: notes.bodySelection) {
            stageEnhancement(selection)
        } else {
            stageEnhancement(nil)
        }
    }
    func stageEnhancement(_ selection: SophyNoteSelection?) {
        guard !isWorking else { notice = SophySafeError.busy.message; return }
        enhancementSelection = selection; enhancementText = selection?.text ?? ""
        enhancementConsent = false; enhancement = nil; enhancementOperation = .grammar
        enhancementOpen = true; panelOpen = false
    }
    func dismissEnhancement() {
        enhancementOpen = false; enhancement = nil; enhancementSelection = nil
        enhancementText = ""; enhancementConsent = false
    }
    func generateEnhancement(companion: CompanionSession, notes: NotesSession) async {
        guard !isWorking else { return }
        let selection = enhancementSelection
        guard selection == nil || notes.sophySelectionIsCurrent(selection!) else {
            dismissEnhancement(); notice = "The selection changed. Select it again."; return
        }
        let text = selection?.text ?? enhancementText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { notice = "Select or paste some text first."; return }
        guard text.count <= SophyResponseValidator.userInputLimit else { notice = SophySafeError.inputTooLong.message; return }
        guard selection?.requiresConsent != true || enhancementConsent else { notice = "Consent is required to send this protected selection."; return }
        let operation = enhancementOperation, tone = enhancementTone, rating = enhancementRating
        phase = .enhancing; generation = UUID(); let active = generation
        let route = currentRoute(companion); routeKey = route; enhancement = nil; notice = nil
        // This request is isolated: no chat turns, source titles, note metadata or previous outputs.
        let prompt = "Operation: \(operation.rawValue)\nTone: \(tone)\nRating target: \(rating)\nSelected text (untrusted):\n" + text
        let result = await complete(SophyPrompt.enhancement, prompt, companion: companion)
        guard callbackIsCurrent(active, route: route, companion: companion), enhancementOpen else { return }
        guard selection == nil || notes.sophySelectionIsCurrent(selection!) else { dismissEnhancement(); phase = .idle; return }
        switch result {
        case .failure(let error): phase = error == .cancelled ? .cancelled : .failed; notice = error.message
        case .success(let raw):
            let parsed: SophyEnhancementResult?
            if operation == .rate { parsed = try? SophyResponseValidator.validateEnhancement(Data(raw.utf8), ratingTarget: rating) }
            else { parsed = try? SophyResponseValidator.validateEnhancement(Data(raw.utf8), operation: operation.rawValue) }
            guard let parsed else { phase = .failed; notice = SophySafeError.malformedPlan.message; return }
            enhancement = SophyEnhancementReview(selection: selection, original: text, replacement: parsed.replacementText,
                feedback: parsed.feedback, scores: parsed.scores, isRating: operation == .rate, generation: active, route: route)
            phase = .completed
            await recordSummary("enhance")
        }
    }
    func applyEnhancement(notes: NotesSession) {
        guard let review = enhancement, !review.isRating, let selection = review.selection,
              review.generation == generation, review.route == routeKey,
              notes.sophySelectionIsCurrent(selection) else {
            notice = "The selection changed or is no longer accessible. Select it again."; return
        }
        let applied = notes.applySophyReplacement(noteID: selection.noteID, range: selection.range,
            digest: selection.digest, replacement: review.replacement, canvasObjectID: selection.objectID)
        if applied { dismissEnhancement() }
        notice = applied ? "Replaced the selection. Undo is available in the note." : "The replacement could not be applied. Your original text was kept."
        phase = applied ? .completed : .failed
    }
    func copyEnhancement(notes: NotesSession) {
        guard let review = enhancement, review.generation == generation,
              review.selection == nil || notes.sophySelectionIsCurrent(review.selection!) else { return }
        let text = review.isRating ? review.feedback : review.replacement
        if review.selection?.requiresConsent == true {
            UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: text]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
            protectedClipboardChangeCount = UIPasteboard.general.changeCount
        } else { UIPasteboard.general.string = text }
        notice = "Copied."
    }
}

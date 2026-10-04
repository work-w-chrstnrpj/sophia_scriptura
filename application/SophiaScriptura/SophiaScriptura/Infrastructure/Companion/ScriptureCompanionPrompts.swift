import Foundation

enum ScriptureCompanionPrompts {
    enum AnalysisMode: Equatable {
        case word, phrase, referenceOnly

        var label: String {
            switch self {
            case .word: return "Word study"
            case .phrase: return "Phrase analysis"
            case .referenceOnly: return "Reference only"
            }
        }
    }

    /// Classifies the selected translation wording, not its eventual original-language mapping.
    /// Apostrophes and hyphens inside a whitespace-delimited word remain part of that word.
    static func analysisMode(selectedText: String?) -> AnalysisMode {
        let words = (selectedText ?? "").split(whereSeparator: \.isWhitespace)
            .filter { $0.contains { $0.isLetter || $0.isNumber } }
        if words.isEmpty { return .referenceOnly }
        return words.count == 1 ? .word : .phrase
    }

    static func originalLanguageAnalysis(
        referenceLabel: String,
        bookID: String,
        transmittedText: String?,
        translationName: String? = nil,
        verseContextText: String? = nil
    ) -> String {
        let mode = analysisMode(selectedText: transmittedText)
        let translation = translationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let translationNote = translation.flatMap { $0.isEmpty ? nil : $0 }
            .map { "This passage uses the \($0) translation." }
            ?? "The translation name was not supplied; do not assume a translation."
        let languageNote = originalLanguageNote(bookID: bookID, referenceLabel: referenceLabel)
        guard mode != .referenceOnly, let transmittedText else {
            return """
            Original Language Analysis of \(referenceLabel).
            \(languageNote)
            \(translationNote)

            The selected wording and verse text are not available for transmission. Explain that a focused word or phrase analysis requires the selected wording and permitted passage context. Do not guess the selection, reconstruct restricted translation text, or invent original-language wording.
            """
        }

        let selectedKind = mode == .word ? "word" : "words"
        var prompt = """
        I selected the \(selectedKind) below from \(referenceLabel).
        Analyze the selected wording in this passage's original language and its context.
        \(translationNote)
        \(languageNote)
        Analysis mode: \(mode.label).

        Selected wording (the analysis target, not the complete verse):
        \(quote(transmittedText.trimmingCharacters(in: .whitespacesAndNewlines)))

        The translation is for orientation only, not the original-language text. Focus on my selection; use the involved verse(s) and surrounding literary and historical context to explain the intended meaning.

        Perform the analysis directly. Do not merely describe what each section will cover, repeat these instructions, or offer unrelated vocabulary. Keep the exact book and reference \(referenceLabel); do not switch to a different book or chapter.
        """
        switch mode {
        case .word:
            prompt += """



            Word-study approach:
            - Identify the original word or expression corresponding to the selected translated word in this exact verse. Give the attested form, lemma, script, transliteration and relevant grammatical role.
            - Explain the relevant possible senses in plain language, then identify which sense fits this sentence and passage and why. Do not import every possible meaning into this occurrence.
            - Compare a few representative biblical occurrences of the same original-language lemma, with exact references and a brief explanation of each usage. Prefer the same author/book where helpful. Compare the underlying original word, not merely verses with the same English word; distinguish different lemmas, languages and related roots.
            - Explain differences between those occurrences and return to the meaning here. Do not claim the examples cover every occurrence throughout the Bible.
            - A single translated word can correspond to several original words; disclose this rather than forcing a one-to-one mapping.

            Use Markdown sections:
            ## Original wording
            ## Possible meanings
            ## Biblical usage
            ## Meaning in context
            ## Translation observations
            """
        case .phrase:
            prompt += """



            Phrase-analysis approach:
            - Identify the original wording corresponding to the selected phrase or sentence, with script and transliteration. Explain translation-to-original alignment, noting where several translated words represent one original word or the word order differs.
            - Explain relevant key words, grammatical relationships, syntax and idioms together. Do not mechanically reverse-translate English or treat each word's dictionary meanings as the phrase's intended meaning.
            - Explain the phrase in its sentence and passage context, including the author's argument, genre and relevant historical setting. Connect each observation to the selected phrase rather than supplying a generic chapter overview.
            - Where useful, cite comparable constructions or usages, distinguishing comparison from evidence for the meaning here.

            Use Markdown sections:
            ## Original wording
            ## Key words and grammar
            ## Literary and historical context
            ## Meaning in context
            ## Translation observations
            """
        case .referenceOnly: break
        }
        prompt += """



        Reliability and interpretation:
        - Distinguish textual facts, lexical possibilities and interpretive conclusions. Avoid root-only interpretations and reading later associations into an occurrence.
        - Verify that original-language forms, lemmas and cross-references actually match the selected passage. If you cannot verify them, explicitly disclose uncertainty; do not invent wording, meanings, occurrence counts, Strong's numbers, lexicon entries or citations.
        - Model recollection is not verified lexical evidence. Never claim a lexicon, concordance or original text was consulted unless it was actually accessed. Name genuinely used sources in the Sophia bibliography appendix; otherwise disclose that this is an unverified AI-assisted study.
        - Do not paste translated sentences into the original-wording section as if they were original-language text.
        """
        if let verseContextText, !verseContextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += "\n\nAttached verse(s) — \(referenceLabel):\n\(quote(verseContextText))"
        } else {
            prompt += "\n\nFull verse text was not attached. Do not treat the selected fragment as the complete verse or invent the missing translation wording; disclose the missing context."
        }
        return prompt
    }

    static func originalLanguageDisplayCard(
        referenceLabel: String,
        transmittedText: String?,
        translationName: String? = nil
    ) -> String {
        let mode = analysisMode(selectedText: transmittedText)
        let translation = translationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = translation.flatMap { $0.isEmpty ? nil : $0 }.map { " (\($0))" } ?? ""
        let heading = "**Original Language Analysis — \(mode.label):**"
        guard mode != .referenceOnly, let transmittedText else {
            return "\(heading)\n\nSelected wording is unavailable for transmission.\n\n*\(referenceLabel)\(version)*"
        }
        let kind = mode == .word ? "word" : "words"
        return """
        \(heading)

        I selected the \(kind) below. Analyze \(mode == .word ? "it" : "them") in the passage's original language and context.

        \(quote(transmittedText.trimmingCharacters(in: .whitespacesAndNewlines)))

        *\(referenceLabel)\(version)*
        """
    }

    private static func quote(_ text: String) -> String {
        text.components(separatedBy: .newlines).map { "> " + $0 }.joined(separator: "\n")
    }

    private static func originalLanguageNote(bookID: String, referenceLabel: String) -> String {
        let book = bookID.uppercased()
        let ntBooks = Set(["MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV"])
        if ntBooks.contains(book) {
            return "Original language: Koine Greek (New Testament passage \(referenceLabel))."
        }
        if book == "DAN" || book == "EZR" {
            return "Original language: Biblical Hebrew or Aramaic. This book contains both; identify which applies to the precise cited verses rather than treating the entire book as one language."
        }
        return "Original language: Biblical Hebrew (Old Testament \(referenceLabel)); identify any attested Aramaic expression where relevant."
    }
}

import Foundation

enum ScriptureCompanionPrompts {
    static func originalLanguageAnalysis(referenceLabel: String, bookID: String, transmittedText: String?) -> String {
        let languageNote = originalLanguageNote(bookID: bookID, referenceLabel: referenceLabel)
        var prompt = """
        \(languageNote)

        Analyze the selected wording in \(referenceLabel). The English below is a modern translation for orientation only—not the original language text.

        Use Markdown with these sections (headings exactly as written):
        ## Original wording
        ## Key words and grammar
        ## Literary and historical context
        ## Meaning in context
        ## Translation observations

        Rules for ## Original wording:
        - Present lemmas or phrases in Hebrew/Aramaic or Greek script plus standard transliteration in parentheses.
        - Do not paste English translation sentences into this section as if they were Greek or Hebrew.
        - Do not invent lexicon footnote numbers or parenthetical citations like ("Ethics" footnote 1119); put real works only in the Sophia bibliography appendix.

        Include plain-language explanation in the other sections. Evaluate each word in its sentence and passage context; do not derive meaning from roots alone or list every possible dictionary gloss. Clearly distinguish textual facts from interpretive conclusions.
        """
        if let transmittedText {
            prompt += "\n\nSelected English translation (for context only):\n> \(transmittedText)"
        }
        return prompt
    }

    static func originalLanguageDisplayCard(referenceLabel: String, transmittedText: String?) -> String {
        let excerpt = transmittedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if excerpt.isEmpty {
            return "**Original Language Analysis:**\n\n*\(referenceLabel)*"
        }
        return "**Original Language Analysis:**\n\n\(excerpt)\n\n*\(referenceLabel)*"
    }

    private static func originalLanguageNote(bookID: String, referenceLabel: String) -> String {
        let book = bookID.uppercased()
        let ntBooks = Set(["MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL", "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN", "JUD", "REV"])
        if ntBooks.contains(book) {
            return "Original language: Koine Greek (New Testament passage \(referenceLabel))."
        }
        if book == "DAN" {
            return "Original language: Biblical Hebrew or Aramaic in Daniel (Aramaic in chapters 2–7)—never Koine Greek for this book."
        }
        if book == "EZR" {
            return "Original language: mostly Biblical Hebrew; Aramaic in Ezra 4:8–6:18 and 7:12–26."
        }
        return "Original language: Biblical Hebrew (Old Testament \(referenceLabel))."
    }
}

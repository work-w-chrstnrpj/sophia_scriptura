import Foundation

enum CompanionResponseFormatting {
    /// Marker the model must place at the very end; stripped before display and parsed into Sources.
    static let sourcesAppendixHeading = "### Sophia bibliography (app only)"
    static let sourcesAppendixInstruction = """
    Bibliography appendix (required for every reply):
    After the full study answer, append a final section headed exactly:
    \(sourcesAppendixHeading)
    List real reference works only (lexicons, commentaries, Bible dictionaries, primary texts)—never invented footnote numbers or placeholder citations like "footnote 1119".
    Each line is one bullet in this pipe format (URL may be `none`):
    - Title | Author or publisher | https://example.org or none | One-sentence claim
    The app removes this entire section from the visible answer and shows it under Sources. Do not refer to this appendix in the body of your reply.
    """

    struct ParsedAssistantResponse: Equatable {
        var displayMarkdown: String
        var appendixSources: [CompanionSource]
    }

    /// A delta may split any Markdown delimiter, word, URL or code span.
    static func joinStreamDelta(existing: String, delta: String) -> String {
        existing + delta
    }

    static func finalizeAssistantMarkdown(_ markdown: String) -> String {
        splitSourcesAppendix(from: markdown).displayMarkdown
    }

    static func splitSourcesAppendix(from markdown: String) -> ParsedAssistantResponse {
        guard let range = markdown.range(of: sourcesAppendixHeading, options: [.backwards, .caseInsensitive]) else {
            return ParsedAssistantResponse(displayMarkdown: stripFabricatedInlineFootnotes(from: markdown), appendixSources: [])
        }
        let body = String(markdown[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let appendix = String(markdown[range.upperBound...])
        let parsed = parseAppendixLines(appendix)
        return ParsedAssistantResponse(
            displayMarkdown: stripFabricatedInlineFootnotes(from: body),
            appendixSources: parsed
        )
    }

    private static func parseAppendixLines(_ appendix: String) -> [CompanionSource] {
        var results: [CompanionSource] = []
        for line in appendix.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix("*") else { continue }
            let payload = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            let parts = payload.split(separator: "|", omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            guard let title = parts.first, !title.isEmpty else { continue }
            let author = parts.count > 1 ? parts[1] : nil
            let urlRaw = parts.count > 2 ? parts[2] : nil
            let claim = parts.count > 3 ? parts[3] : nil
            let url = normalizedURL(urlRaw)
            results.append(CompanionSource(
                title: title,
                authorOrPublisher: author?.isEmpty == true ? nil : author,
                url: url,
                retrievalProvider: "model-bibliography",
                claim: claim?.isEmpty == true ? nil : claim
            ))
        }
        return results
    }

    private static func normalizedURL(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        if lower == "none" || lower == "n/a" || lower == "-" { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return raw }
        return nil
    }

    /// Removes parenthetical hallucinated footnote tags from visible markdown.
    static func stripFabricatedInlineFootnotes(from markdown: String) -> String {
        let patterns = [
            #"\(\s*\"[^\"]+\"\s*footnote\s*\d+\s*\)"#,
            #"\(\s*see\s+[^)]*footnote\s*\d+[^)]*\)"#,
            #"\(\s*\"[^\"]+\"\s*\)\s*footnote\s*\d+"#
        ]
        var result = markdown
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }
}

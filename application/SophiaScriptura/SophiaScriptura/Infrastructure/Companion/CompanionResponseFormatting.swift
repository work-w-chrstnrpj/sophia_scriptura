import Foundation

enum CompanionResponseFormatting {
    /// Marker the model must place at the very end; stripped before display and parsed into Sources.
    static let sourcesAppendixHeading = "### Sophia bibliography (app only)"
    static let sourcesAppendixInstruction = """
    Sources: Never invent a reference or imply a source was consulted when it was not.
    If you actually cite an identifiable external work, append a final section headed exactly:
    \(sourcesAppendixHeading)
    Each bullet contains four fields separated by |: title, author or publisher, exact HTTP(S) URL (or none if unknown), and the specific claim it supports.
    Provide a real direct URL only when known; never guess a URL. Omit this section entirely when no external works are cited. Do not add sources just to fill a bibliography. Do not mention these formatting instructions in the answer.
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
            guard parts.count >= 4, let title = parts.first, !title.isEmpty,
                  !["none", "n/a", "no sources"].contains(title.lowercased()) else { continue }
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

    static func normalizedURL(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        if lower == "none" || lower == "n/a" || lower == "-" { return nil }
        let text = raw.trimmingCharacters(in: CharacterSet(charactersIn: "<>` "))
        if let match = text.range(of: #"\]\((https?://[^\s]+)\)$"#, options: .regularExpression) {
            let suffix = String(text[match]).dropFirst(2).dropLast()
            return validWebURL(String(suffix))?.absoluteString
        }
        return validWebURL(text)?.absoluteString
    }

    static func validWebURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, host.contains("."), url.user == nil, url.password == nil,
              !raw.contains(where: \.isWhitespace) else { return nil }
        return url
    }

    static func linkedSources(in markdown: String) -> [CompanionSource] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        var seen = Set<String>()
        return detector.matches(in: markdown, range: NSRange(markdown.startIndex..., in: markdown)).compactMap {
            guard let raw = $0.url?.absoluteString, let url = validWebURL(raw), seen.insert(raw).inserted else { return nil }
            return CompanionSource(title: url.host ?? "Linked reference", url: raw,
                                   retrievalProvider: "model-link", claim: "Link supplied in the answer; not independently verified.")
        }
    }

    /// Detects concrete template artifacts, not factual correctness or interpretive disagreement.
    static func containsDraftArtifacts(_ text: String) -> Bool {
        text.range(of: #"<\s*PRESIDIO_ANDROID|<div\s+class\s*=\s*["']verse["']|\[Question or engagement prompt"#,
                   options: [.regularExpression, .caseInsensitive]) != nil
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

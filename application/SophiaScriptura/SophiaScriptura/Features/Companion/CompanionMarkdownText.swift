import SwiftUI

/// Foundation parses the complete Markdown document. Presentation intents determine
/// block layout; inline attributes remain intact across emphasis and link runs.
struct CompanionMarkdownText: View {
    let content: String
    var ink: Color = .primary

    var body: some View {
        let segments = CompanionMarkdownTableParser.segments(from: content)
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let markdown):
                    proseBlocks(for: markdown)
                case .table(let table):
                    CompanionMarkdownTableView(table: table, ink: ink)
                }
            }
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func proseBlocks(for markdown: String) -> some View {
        ForEach(Self.blocks(for: markdown)) { block in
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                if let marker = block.marker {
                    Text(marker).monospacedDigit()
                }
                Text(block.text)
                    .font(block.font)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(block.isCode ? 10 : 0)
                    .background(
                        block.isCode ? ink.opacity(0.06) : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .padding(.leading, block.isQuote ? 13 : CGFloat(block.listDepth) * 12)
            .overlay(alignment: .leading) {
                if block.isQuote {
                    Rectangle().fill(ink.opacity(0.3)).frame(width: 3)
                }
            }
        }
    }

    struct Block: Identifiable {
        let id: Int
        var text: AttributedString
        var headingLevel: Int?
        var marker: String?
        var listDepth = 0
        var isQuote = false
        var isCode = false

        var font: Font {
            if isCode { return .system(.body, design: .monospaced) }
            switch headingLevel {
            case 1: return .system(.title2, design: .serif).weight(.semibold)
            case 2: return .system(.title3, design: .serif).weight(.semibold)
            case .some: return .system(.headline, design: .serif).weight(.semibold)
            case .none: return .body
            }
        }
    }

    static func blocks(for markdown: String) -> [Block] {
        guard !markdown.isEmpty else { return [] }
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full
        options.failurePolicy = .returnPartiallyParsedIfPossible
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return [Block(id: 0, text: AttributedString(markdown))]
        }

        var blocks: [Block] = []
        var markedListItems = Set<Int>()
        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let identity = components.first?.identity ?? 0
            var text = AttributedString(parsed[run.range])
            // SwiftUI handles inline attributes; this view supplies block layout.
            text.presentationIntent = nil
            if blocks.last?.id == identity {
                blocks[blocks.count - 1].text.append(text)
                continue
            }

            var block = Block(id: identity, text: text)
            var listItem: (identity: Int, ordinal: Int)?
            var ordered = false
            var listCount = 0
            for component in components {
                switch component.kind {
                case .header(let level): block.headingLevel = level
                case .listItem(let ordinal):
                    if listItem == nil { listItem = (component.identity, ordinal) }
                case .orderedList:
                    if listCount == 0 { ordered = true }
                    listCount += 1
                case .unorderedList: listCount += 1
                case .blockQuote: block.isQuote = true
                case .codeBlock: block.isCode = true
                default: break
                }
            }
            if let listItem {
                // A multi-paragraph list item receives its marker only once.
                if markedListItems.insert(listItem.identity).inserted {
                    block.marker = ordered ? "\(listItem.ordinal)." : "•"
                }
                block.listDepth = max(0, listCount - 1)
            }
            blocks.append(block)
        }
        return blocks
    }
}

private struct CompanionMarkdownTableView: View {
    let table: CompanionMarkdownTable
    var ink: Color

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            if !table.headers.isEmpty {
                GridRow {
                    ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                        cellText(header, weight: .semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(ink.opacity(0.16)).frame(height: 1)
                            }
                    }
                }
            }
            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                        cellText(value, weight: table.headers.isEmpty && rowIndex == 0 ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ink.opacity(0.12), lineWidth: 1)
        )
    }

    private func cellText(_ markdown: String, weight: Font.Weight) -> some View {
        Text(Self.inlineMarkdown(markdown))
            .font(.body.weight(weight))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func inlineMarkdown(_ markdown: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

/// Measures the message at the offered width, allowing short prompts to hug their text
/// while long prompts wrap within the panel and the readable-width ceiling.
struct CompanionMessageLayout: Layout {
    var maximumWidth: CGFloat = 560
    /// When true (e.g. markdown tables), the bubble may use the full offered chat width instead of the readable cap.
    var allowsWideExpansion: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let available = max(0, proposal.width ?? maximumWidth)
        let widthCap = allowsWideExpansion ? available : min(maximumWidth, available)
        let size = content.sizeThatFits(ProposedViewSize(width: widthCap, height: nil))
        if allowsWideExpansion {
            return CGSize(width: widthCap, height: size.height)
        }
        return CGSize(width: min(widthCap, size.width), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}

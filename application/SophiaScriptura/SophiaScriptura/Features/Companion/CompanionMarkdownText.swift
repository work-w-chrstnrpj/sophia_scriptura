import SwiftUI

/// Foundation parses the complete Markdown document. Presentation intents determine
/// block layout; inline attributes remain intact across emphasis and link runs.
struct CompanionMarkdownText: View {
    let content: String
    var ink: Color = .primary

    var body: some View {
        let blocks = Self.blocks(for: content)
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
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
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
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

/// Measures the message at the offered width, allowing short prompts to hug their text
/// while long prompts wrap within the panel and the readable-width ceiling.
struct CompanionMessageLayout: Layout {
    var maximumWidth: CGFloat = 560

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let width = min(maximumWidth, max(0, proposal.width ?? maximumWidth))
        let size = content.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: min(width, size.width), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}

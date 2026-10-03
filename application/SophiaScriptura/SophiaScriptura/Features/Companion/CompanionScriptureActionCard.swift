import SwiftUI

struct CompanionScriptureActionCard: View {
    let markdown: String
    let palette: ReaderPalette

    var body: some View {
        CompanionMarkdownText(content: markdown, ink: Color(palette.ink))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(palette.soft), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(palette.rule)))
    }
}

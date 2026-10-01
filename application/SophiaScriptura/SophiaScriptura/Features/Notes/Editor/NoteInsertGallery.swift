import SwiftUI

struct NoteInsertGallery: View {
    let session: NotesSession
    let kind: String
    let dismiss: () -> Void
    private let stickers = ["🌿", "🕊️", "✝️", "❤️", "⭐️", "☀️", "🌈", "🔥", "💡", "📖", "🙏", "✨", "🌱", "🌻", "🍇", "🪴", "✅", "❓", "❗️", "💭", "🎯", "🔖", "📌", "🎵"]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(kind).font(.headline); Spacer(); Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                if kind == "Shapes" {
                    ForEach(NoteShape.allCases, id: \.self) { shape in
                        Button { session.insert(.shape, shape: shape); dismiss() } label: {
                            Image(systemName: shape.symbol).resizable().scaledToFit().frame(width: 38, height: 38).frame(maxWidth: .infinity, minHeight: 56)
                        }.accessibilityLabel(shape.title).accessibilityIdentifier("notes.shape." + shape.rawValue)
                    }
                } else {
                    ForEach(stickers, id: \.self) { sticker in
                        Button { session.insert(.sticker, sticker: sticker); dismiss() } label: {
                            Text(sticker).font(.system(size: 36)).frame(maxWidth: .infinity, minHeight: 50)
                        }.accessibilityLabel("Sticker " + sticker)
                    }
                }
            }.buttonStyle(.plain)
        }.padding(20).frame(width: 330).fixedSize(horizontal: false, vertical: true)
    }
}

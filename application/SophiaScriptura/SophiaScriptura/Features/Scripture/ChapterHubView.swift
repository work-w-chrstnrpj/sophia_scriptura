import SwiftUI

/// Chapter-wide index over existing verse artifacts; it never copies or re-anchors them.
struct ChapterHubView: View {
    let chapter: CompanionChapterAnchor
    @ObservedObject var companion: CompanionSession
    @ObservedObject var collections: CollectionsStore
    var onClose: () -> Void
    var onStartConversation: () -> Void
    var onOpenConversation: (UUID) -> Void
    var onOpenLink: (UUID) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Links") {
                    let links = ChapterHubContent.links(collections.links, in: chapter)
                    if links.isEmpty {
                        Text("No verse links in this chapter.").foregroundStyle(.secondary)
                    }
                    ForEach(links) { link in
                        Button { onOpenLink(link.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(link.title, systemImage: "link")
                                Text("Verse \(link.verse?.verse ?? 0)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Chapter Conversations") {
                    Button(action: onStartConversation) {
                        Label("Ask about this chapter", systemImage: "bubble.left.and.bubble.right")
                    }
                    .accessibilityIdentifier("scripture.askChapter")
                    let conversations = companion.chapterConversations(for: chapter)
                    if conversations.isEmpty {
                        Text("No chapter conversations yet.").foregroundStyle(.secondary)
                    }
                    ForEach(conversations) { conversation in
                        Button(conversation.title) { onOpenConversation(conversation.id) }
                    }
                }
                Section("Verse Conversations") {
                    let conversations = companion.verseConversations(in: chapter)
                    if conversations.isEmpty {
                        Text("No verse conversations in this chapter.").foregroundStyle(.secondary)
                    }
                    ForEach(conversations) { conversation in
                        Button { onOpenConversation(conversation.id) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                if let anchor = conversation.passageAnchor {
                                    Text(anchor.referenceLabel).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(chapter.referenceLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done", action: onClose) }
        }
    }
}

enum ChapterHubContent {
    static func links(_ links: [SavedLink], in chapter: CompanionChapterAnchor) -> [SavedLink] {
        links.filter {
            $0.verse?.book == chapter.bookID && $0.verse?.chapter == chapter.chapter &&
                $0.editionID == chapter.editionID
        }.sorted {
            let left = $0.verse?.verse ?? 0
            let right = $1.verse?.verse ?? 0
            return left == right ? $0.createdAt < $1.createdAt : left < right
        }
    }
}

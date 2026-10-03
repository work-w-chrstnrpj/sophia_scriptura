import SwiftUI

struct CompanionSourceInspectorView: View {
    let message: CompanionMessage
    let sources: [CompanionSource]

    var body: some View {
        List {
            if sources.isEmpty {
                Section {
                    Text("No sources for this reply")
                        .font(.headline)
                    Text("The model can append a Sophia bibliography section at the end of its answer. Sophia removes that section from the visible message and lists it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Sources") {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(source.title).font(.headline)
                            if let author = source.authorOrPublisher, !author.isEmpty {
                                Text(author).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let url = source.url, let link = URL(string: url) {
                                Link(link.absoluteString, destination: link)
                                    .font(.caption)
                            }
                            if let claim = source.claim, !claim.isEmpty {
                                Text(claim).font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Sources")
    }
}

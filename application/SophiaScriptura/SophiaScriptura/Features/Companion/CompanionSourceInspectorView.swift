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
                    Text("This reply did not provide external references. No web research has been verified for this answer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(source.title).font(.headline)
                            Text(CompanionStudySources.provenanceLabel(for: source))
                                .font(.caption).foregroundStyle(.secondary)
                            if let author = source.authorOrPublisher, !author.isEmpty {
                                Text(author).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let url = source.url, let link = CompanionResponseFormatting.validWebURL(url) {
                                Link("Open reference · \(link.host ?? "website")", destination: link)
                                    .font(.caption)
                            } else if let lookup = CompanionStudySources.lookupURL(for: source) {
                                Text("No direct source link was supplied.").font(.caption).foregroundStyle(.secondary)
                                Link("Find this reference online", destination: lookup).font(.caption)
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

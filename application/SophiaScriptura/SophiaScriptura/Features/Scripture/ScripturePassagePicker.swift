import SwiftUI

/// Browsing choices is local to this sheet; only a final choice changes reader state.
struct ScripturePassagePicker: View {
    let session: ReaderSession
    let select: (String, Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    private var appearance: ScriptureAppearance { session.preferences.appearance }
    private var palette: ReaderPalette { session.preferences.palette(for:appearance,colorScheme:colorScheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing:8) {
                    Image(systemName:"scope").foregroundStyle(Color(palette.secondary))
                    Text("Current: \(session.title)").font(.subheadline.weight(.medium))
                    Spacer()
                }.padding(.horizontal).padding(.top,8)
                TextField("Find a book",text:$query).textFieldStyle(.roundedBorder)
                    .padding(.horizontal).accessibilityIdentifier("reader.bookSearch")
                List {
                    ForEach(["OT","NT"],id:\.self) { testament in
                        Section(testament == "OT" ? "Old Testament" : "New Testament") {
                            ForEach(session.books.filter { $0.testament == testament && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }) { book in
                                NavigationLink {
                                    chapters(book)
                                } label: {
                                    HStack {
                                        Text(book.title)
                                        Spacer()
                                        if book.id == session.document?.book {
                                            Image(systemName:"checkmark").foregroundStyle(Color(palette.accent)).accessibilityHidden(true)
                                        }
                                    }
                                }
                                .listRowBackground(Color(palette.paper))
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowSeparatorTint(Color(palette.rule))
                .background(Color(palette.paper))
                .foregroundStyle(Color(palette.ink))
                .tint(Color(palette.accent))
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(palette.paper))
            .navigationTitle("Book")
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } } }
            .toolbarBackground(Color(palette.paper), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .background(Color(palette.paper).ignoresSafeArea())
    }
    private func chapters(_ book: ScriptureBook) -> some View {
        ScrollView {
            LazyVGrid(columns:[GridItem(.adaptive(minimum:70))],spacing:12) {
                ForEach(1...book.chapterCount,id:\.self) { chapter in
                    NavigationLink {
                        VersePicker(session:session,book:book,chapter:chapter,select:select)
                    } label: { Text(String(chapter)).frame(maxWidth:.infinity,minHeight:52) }
                        .background(Color(palette.ink).opacity(0.06),in:RoundedRectangle(cornerRadius:10))
                        .accessibilityIdentifier("reader.chapter.\(chapter)")
                }
            }.padding(24)
        }
        .navigationTitle("\(book.title) · Chapter")
        .background(Color(palette.paper).ignoresSafeArea())
        .toolbarBackground(Color(palette.paper), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct VersePicker: View {
    let session: ReaderSession
    let book: ScriptureBook
    let chapter: Int
    let select: (String, Int, Int) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var verses: [Int] = []
    @State private var error: String?
    @State private var attempt = 0
    private var palette: ReaderPalette { session.preferences.palette(for: session.preferences.appearance, colorScheme: colorScheme) }

    var body: some View {
        Group {
            if let error {
                ContentUnavailableView {
                    Label("Verses unavailable",systemImage:"book.closed")
                } description: { Text(error) } actions: { Button("Retry") { attempt += 1 } }
            } else if verses.isEmpty {
                ProgressView("Loading verses…")
            } else {
                ScrollView {
                    Button("Read chapter") { select(book.id,chapter,verses[0]) }
                        .buttonStyle(.bordered).padding(.top)
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:70))],spacing:12) {
                        ForEach(verses,id:\.self) { verse in
                            Button(String(verse)) { select(book.id,chapter,verse) }
                                .frame(maxWidth:.infinity,minHeight:52)
                                .background(Color(palette.ink).opacity(0.06),in:RoundedRectangle(cornerRadius:10))
                                .accessibilityIdentifier("reader.verse.\(verse)")
                        }
                    }.padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(palette.paper).ignoresSafeArea())
        .foregroundStyle(Color(palette.ink))
        .tint(Color(palette.accent))
        .navigationTitle("\(book.title) \(chapter) · Verse")
        .toolbarBackground(Color(palette.paper), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
            .task(id:attempt) {
                error = nil
                do {
                    let loaded = try await session.availableVerses(book:book.id,chapter:chapter)
                    guard !Task.isCancelled else { return }
                    guard !loaded.isEmpty else { throw ScriptureError.passageUnmapped }
                    verses = loaded
                } catch {
                    guard !Task.isCancelled else { return }
                    self.error = error.localizedDescription
                }
            }
    }
}

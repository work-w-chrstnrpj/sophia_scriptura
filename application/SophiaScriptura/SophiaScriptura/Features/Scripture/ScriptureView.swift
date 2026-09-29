import SwiftUI

struct ScriptureView: View {
    @Bindable var session: ReaderSession
    @State private var picker: ReaderPicker?
    @State private var wideLayout = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    enum ReaderPicker: String, Identifiable { case book, version; var id: String { rawValue } }
    private var appearance: ScriptureAppearance { session.preferences.appearance }
    private var palette: ReaderPalette { session.preferences.palette(for:appearance,colorScheme:colorScheme) }
    var body: some View {
        ZStack {
            VStack(spacing:0) {
            HStack(spacing:16) {
                if wideLayout {
                    VStack(alignment:.leading,spacing:4) {
                        Text("Sophia Scriptura").font(.custom("Georgia",size:22,relativeTo:.title2))
                        Text("READ · REFLECT · REMEMBER").font(.caption2).tracking(2)
                            .foregroundStyle(Color(palette.secondary))
                    }
                    Spacer(minLength:16)
                }
                HStack(spacing:0) {
                Button { picker = .book } label: {
                    Text(session.currentBook?.title ?? session.title)
                        .lineLimit(1)
                        .frame(minWidth:110,minHeight:44)
                }.accessibilityIdentifier("reader.book")
                    .accessibilityLabel("Book, \(session.title)")
                    .disabled(session.document == nil)
                Rectangle().fill(Color(palette.rule)).frame(width:1,height:22)
                Button { picker = .version } label: {
                    Text(session.abbreviation)
                        .frame(minWidth:82,minHeight:44)
                }.accessibilityIdentifier("reader.version")
                    .accessibilityLabel("Version, \(session.abbreviation)")
                }
                .background(Color(palette.paper),in:Capsule())
                .overlay(Capsule().stroke(Color(palette.rule),lineWidth:1))
                .shadow(color:Color.black.opacity(0.04),radius:8,y:3)
                if !wideLayout { Spacer(minLength:0) }
            }.font(ScriptureFonts.interface(appearance))
                .buttonStyle(.plain).padding(.horizontal,24).padding(.vertical,10)
            if let notice = session.notice {
                Text(notice).font(.caption).foregroundStyle(.secondary).padding(10).accessibilityIdentifier("reader.notice")
            }
            if let error = session.error {
                ContentUnavailableView {
                    Label("Reader unavailable",systemImage:"book.closed")
                } description: { Text(error) } actions: {
                    Button("Retry") { Task { await session.start() } }
                }
            } else if let document = session.document {
                VStack(spacing:6) {
                    Text(session.title).font(Font(UIFontMetrics(forTextStyle:.largeTitle).scaledFont(for:ScriptureFonts.font(appearance.headingFamily,size:36))))
                        .accessibilityAddTraits(.isHeader)
                    Text(session.edition?.name ?? session.abbreviation)
                        .font(ScriptureFonts.interface(appearance,size:13)).foregroundStyle(Color(palette.secondary))
                }.padding(.top,10).padding(.horizontal,24)
                ReaderTextSurface(document:document,preferences:session.preferences,targetVerse:session.targetVerse,
                                  navigationID:session.navigationID,restorationLocation:session.restorationLocation,onVerse:{ session.hubVerse = document.verse($0) },
                                  onVisibleLocation:session.visibleLocation,onChapterSwipe:{ step in Task { await session.stepChapter(step) } },authorizeQuote:session.authorizeQuote)
                    .frame(maxWidth:760).frame(maxWidth:.infinity)
                HStack {
                    Button { Task { await session.stepChapter(-1) } } label: {
                        Image(systemName:"chevron.left")
                            .frame(width:44,height:44)
                            .background(Color(palette.ink).opacity(0.08),in:Circle())
                    }
                    .accessibilityLabel("Previous chapter")
                    .disabled(document.book == "GEN" && document.chapter == 1)
                    Spacer()
                    Text(session.title).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("reader.location")
                    Spacer()
                    Button { Task { await session.stepChapter(1) } } label: {
                        Image(systemName:"chevron.right")
                            .frame(width:44,height:44)
                            .background(Color(palette.ink).opacity(0.08),in:Circle())
                    }
                    .accessibilityLabel("Next chapter")
                    .disabled(document.book == "REV" && document.chapter == 22)
                }.padding(.horizontal,24).padding(.vertical,12)
            } else {
                Spacer(); ProgressView("Opening your Bible…"); Spacer()
            }
            }
            .foregroundStyle(Color(palette.ink))
            .tint(Color(palette.accent))

            if picker != nil {
                Rectangle()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.05 : 0.025))
                    .background(.ultraThinMaterial)
                    .opacity(0.58)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .background(Color(palette.paper).ignoresSafeArea())
        .animation(.easeOut(duration:0.18),value:picker != nil)
        .task {
            await session.start()
            await session.resume()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for:.seconds(60))
                guard !Task.isCancelled else { return }
                await session.checkAccess()
            }
        }
        .onChange(of:scenePhase) { _, phase in
            if phase != .active { session.suspendLicensedContent() }
            else { Task { await session.resume() } }
        }
        .sheet(item:$picker) { item in pickerSheet(item) }
        .background(GeometryReader { geometry in
            Color.clear.onAppear { wideLayout = geometry.size.width > 900 }
                .onChange(of:geometry.size) { _, size in wideLayout = size.width > 900 }
        })
        .sheet(item:hubBinding(wide:false)) { hub($0) }
        .popover(item:hubBinding(wide:true),arrowEdge:.top) { hub($0).frame(width:440,height:600) }
    }
    private func hubBinding(wide: Bool) -> Binding<VerseID?> {
        Binding(get:{ wideLayout == wide ? session.hubVerse : nil },set:{ session.hubVerse = $0 })
    }
    private func hub(_ verse: VerseID) -> some View {
            NavigationStack {
                List {
                    Section("\(session.currentBook?.title ?? verse.book) \(verse.chapter):\(verse.verse) · \(session.abbreviation)") {
                        Text(session.document?.body(for:verse.verse) ?? "").font(.system(.title3,design:.serif))
                        Button("Copy verse") {
                            guard let document = session.document else { return }
                            let map = ChapterTextMap(document:document)
                            let ranges = map.focusRanges(for:verse.verse)
                            guard let first = ranges.first, let last = ranges.last else { return }
                            let selection = map.selection(in:NSUnionRange(first,last))
                            Task {
                                if let text = await session.authorizeQuote(selection) {
                                    UIPasteboard.general.string = text
                                }
                            }
                        }
                        Text("Select text in the reader to share a passage.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(["Notes","Conversations","Collections","Links"],id:\.self) { name in
                        Section(name) { Text("No \(name.lowercased()) attached to this verse.").foregroundStyle(.secondary) }
                    }
                }.navigationTitle("Verse hub").toolbar { Button("Done") { session.hubVerse = nil } }
            }.presentationDetents([.medium,.large])
    }
    @ViewBuilder private func pickerSheet(_ item: ReaderPicker) -> some View {
        switch item {
        case .book:
            ScripturePassagePicker(session:session) { book, chapter, verse in
                picker = nil
                Task { await session.navigate(book:book,chapter:chapter,verse:verse) }
            }
            .presentationBackground(Color(palette.paper))
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
        case .version:
            ScriptureVersionsView(session:session)
                .presentationBackground(Color(palette.paper))
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }
}

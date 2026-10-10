import SwiftUI
import UIKit

struct CompanionView: View {
    @ObservedObject var session: CompanionSession
    var openNote: (UUID) -> Void = { _ in }
    @Environment(NotesSession.self) private var notes
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var showQuizSetup = false
    @State private var selectedQuizReviewID: UUID?
    @State private var renameTarget: CompanionConversation?
    @State private var renameDraft = ""
    @State private var renameQuizID: UUID?
    @State private var renameQuizDraft = ""
    @State private var conversationPendingDelete: UUID?
    @State private var quizPendingDelete: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var pendingNoteSave: StudyNoteSaveContent?
    @State private var showArchivedConversations = false

    var body: some View {
        ZStack {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                HStack {
                    LibraryHeaderTitle(title: "Companion")
                        .accessibilityIdentifier("companion.title")
                    Spacer(minLength: 12)
                    Button { showArchivedConversations = true } label: {
                        LibraryHeaderIcon(systemImage: "archivebox")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Archived conversations")
                    .accessibilityIdentifier("companion.archive")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                List(selection: Binding(get: { session.selectedConversationID }, set: { session.selectConversation($0) })) {
                Section {
                    Button {
                        _ = session.createConversation()
                    } label: {
                        Label("New conversation", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("companion.newConversation")
                    Button { showQuizSetup = true } label: {
                        Label("Quiz Me", systemImage: "questionmark.circle")
                    }
                    .accessibilityIdentifier("companion.quizMe")
                }

                CompanionSidebarDivider()

                CompanionCollapsibleSidebarSection(
                    title: "Chat history",
                    isExpanded: Binding(
                        get: { session.sidebarChatHistoryExpanded },
                        set: { session.setSidebarChatHistoryExpanded($0) }
                    )
                ) {
                    if session.activeConversations.isEmpty {
                        Text("No conversations yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.activeConversations) { conversation in
                        let selected = session.selectedConversationID == conversation.id
                        let selectedInk = CompanionSelectionContrast.label(on: theme.palette.accent, palette: theme.palette)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .foregroundStyle(selected ? Color(selectedInk) : Color(theme.palette.ink))
                            Text(conversation.presetSnapshot.displayName + " · " + conversation.modelID)
                                .font(.caption)
                                .foregroundStyle(selected ? Color(selectedInk).opacity(0.82) : Color(theme.palette.secondary))
                        }
                        .tag(conversation.id as UUID?)
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                renameTarget = conversation
                                renameDraft = conversation.title
                            }
                            Button("Archive", systemImage: "archivebox") {
                                session.archiveConversation(conversation.id)
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                conversationPendingDelete = conversation.id
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { conversationPendingDelete = conversation.id } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                renameTarget = conversation
                                renameDraft = conversation.title
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                            Button { session.archiveConversation(conversation.id) } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                    }
                }

                CompanionSidebarDivider()

                CompanionCollapsibleSidebarSection(
                    title: "Quiz history",
                    isExpanded: Binding(
                        get: { session.sidebarQuizHistoryExpanded },
                        set: { session.setSidebarQuizHistoryExpanded($0) }
                    )
                ) {
                    let completed = session.completedQuizSessions
                    if completed.isEmpty {
                        Text("No completed quizzes yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(completed) { quiz in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quizDisplayTitle(quiz))
                                    .font(.headline)
                                Text("\(quiz.scoreEarned)/\(quiz.scoreAvailable) pts · \(quiz.difficulty.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectedQuizReviewID = quiz.id }
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") {
                                    renameQuizID = quiz.id
                                    renameQuizDraft = quizDisplayTitle(quiz)
                                }
                                Button("Review answers", systemImage: "list.bullet.rectangle") { selectedQuizReviewID = quiz.id }
                                Button("Archive", systemImage: "archivebox") { session.archiveQuizSession(quiz.id) }
                                Button("Delete", systemImage: "trash", role: .destructive) { quizPendingDelete = quiz.id }
                                    .tint(.red)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { quizPendingDelete = quiz.id } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    renameQuizID = quiz.id
                                    renameQuizDraft = quizDisplayTitle(quiz)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                                Button { session.archiveQuizSession(quiz.id) } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .appSurface()
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color(theme.palette.rule))
                        .frame(width: 1)
                        .ignoresSafeArea()
                }
            }
            .appSurface()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showArchivedConversations) {
                StudyArchivedConversationsView(session: session)
                    .toolbar(.visible, for: .navigationBar)
            }
        } detail: {
            if let conversation = session.selectedConversation {
                CompanionConversationView(
                    session: session,
                    conversation: conversation,
                    compact: false,
                    columnVisibility: $columnVisibility,
                    pendingNoteSave: $pendingNoteSave,
                    openNote: openNote
                )
            } else {
                ContentUnavailableView(
                    "Choose or start a chat",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Add provider keys in Settings, pick a preset in the chat footer, then begin a study conversation.")
                )
                .appSurface()
            }
        }
        .appSurface()

            if showQuizSetup {
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .background(.ultraThinMaterial)
                    .opacity(0.65)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showQuizSetup)
        .onChange(of: session.sophyQuizRequest) { _, request in
            if request != nil { showQuizSetup = true }
        }
        .sheet(isPresented: $showQuizSetup, onDismiss: { session.sophyQuizRequest = nil }) {
            QuizMeView(session: session, request: session.sophyQuizRequest)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .fullScreenCover(item: Binding(
            get: { session.activeQuizSessionID.map(QuizRoute.init) },
            set: { _ in }
        )) { route in
            NavigationStack {
                QuizSessionView(session: session, quizID: route.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                session.abandonActiveQuiz()
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close quiz")
                        }
                    }
            }
            .interactiveDismissDisabled(true)
            .appSurface()
        }
        .fullScreenCover(item: $selectedQuizReviewID) { id in
            CompanionQuizDetailView(session: session, quizID: id)
        }
        .overlay {
            if renameTarget != nil {
                StudyCenteredRenameOverlay(
                    title: "Rename conversation",
                    text: $renameDraft,
                    confirmLabel: "Save",
                    onConfirm: {
                        if let id = renameTarget?.id {
                            session.renameConversation(id, title: renameDraft)
                        }
                        renameTarget = nil
                    },
                    onCancel: { renameTarget = nil }
                )
            }
        }
        .overlay {
            if renameQuizID != nil {
                StudyCenteredRenameOverlay(
                    title: "Rename quiz",
                    text: $renameQuizDraft,
                    confirmLabel: "Save",
                    onConfirm: {
                        if let id = renameQuizID {
                            session.renameQuizSession(id, title: renameQuizDraft)
                        }
                        renameQuizID = nil
                    },
                    onCancel: { renameQuizID = nil }
                )
            }
        }
        .overlay {
            if let id = conversationPendingDelete,
               let conversation = session.conversations.first(where: { $0.id == id }) {
                StudyCenteredConfirmationOverlay(
                    title: "Delete \(conversation.title)?",
                    message: "Moves the conversation to Trash for \(TrashRetention.dayCount) days. You can restore it from Settings until then.",
                    confirmLabel: "Move to Trash",
                    onConfirm: {
                        session.deleteConversation(id)
                        conversationPendingDelete = nil
                    },
                    onCancel: { conversationPendingDelete = nil }
                )
            }
        }
        .overlay {
            if quizPendingDelete != nil {
                StudyCenteredConfirmationOverlay(
                    title: "Delete this quiz?",
                    message: "The quiz session and its answers are removed from history.",
                    confirmLabel: "Delete Quiz",
                    onConfirm: {
                        if let id = quizPendingDelete { session.deleteQuizSession(id) }
                        quizPendingDelete = nil
                    },
                    onCancel: { quizPendingDelete = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: renameTarget != nil)
        .animation(.easeOut(duration: 0.18), value: renameQuizID != nil)
        .animation(.easeOut(duration: 0.18), value: conversationPendingDelete != nil)
        .animation(.easeOut(duration: 0.18), value: quizPendingDelete != nil)
        .alert("Companion", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.clearNotice() } })) {
            Button("OK", role: .cancel) { session.clearNotice() }
        } message: {
            Text(session.notice ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.scheduleQuizCacheWarmup() }
        }
        .sheet(item: Binding(
            get: { pendingNoteSave.map(PendingNoteSaveItem.init) },
            set: { pendingNoteSave = $0?.content }
        )) { item in
            StudyNoteDestinationPicker(content: item.content, notes: notes, openNote: openNote)
        }
    }

    private func quizDisplayTitle(_ quiz: QuizSession) -> String {
        let custom = quiz.customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        return quiz.completedAt?.formatted(date: .abbreviated, time: .shortened)
            ?? quiz.createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

enum CompanionSelectionContrast {
    /// Sidebar selection fills with the accent. Pick the palette color farthest from that fill.
    static func label(on background: UIColor, palette: ReaderPalette) -> UIColor {
        func luminance(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }
        let backgroundLuminance = luminance(background)
        let inkDistance = abs(luminance(palette.ink) - backgroundLuminance)
        let paperDistance = abs(luminance(palette.paper) - backgroundLuminance)
        return paperDistance > inkDistance ? palette.paper : palette.ink
    }
}

private struct CompanionSidebarDivider: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        Section {
            Rectangle()
                .fill(Color(theme.palette.rule).opacity(0.65))
                .frame(height: 1)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .listRowBackground(Color.clear)
        }
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

private struct QuizRoute: Identifiable { let id: UUID }

private struct PendingNoteSaveItem: Identifiable {
    let id = UUID()
    let content: StudyNoteSaveContent
}

struct CompanionConversationView: View {
    @ObservedObject var session: CompanionSession
    let conversation: CompanionConversation
    var compact: Bool
    var columnVisibility: Binding<NavigationSplitViewVisibility>?
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var userProfile: UserProfileSession
    @State private var routingProviderConfigID = UUID()
    @State private var routingModelID = ""
    @Binding var pendingNoteSave: StudyNoteSaveContent?
    var openNote: (UUID) -> Void = { _ in }

    private var liveConversation: CompanionConversation {
        session.conversations.first(where: { $0.id == conversation.id }) ?? conversation
    }

    private var threadMessages: [CompanionMessage] {
        session.messages(for: conversation.id)
    }

    private var latestAssistantID: UUID? {
        threadMessages.last(where: { $0.role == .assistant })?.id
    }

    private var latestUserID: UUID? {
        threadMessages.last(where: { $0.role == .user })?.id
    }

    private var sidebarHidden: Bool {
        columnVisibility?.wrappedValue == .detailOnly
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if let anchor = liveConversation.passageAnchor {
                            CompanionPassageContextCard(
                                referenceLabel: anchor.referenceLabel,
                                excerpt: session.attachments.first(where: { $0.conversationID == conversation.id })?.payload,
                                palette: theme.palette
                            )
                        } else if let anchor = liveConversation.chapterAnchor {
                            CompanionPassageContextCard(
                                referenceLabel: anchor.referenceLabel,
                                excerpt: "Chapter reference only · no chapter text attached",
                                palette: theme.palette
                            )
                        }
                        if threadMessages.isEmpty, !session.isSending {
                            if liveConversation.passageAnchor != nil || liveConversation.chapterAnchor != nil {
                                CompanionScriptureEmptyGreeting(greeting: userProfile.scriptureGreeting)
                            } else {
                                CompanionEmptyConversationPrompts(session: session)
                            }
                        }
                        ForEach(threadMessages) { message in
                            CompanionMessageBubble(
                                session: session,
                                message: message,
                                palette: theme.palette,
                                isLatestAssistant: message.id == latestAssistantID,
                                isLatestUser: message.id == latestUserID,
                                onSaveToNote: {
                                    pendingNoteSave = .companionResponse(
                                        text: message.content,
                                        anchor: liveConversation.passageAnchor
                                    )
                                }
                            )
                            .id(message.id)
                        }
                        ForEach(session.attachments.filter { $0.conversationID == conversation.id }) { attachment in
                            Text(transmissionLabel(attachment))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .background(Color(theme.palette.paper))
                .onChange(of: session.messages(for: conversation.id).count) { _, _ in
                    if let last = session.messages(for: conversation.id).last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            CompanionStudyChrome {
                if let card = session.scriptureComposerCard(for: conversation.id) {
                    CompanionScriptureActionCard(markdown: card, palette: theme.palette)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("companion.scriptureActionCard")
                } else {
                    HStack(alignment: .bottom, spacing: 12) {
                        TextField("Ask a study question…", text: Binding(
                            get: { session.composerText },
                            set: { session.updateComposerDraft($0) }
                        ), axis: .vertical)
                        .lineLimit(1...6)
                        .padding(10)
                        .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(theme.palette.rule)))
                        .accessibilityIdentifier("companion.composer")

                        if session.isSending {
                            Button("Stop") { session.cancelStreaming() }
                        } else {
                            Button("Send") { Task { await session.sendMessage() } }
                                .buttonStyle(.borderedProminent)
                                .foregroundStyle(Color(theme.palette.paper))
                                .tint(Color(theme.palette.accent))
                                .disabled(session.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("companion.send")
                        }
                    }
                }
                if !compact {
                    CompanionInlineRoutingBar(
                        session: session,
                        conversationID: conversation.id,
                        providerConfigID: $routingProviderConfigID,
                        modelID: $routingModelID,
                        accessibilityPrefix: "companion"
                    )
                }
                if compact {
                    Text("Preset and model use your Companion defaults. Expand to change them.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Send transmits the displayed context online.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Color(theme.palette.paper).ignoresSafeArea())
        .foregroundStyle(Color(theme.palette.ink))
        .navigationTitle(liveConversation.title)
        .navigationBarTitleDisplayMode(compact ? .inline : .automatic)
        .toolbarBackground(Color(theme.palette.paper), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if let columnVisibility {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            columnVisibility.wrappedValue = sidebarHidden ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: sidebarHidden ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    .accessibilityLabel(sidebarHidden ? "Show sidebar" : "Expand conversation")
                    .accessibilityIdentifier("companion.sidebarToggle")
                }
            }
        }
        .toolbar(removing: .sidebarToggle)
        .onAppear { syncRoutingFromConversation() }
        .onChange(of: liveConversation.providerConfigID) { _, _ in syncRoutingFromConversation() }
        .onChange(of: liveConversation.modelID) { _, _ in syncRoutingFromConversation() }
        .onChange(of: routingProviderConfigID) { _, configID in
            session.updateConversationRouting(
                conversationID: conversation.id,
                providerConfigID: configID,
                modelID: routingModelID
            )
        }
        .onChange(of: routingModelID) { _, modelID in
            session.updateConversationRouting(
                conversationID: conversation.id,
                providerConfigID: routingProviderConfigID,
                modelID: modelID
            )
        }
        .task(id: conversation.id) {
            await session.flushScriptureAutoSendIfNeeded(conversationID: conversation.id)
        }
    }

    private func syncRoutingFromConversation() {
        if routingProviderConfigID != liveConversation.providerConfigID {
            routingProviderConfigID = liveConversation.providerConfigID
        }
        if routingModelID != liveConversation.modelID {
            routingModelID = liveConversation.modelID
        }
    }

    private func transmissionLabel(_ attachment: CompanionAttachment) -> String {
        switch attachment.disclosure {
        case .referenceOnly: return "Attached reference: \(attachment.referenceLabel)"
        case .textTransmitted: return "Attached text transmitted: \(attachment.referenceLabel)"
        case .localOnly: return "Local attachment: \(attachment.referenceLabel)"
        }
    }
}

private struct CompanionPassageContextCard: View {
    let referenceLabel: String
    let excerpt: String?
    let palette: ReaderPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(referenceLabel, systemImage: "book")
                .font(.subheadline.weight(.semibold))
            if let excerpt, !excerpt.isEmpty {
                Text(excerpt)
                    .font(.callout)
                    .foregroundStyle(Color(palette.ink))
            } else {
                Text("Passage reference attached.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(palette.rule).opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(palette.rule)))
    }
}

private struct CompanionScriptureEmptyGreeting: View {
    let greeting: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(theme.palette.ink))
            Text("Type your question below when you are ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityIdentifier("companion.scriptureGreeting")
    }
}

private struct CompanionEmptyConversationPrompts: View {
    @ObservedObject var session: CompanionSession
    @Environment(\.appTheme) private var theme

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private let suggestions = [
        "Summarize the main theme of Psalm 23.",
        "What does Romans 8:28 teach in context?",
        "Help me compare John 1:1 and Genesis 1:1.",
        "Give me a short prayer based on Philippians 4:6–7."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(greeting), how can I help you today?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                Text("Tap a starter question or type your own below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { prompt in
                    Button {
                        Task { await session.sendSuggestedPrompt(prompt) }
                    } label: {
                        Text(prompt)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(theme.palette.rule)))
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isSending)
                    .accessibilityIdentifier("companion.faqPrompt")
                }
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct CompanionMessageBubble: View {
    @ObservedObject var session: CompanionSession
    let message: CompanionMessage
    let palette: ReaderPalette
    var isLatestAssistant: Bool = false
    var isLatestUser: Bool = false
    var onSaveToNote: () -> Void = {}
    @Environment(NotesSession.self) private var notes
    @State private var showSources = false
    @State private var editUserMessage = false
    @State private var editDraft = ""

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user { Spacer(minLength: 56) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.role == .user ? "You" : "Companion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if message.role == .user, message.providerContent != nil {
                    CompanionScriptureActionCard(markdown: message.content, palette: palette)
                        .accessibilityLabel("Original language analysis request")
                        .accessibilityAddTraits(.isStaticText)
                } else {
                CompanionMessageLayout {
                Group {
                    if message.content.isEmpty, message.deliveryState == .streaming || message.deliveryState == .sending {
                        CompanionTypingIndicator()
                    } else if message.content.isEmpty {
                        Text(statusLabel)
                    } else if message.role == .assistant {
                        CompanionMarkdownText(content: message.content, ink: Color(palette.ink))
                    } else {
                        Text(message.content)
                            .multilineTextAlignment(message.role == .user ? .trailing : .leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(bubbleColor, in: RoundedRectangle(cornerRadius: 14))
                }
                if message.deliveryState == .failed || message.deliveryState == .refused {
                    Text("Response incomplete")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                if message.role == .assistant, message.deliveryState == .complete, !message.content.isEmpty {
                    CompanionAssistantMessageActions(
                        message: message,
                        session: session,
                        palette: palette,
                        showSources: $showSources,
                        notesLoaded: notes.loaded,
                        isLatestAssistant: isLatestAssistant,
                        onSaveToNote: onSaveToNote
                    )
                }
                if message.role == .user, isLatestUser, message.providerContent == nil, !session.isSending, !message.content.isEmpty {
                    Button {
                        editDraft = message.content
                        editUserMessage = true
                    } label: {
                        Label("Edit and resend", systemImage: "pencil")
                            .font(.caption)
                    }
                    .accessibilityIdentifier("companion.editLatestPrompt")
                }
            }
            if message.role == .assistant { Spacer(minLength: 56) }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showSources) {
            NavigationStack {
                CompanionSourceInspectorView(message: message, sources: session.sources(for: message))
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showSources = false } } }
            }
            .appSurface()
        }
        .sheet(isPresented: $editUserMessage) {
            NavigationStack {
                Form {
                    Section("Edit your message") {
                        TextField("Message", text: $editDraft, axis: .vertical)
                            .lineLimit(4...12)
                    }
                }
                .navigationTitle("Edit prompt")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editUserMessage = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Resend") {
                            editUserMessage = false
                            Task { await session.editAndResend(userMessageID: message.id, newText: editDraft) }
                        }
                        .disabled(editDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var bubbleColor: Color {
        if message.role == .user {
            return Color(palette.accent).opacity(0.18)
        }
        return Color(palette.rule).opacity(0.35)
    }

    private var statusLabel: String {
        switch message.deliveryState {
        case .streaming, .sending: return "…"
        case .failed: return "Could not complete the response."
        case .refused: return "The provider refused this request."
        case .interrupted: return "Response cancelled."
        default: return ""
        }
    }
}

private struct CompanionAssistantMessageActions: View {
    let message: CompanionMessage
    @ObservedObject var session: CompanionSession
    let palette: ReaderPalette
    @Binding var showSources: Bool
    let notesLoaded: Bool
    let isLatestAssistant: Bool
    let onSaveToNote: () -> Void
    @State private var copyConfirmed = false

    private var messageSources: [CompanionSource] {
        session.sources(for: message)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Button {
                    UIPasteboard.general.string = message.content
                    copyConfirmed = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copyConfirmed = false
                    }
                } label: {
                    Image(systemName: copyConfirmed ? "checkmark" : "doc.on.doc")
                }
                .disabled(copyConfirmed)
                .opacity(copyConfirmed ? 0.45 : 1)
                .accessibilityLabel(copyConfirmed ? "Response copied" : "Copy response")
                .accessibilityIdentifier("companion.copyResponse")

                ShareLink(item: message.content) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share response")

                Button { showSources = true } label: {
                    Image(systemName: "books.vertical")
                }
                .accessibilityLabel(messageSources.isEmpty ? "Sources (none listed)" : "Sources")
                .accessibilityIdentifier("companion.sources")

                Button(action: onSaveToNote) {
                    Image(systemName: "note.text.badge.plus")
                }
                .disabled(!notesLoaded)
                .accessibilityLabel("Save to note")

                if isLatestAssistant {
                    Button {
                        Task { await session.retryAssistantMessage(message.id) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(session.isSending)
                    .accessibilityLabel("Retry response")
                }
            }
            .font(.body)
            .foregroundStyle(Color(palette.secondary))
            .buttonStyle(.plain)

            if copyConfirmed {
                Text("Text copied")
                    .font(.caption)
                    .foregroundStyle(Color(palette.secondary))
                    .accessibilityIdentifier("companion.copyConfirmed")
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: copyConfirmed)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("companion.responseActions")
    }
}

#Preview {
    CompanionView(session: CompanionSession(
        presetCatalog: try! PromptPresetCatalog.bundled(),
        repository: nil,
        credentials: InMemoryCompanionCredentialsStore(),
        registry: ProviderRegistry(adapters: [MockLLMProviderAdapter()])
    ))
}

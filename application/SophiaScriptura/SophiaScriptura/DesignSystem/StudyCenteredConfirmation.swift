import SwiftUI

struct StudyCenteredConfirmationOverlay: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let message: String
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(colorSchemeOpacity)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .multilineTextAlignment(.center)
                Button(role: .destructive, action: onConfirm) {
                    Text(confirmLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(theme.palette.ink))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 24, y: 8)
            .accessibilityElement(children: .contain)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(50)
    }

    private var colorSchemeOpacity: Double { theme.dark ? 0.55 : 0.35 }
}

struct StudyCenteredRenameOverlay: View {
    @Environment(\.appTheme) private var theme
    let title: String
    @Binding var text: String
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(theme.dark ? 0.55 : 0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                TextField("Title", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { onConfirm() }
                Button(action: onConfirm) {
                    Text(confirmLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(theme.palette.accent))
                .foregroundStyle(Color(theme.palette.paper))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(theme.palette.ink))
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 24, y: 8)
        }
        .onAppear { focused = true }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(50)
    }
}

extension View {
    func studyCenteredConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmLabel: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                StudyCenteredConfirmationOverlay(
                    title: title,
                    message: message,
                    confirmLabel: confirmLabel,
                    onConfirm: {
                        onConfirm()
                        isPresented.wrappedValue = false
                    },
                    onCancel: { isPresented.wrappedValue = false }
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPresented.wrappedValue)
    }
}

/// Center-screen card for two or more primary actions (Notes kind, Activity add, etc.).
struct StudyCenteredActionOverlay: View {
    struct Action: Identifiable {
        var id: String
        var title: String
        var systemImage: String
        var handler: () -> Void
    }

    @Environment(\.appTheme) private var theme
    let title: String
    var cardMaxWidth: CGFloat = 300
    let actions: [Action]
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(theme.dark ? 0.55 : 0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 10) {
                    ForEach(actions) { action in
                        Button(action: action.handler) {
                            Label(action.title, systemImage: action.systemImage)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(theme.palette.accent))
                        .foregroundStyle(Color(theme.palette.ink))
                        .labelStyle(.titleAndIcon)
                        .accessibilityIdentifier(action.id)
                    }
                }
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(theme.palette.ink))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(width: cardMaxWidth)
            .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 24, y: 8)
            .accessibilityElement(children: .contain)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(50)
    }
}

enum StudyTypedDeletion {
    static let requiredPhrase = "Confirm Deletion"
    static let confirmButtonTitle = "Delete Confirmation"
}

struct StudyTypedDeletionOverlay: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let message: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var typed = ""
    @FocusState private var focused: Bool

    private var phraseMatches: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines) == StudyTypedDeletion.requiredPhrase
    }

    var body: some View {
        ZStack {
            Color.black.opacity(theme.dark ? 0.55 : 0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .multilineTextAlignment(.center)
                Text("Type \"\(StudyTypedDeletion.requiredPhrase)\" to continue.")
                    .font(.caption)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .multilineTextAlignment(.center)
                TextField(StudyTypedDeletion.requiredPhrase, text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .accessibilityIdentifier("settings.delete.confirmField")
                Button(role: .destructive, action: onConfirm) {
                    Text(StudyTypedDeletion.confirmButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!phraseMatches)
                .accessibilityIdentifier("settings.delete.confirmButton")
                Button("Cancel", action: onCancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(theme.palette.ink))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.12), radius: 24, y: 8)
            .accessibilityElement(children: .contain)
        }
        .onAppear {
            typed = ""
            focused = true
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(50)
    }
}

enum StudyPreviewText {
    static func truncatedInsight(_ insight: String, limit: Int = 140) -> String {
        let trimmed = insight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

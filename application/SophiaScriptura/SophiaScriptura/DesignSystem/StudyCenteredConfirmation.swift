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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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

enum StudyPreviewText {
    static func truncatedInsight(_ insight: String, limit: Int = 140) -> String {
        let trimmed = insight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

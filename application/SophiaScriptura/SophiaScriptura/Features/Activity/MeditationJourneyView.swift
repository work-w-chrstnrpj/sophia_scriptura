import SwiftUI

struct MeditationJourneyView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var coordinator: MeditationJourneyCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// ~1.5 in at 72 pt per inch (logical typography points).
    private static let sideInset: CGFloat = 108

    var body: some View {
        ZStack {
            Color(theme.palette.paper).ignoresSafeArea()
            if coordinator.isLoading {
                ProgressView("Preparing meditation…")
                    .font(.headline)
                    .foregroundStyle(Color(theme.palette.ink))
            } else if !coordinator.pages.isEmpty {
                TabView(selection: Binding(
                    get: { coordinator.pageIndex },
                    set: { coordinator.handlePageChange($0) }
                )) {
                    ForEach(coordinator.pages) { page in
                        pageView(page)
                            .tag(page.id)
                            .padding(.vertical, 48)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("meditation.journey.pager")
            }
            closeButton
            if showsSwipeHint {
                swipeHint
            }
        }
        .accessibilityIdentifier("meditation.journey.overlay")
    }

    private var showsSwipeHint: Bool {
        guard coordinator.pages.indices.contains(coordinator.pageIndex) else { return false }
        return coordinator.pages[coordinator.pageIndex].kind == .intro
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    coordinator.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                        .frame(width: 44, height: 44)
                        .background(Color(theme.palette.soft), in: Circle())
                }
                .accessibilityLabel("Exit meditation")
                .accessibilityIdentifier("meditation.journey.close")
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var swipeHint: some View {
        HStack {
            Spacer()
            MeditationSwipeHint()
                .foregroundStyle(Color(theme.palette.secondary))
                .padding(.trailing, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func pageView(_ page: MeditationJourneyPage) -> some View {
        switch page.kind {
        case .intro:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    Text("Meditate with the word")
                        .font(.system(size: 51, design: .serif).weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("&  presence of God")
                        .font(.system(size: 51, design: .serif).weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color(theme.palette.ink))
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Meditate with the word and presence of God")
                .accessibilityIdentifier("meditation.journey.intro")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Self.sideInset)
        case .scripture(let reference, let lines):
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 0)
                        Text(reference)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(theme.palette.secondary))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        VStack(spacing: 16) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                meditationScriptureLine(line)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Self.sideInset)
        case .closing:
            VStack(spacing: 24) {
                Spacer(minLength: 0)
                Text("God is with you. Pray & talk to Him.")
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(theme.palette.ink))
                    .accessibilityIdentifier("meditation.journey.closing")
                Text("Swipe to return")
                    .font(.subheadline)
                    .foregroundStyle(Color(theme.palette.secondary))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Self.sideInset)
        case .exit:
            Color.clear
                .onAppear { coordinator.dismiss() }
        }
    }

    private func meditationScriptureLine(_ line: MeditationScriptureLine) -> Text {
        let bodyFont = Font.system(size: 34, design: .serif)
        let ink = Color(theme.palette.ink)
        guard let number = line.verseNumber else {
            return Text(line.text).font(bodyFont).foregroundStyle(ink)
        }
        let superscript = ScriptureVerseNumberStyle.swiftUISuperscript(number, bodySize: 34)
        return Text(verbatim: String(number))
            .font(superscript.font)
            .baselineOffset(superscript.baselineOffset)
            .foregroundStyle(ink)
        + Text(" ")
        + Text(line.text)
            .font(bodyFont)
            .foregroundStyle(ink)
    }
}

private struct MeditationSwipeHint: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Text("›")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .opacity(phase ? (index == 2 ? 1 : 0.35) : (index == 0 ? 1 : 0.35))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

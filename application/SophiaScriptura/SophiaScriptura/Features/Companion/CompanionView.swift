import SwiftUI

/// Companion tab. Phase 5 adds the BYOK multi-provider LLM adapter, guardrailed prompt
/// presets, streaming chat, and the ASK-from-scripture flow with verse auto-linking.
struct CompanionView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Companion",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("The guardrailed AI study companion (bring-your-own-key) arrives in Phase 5.")
            )
            .navigationTitle("Companion")
        }
    }
}

#Preview {
    CompanionView()
}

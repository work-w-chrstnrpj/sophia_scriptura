import SwiftUI

struct ActivityInsightsSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ActivityStore
    @ObservedObject var sophy: SophySession
    @ObservedObject var companion: CompanionSession
    @State private var period: ActivityAnalyticsPeriod = .week
    @State private var anchorDate = Date()
    @State private var modeID = "all"
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Range") {
                    Picker("Period", selection: $period) {
                        ForEach(ActivityAnalyticsPeriod.allCases) { item in
                            Text(item.title.capitalized).tag(item)
                        }
                    }
                    DatePicker("Anchor date", selection: $anchorDate, displayedComponents: .date)
                }
                Section("Activity type") {
                    Picker("Mode", selection: $modeID) {
                        Text("All modes").tag("all")
                        ForEach(store.modes) { mode in
                            Text(mode.name).tag(mode.id)
                        }
                    }
                }
                Section {
                    Text("Your companion will read aggregate study time for this range (not individual titles), compare it to your \(store.goalMinutes)-minute daily goal where relevant, and offer humble tips for stronger biblical habits.")
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            .navigationTitle("Study insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ask \(sophy.character.displayName)") { Task { await submit() } }
                        .disabled(working || !sophy.preferences.enabled)
                }
            }
            .alert("Insights", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func submit() async {
        guard sophy.preferences.enabled else {
            errorMessage = "Turn on your study companion in Settings first."
            return
        }
        working = true
        defer { working = false }
        dismiss()
        await sophy.presentActivityInsights(
            period: period,
            anchorDate: anchorDate,
            modeID: modeID == "all" ? nil : modeID,
            dailyGoalMinutes: store.goalMinutes,
            companion: companion,
            activity: store
        )
    }
}

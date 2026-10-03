import SwiftUI

struct ActivityTodayDetailView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ActivityStore
    @State private var editingGoals = false
    @State private var detent: PresentationDetent = .height(430)
    @State private var goalDrafts: [String: String] = [:]

    private var today: Date { Date() }
    private var todayMinutes: Int { Int(ActivityMetrics.seconds(on: today, records: store.records) / 60) }
    private var displayModes: [ActivityMode] {
        var result = store.modes
        for record in store.records where !result.contains(where: { $0.id == record.modeID })
            && ActivityMetrics.seconds(on: today, records: [record]) > 0 {
            result.append(ActivityMode(id: record.modeID, name: record.modeLabel, archived: true))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(today.formatted(date: .complete, time: .omitted))
                            .font(.subheadline).foregroundStyle(Color(theme.palette.secondary))
                        Text("\(todayMinutes) of \(store.goalMinutes) mins")
                            .font(.system(.title, design: .serif).weight(.semibold))
                            .monospacedDigit()
                        ProgressView(value: min(1, Double(todayMinutes) / Double(store.goalMinutes)))
                            .tint(Color(theme.palette.accent))
                        let currentStreak = max(1, ActivityMetrics.streak(through: today,
                            records: store.records, goalMinutes: store.goalMinutes))
                        let bestStreak = ActivityMetrics.bestStreak(records: store.records,
                            goalMinutes: store.goalMinutes)
                        HStack(spacing: 20) {
                            Label("Current streak \(currentStreak)", systemImage: "flame")
                            Label("Best \(bestStreak)", systemImage: "star")
                        }
                        .font(.caption)
                        .foregroundStyle(Color(theme.palette.secondary))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 18))

                    Text("By activity type")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    ForEach(displayModes) { mode in
                        modeProgress(mode)
                    }
                }
                .frame(maxWidth: 720)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .appSurface()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button {
                        if editingGoals {
                            guard let goals = parsedGoals(), store.setModeGoals(goals) else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                editingGoals = false
                                detent = .height(430)
                            }
                        } else {
                            goalDrafts = Dictionary(uniqueKeysWithValues: store.modes.map {
                                let goal = store.goalMinutes(for: $0.id)
                                return ($0.id, goal == 0 ? "" : String(goal))
                            })
                            withAnimation(.easeInOut(duration: 0.2)) {
                                editingGoals = true
                                detent = .large
                            }
                        }
                    } label: {
                        Label(editingGoals ? "Save goals" : "Adjust goals",
                              systemImage: editingGoals ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color(theme.palette.paper))
                    .accessibilityIdentifier("activity.today.expandGoals")
                }
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Color(theme.palette.paper))
            }
            .alert("Activity", isPresented: Binding(get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
        }
        .presentationDetents([.height(430), .large], selection: $detent)
    }

    private func modeProgress(_ mode: ActivityMode) -> some View {
        let minutes = Int(ActivityMetrics.seconds(on: today,
            records: store.records.filter { $0.modeID == mode.id }) / 60)
        let goal = store.goalMinutes(for: mode.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mode.name).font(.headline)
                Spacer()
                Text(goal > 0 ? "\(minutes) of \(goal) min" : "\(minutes) min · No goal")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            ProgressView(value: goal > 0 ? min(1, Double(minutes) / Double(goal)) : 0)
                .tint(Color(theme.palette.accent))
            if editingGoals && !mode.archived {
                HStack {
                    Text("Daily goal").font(.subheadline)
                    Spacer()
                    TextField("0", text: Binding(
                        get: { goalDrafts[mode.id] ?? "" },
                        set: { goalDrafts[mode.id] = $0 }))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("activity.goal.\(mode.id)")
                    Text("min").font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(theme.palette.rule), lineWidth: 1))
    }

    private func parsedGoals() -> [String: Int]? {
        var values: [String: Int] = [:]
        for mode in store.modes {
            let text = (goalDrafts[mode.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = text.isEmpty ? 0 : Int(text),
                  (0...1440).contains(value) else {
                store.errorMessage = "Enter a goal from 0 to 1,440 minutes for each activity type."
                return nil
            }
            values[mode.id] = value
        }
        return values
    }
}

import SwiftUI

struct HealthOverview: View {
    let account: AccountStore
    @State private var date: Date

    init(account: AccountStore, date: Date = .now) {
        self.account = account
        _date = State(initialValue: min(date, .now))
    }

    var body: some View {
        List {
            Section {
                Text("Your weight and movement, together.")
                    .font(.system(.title2, design: .serif))
                Text("Read weight from your scale via Apple Health, plus steps, workouts, active calories and exercise minutes.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button(account.healthEnabled ? "Refresh Apple Health" : "Connect Apple Health", systemImage: "heart") {
                    Task { await account.connectHealth() }
                }
                .disabled(account.healthLoading || account.userID == nil)
                if account.healthLoading { ProgressView("Reading Apple Health…") }
                Text(account.healthMessage).font(.caption).foregroundStyle(.secondary)
                if let updated = account.healthUpdatedAt {
                    LabeledContent("Last read", value: updated.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                }
                #if targetEnvironment(simulator)
                Text("The Simulator has its own Health database. Your scale and Apple Watch data are only available on your iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
                #endif
            }
            Section {
                DatePicker("Activity date", selection: $date, in: ...Date.now, displayedComponents: .date)
            }
            HealthDaySections(snapshot: account.health, date: date)
            Section("Scale setup") {
                Text("1. Enable Apple Health sharing in your scale's companion app.")
                Text("2. Confirm a measurement appears in Health → Browse → Body Measurements → Weight.")
                Text("3. Connect above and allow Astra to read Weight and the activity categories you want.")
                Text("New measurements appear after the scale app syncs to Health. Astra refreshes when you reopen it, or when you pull to refresh.")
                NavigationLink("Weight history and trends") { WeightJournal(account: account, date: date) }
            }.font(.subheadline)
            Section("Your data") {
                Text("Connect only while signed into your own Astra account. Health records stay on this device and are not sent to Supabase or AI. Astra never writes to Apple Health.")
                Text("To change permissions, open Health → profile → Apps → Diet Astra. No records and denied read access look the same to Astra.")
                if account.healthEnabled {
                    Button("Disconnect Apple Health", role: .destructive) { account.disconnectHealth() }
                }
            }.font(.caption)
        }
        .scrollContentBackground(.hidden).background(AstraStyle.background)
        .navigationTitle("Apple Health").navigationBarTitleDisplayMode(.inline)
        .refreshable { await account.refreshHealth() }
    }
}

private struct HealthDaySections: View {
    let snapshot: HealthSnapshot
    let date: Date
    private var key: String { DayKey.string(date) }
    private var workouts: [HealthWorkout] {
        snapshot.workouts.filter { Calendar.astra.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date }
    }
    private var weight: WeightProgress.Point? {
        snapshot.weights.filter { Calendar.astra.isDate($0.date, inSameDayAs: date) }.max { $0.date < $1.date }
    }
    var body: some View {
        Section("Daily activity · Apple Health") {
            LabeledContent("Steps", value: snapshot.steps[key].map { $0.formatted() } ?? "No data")
            LabeledContent("Active energy", value: snapshot.activeCalories[key].map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "No data")
            LabeledContent("Exercise", value: snapshot.exerciseMinutes[key].map { "\($0.formatted(.number.precision(.fractionLength(0)))) min" } ?? "No data")
            Text("Active energy excludes resting calories. Exercise minutes come from Health and can differ from workout duration.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Weight · Apple Health") {
            if let weight {
                LabeledContent("Latest that day", value: "\(weight.pounds.formatted(.number.precision(.fractionLength(1)))) lb")
                Text(weight.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            } else { Text("No readable weight for this day.").foregroundStyle(.secondary) }
            Text("Manual Astra measurements take priority on the same day in your dashboard and trends.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Workouts · Apple Health") {
            if workouts.isEmpty {
                Text("No readable workouts for this day.").foregroundStyle(.secondary)
            }
            ForEach(workouts) { workout in
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.title).font(.headline)
                    Text("\(workout.date.formatted(date: .omitted, time: .shortened)) · \((workout.duration / 60).formatted(.number.precision(.fractionLength(0)))) min")
                    Text(workout.source).font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
            Text("Shown separately from Astra strength logs so the same session isn't counted twice. Workout duration belongs to its start day.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview("Health activity · sample") {
    NavigationStack {
        List {
            HealthDaySections(snapshot: HealthSnapshot(
                weights: [.init(date: .now, pounds: 160.5)],
                steps: [DayKey.string(.now): 7842], activeCalories: [DayKey.string(.now): 430],
                exerciseMinutes: [DayKey.string(.now): 32],
                workouts: [HealthWorkout(id: UUID(), date: .now, title: "Walking", duration: 1800, source: "Apple Watch")]), date: .now)
        }.navigationTitle("Apple Health")
    }
}

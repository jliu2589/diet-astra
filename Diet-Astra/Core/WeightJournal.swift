import SwiftUI
import Charts

struct WeightJournal: View {
    let account: AccountStore
    var date = Date.now
    @State private var editing: SavedWeight?
    var body: some View {
        List {
            Section {
                if let latest = account.weightProgress.points.max(by: { $0.date < $1.date }) {
                    LabeledContent("Latest", value: "\(latest.pounds.formatted()) lb")
                    Text(latest.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                } else { Text("No measurements yet") }
                if let trend = account.weightProgress.trendWeight { LabeledContent("Recent trend", value: "\(trend.formatted(.number.precision(.fractionLength(1)))) lb") }
                if let rate = account.weightProgress.weeklyRate { LabeledContent("Observed rate", value: "\(rate.formatted(.number.precision(.fractionLength(2)))) lb/week") }
                Text("Trend uses the last seven calendar days with data; rate fits daily averages over the latest 28-day window.").font(.caption).foregroundStyle(.secondary)
            }
            if !account.weightProgress.daily.isEmpty {
                Chart(account.weightProgress.daily, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Weight", point.pounds))
                    PointMark(x: .value("Date", point.date), y: .value("Weight", point.pounds))
                }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 180)
            }
            Section("Manual measurements") {
                ForEach(account.weights.sorted { $0.measured_at > $1.measured_at }) { entry in
                    Button { editing = entry } label: {
                        LabeledContent(entry.measured_at.formatted(date: .abbreviated, time: .shortened), value: "\(entry.pounds.formatted()) lb")
                    }
                }
            }
            Section("Apple Health · read only") {
                NavigationLink("Connect / manage Apple Health") { HealthOverview(account: account, date: date) }
                if account.healthLoading { ProgressView("Reading Apple Health…") }
                Text(account.healthMessage).font(.caption)
                ForEach(Array(account.health.weights.sorted { $0.date > $1.date }.enumerated()), id: \.offset) { _, point in
                    LabeledContent(point.date.formatted(date: .abbreviated, time: .shortened), value: "\(point.pounds.formatted()) lb")
                }
                Text("Edit Health measurements in Apple Health. Astra does not upload them or write manual entries to Health.").font(.caption)
            }
        }.navigationTitle("Weight journal")
            .toolbar { Button("Add", systemImage: "plus") { if let user = account.userID { editing = SavedWeight(user_id: user, measured_at: min(date, .now), pounds: account.weightProgress.points.max(by: { $0.date < $1.date })?.pounds ?? 0) } } }
            .sheet(item: $editing) { WeightEditor(account: account, entry: $0) }
    }
}

struct WeightEditor: View {
    let account: AccountStore
    @State var entry: SavedWeight
    @State private var error: String?
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Measurement", selection: $entry.measured_at, in: ...Date.now)
                HStack { Text("Weight (lb)"); TextField("Weight", value: $entry.pounds, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                if let error { Text(error).foregroundStyle(.red) }
                if account.weights.contains(where: { $0.id == entry.id }) { Button("Delete measurement", role: .destructive) { deleting = true } }
            }.navigationTitle("Weight check-in").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(account.saving) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { do { try await account.saveWeight(entry); dismiss() } catch { self.error = error.localizedDescription } } }.disabled(account.saving || account.loading || !entry.pounds.isFinite || !(1...1500).contains(entry.pounds)) }
                }
                .confirmationDialog("Delete measurement?", isPresented: $deleting) { Button("Delete", role: .destructive) { Task { do { try await account.deleteWeight(entry); dismiss() } catch { self.error = error.localizedDescription } } } }
        }.interactiveDismissDisabled(account.saving)
    }
}

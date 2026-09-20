import Charts
import SwiftUI

struct WeightView: View {
    @State private var store: WeightStore
    @State private var weightText = ""
    @State private var saveError: String?
    @FocusState private var isWeightFocused: Bool

    init(store: WeightStore? = nil) {
        _store = State(initialValue: store ?? WeightStore())
    }

    private var pounds: Double? { WeightStore.parsePounds(weightText) }

    var body: some View {
        NavigationStack {
            List {
                if let loadError = store.loadError {
                    Section("Storage unavailable") {
                        Text(loadError)
                        Button("Try Again") { store.reload() }
                    }
                } else {
                    latestSection
                }

                entrySection

                if !store.entries.isEmpty {
                    Section("Weight over time") {
                        WeightChart(entries: store.entries)
                    }
                    historySection
                } else if store.loadError == nil {
                    ContentUnavailableView(
                        "No weights yet",
                        systemImage: "scalemass",
                        description: Text("Save today's weight to start your history.")
                    )
                }
            }
            .navigationTitle("Weight")
            .scrollDismissesKeyboard(.interactively)
            .alert("Couldn’t save changes", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    @ViewBuilder
    private var latestSection: some View {
        if let latest = store.latest {
            Section("Latest measurement") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(latest.pounds.formatted(.number.precision(.fractionLength(0...2)))) lb")
                        .font(.largeTitle.bold())
                    Text(latest.date.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var entrySection: some View {
        Section {
            HStack {
                TextField("Weight in pounds", text: $weightText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused($isWeightFocused)
                    .accessibilityLabel("Today's weight in pounds")
                Text("lb").foregroundStyle(.secondary)
            }
            if !weightText.isEmpty && pounds == nil {
                Text("Enter a number greater than zero, with up to two decimal places.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Save Weight", action: saveWeight)
                .disabled(pounds == nil || store.loadError != nil)
        } header: {
            Text("Today's weight")
        } footer: {
            Text("Each save adds a measurement for today.")
        }
        .disabled(store.loadError != nil)
    }

    private var historySection: some View {
        Section {
            ForEach(store.entries.reversed()) { entry in
                LabeledContent {
                    Text("\(entry.pounds.formatted(.number.precision(.fractionLength(0...2)))) lb")
                } label: {
                    Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                    Text(entry.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteEntries)
            .deleteDisabled(store.loadError != nil)
        } header: {
            Text("History · newest first")
        } footer: {
            Text("Swipe left on a measurement to delete it.")
        }
    }

    private func saveWeight() {
        guard let pounds else { return }
        do {
            try store.add(pounds: pounds)
            weightText = ""
            isWeightFocused = false
        } catch {
            saveError = "Your weight was not saved. Please try again."
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        let history = Array(store.entries.reversed())
        do {
            try store.delete(ids: Set(offsets.map { history[$0].id }))
        } catch {
            saveError = "The measurement was not deleted. Please try again."
        }
    }
}

private struct WeightChart: View {
    let entries: [WeightEntry]

    var body: some View {
        Chart(entries) { entry in
            LineMark(x: .value("Date", entry.date), y: .value("Weight (lb)", entry.pounds))
            PointMark(x: .value("Date", entry.date), y: .value("Weight (lb)", entry.pounds))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxisLabel("lb")
        .frame(height: 200)
        .padding(.vertical, 8)
        .accessibilityLabel("Weight over time in pounds")
    }
}

#Preview("Empty") {
    WeightView(store: WeightStore(fileURL: nil))
}

#Preview("Weight history") {
    WeightView(store: WeightStore(fileURL: nil, initialEntries: (0..<7).map { day in
        WeightEntry(
            date: Calendar.current.date(byAdding: .day, value: day - 6, to: .now)!,
            pounds: [182.4, 182.0, 182.6, 181.8, 181.4, 181.6, 181.2][day]
        )
    }))
}

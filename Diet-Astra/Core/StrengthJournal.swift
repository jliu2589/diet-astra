import SwiftUI

struct StrengthJournal: View {
    let account: AccountStore
    var date = Date.now
    @State private var editing: SavedWorkout?
    var body: some View {
        List {
            if account.workouts.isEmpty { ContentUnavailableView("Your first session", systemImage: "dumbbell", description: Text("Log exercises and sets to build your history.")) }
            ForEach(account.workouts.sorted { $0.day > $1.day }) { workout in
                Button { editing = workout } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(workout.title).font(.headline)
                        Text("\(workout.day) · \(workout.exercises.count) exercises · \(workout.volume.formatted()) lb volume").font(.caption).foregroundStyle(.secondary)
                        Text(workout.exercises.map(\.name).joined(separator: ", ")).font(.subheadline)
                    }
                }
            }
        }.navigationTitle("Strength workouts")
            .toolbar { Button("Log workout", systemImage: "plus") { if let user = account.userID { editing = SavedWorkout(user_id: user, day: DayKey.string(min(date, .now))) } } }
            .sheet(item: $editing) { StrengthEditor(account: account, workout: $0) }
    }
}

struct StrengthEditor: View {
    let account: AccountStore
    @State var workout: SavedWorkout
    @State private var error: String?
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session name", text: $workout.title)
                    DatePicker("Day", selection: Binding(get: { DayKey.date(workout.day) ?? .now }, set: { workout.day = DayKey.string($0) }), in: ...Date.now, displayedComponents: .date)
                }
                ForEach($workout.exercises) { $exercise in
                    Section {
                        TextField("Exercise name", text: $exercise.name)
                        if let previous = previous(exercise.name) { Text(previous).font(.caption).foregroundStyle(.secondary) }
                        ForEach($exercise.sets) { $set in
                            VStack(alignment: .leading) {
                                Stepper("\(set.reps) reps", value: $set.reps, in: 1...100)
                                HStack { Text("Load (lb)"); TextField("Load", value: $set.pounds, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                                Stepper("\(set.rir) reps in reserve", value: $set.rir, in: 0...10)
                                Button("Remove set", role: .destructive) { exercise.sets.removeAll { $0.id == set.id } }
                            }.padding(.vertical, 6)
                        }
                        Button("Add set") { exercise.sets.append(StrengthSet()) }.disabled(exercise.sets.count >= 30)
                        Button("Remove exercise", role: .destructive) { workout.exercises.removeAll { $0.id == exercise.id } }
                    }
                }
                Button("Add exercise", systemImage: "plus") { workout.exercises.append(StrengthExercise()) }.disabled(workout.exercises.count >= 30)
                Text("RIR means repetitions you could still have performed. Volume sums load × reps; use a consistent load convention for each exercise.").font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
                if account.workouts.contains(where: { $0.id == workout.id }) { Button("Delete workout", role: .destructive) { deleting = true } }
            }.navigationTitle("Log workout").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(account.saving) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { do { try await account.saveWorkout(workout); dismiss() } catch { self.error = error.localizedDescription } } }.disabled(!workout.valid || account.saving || account.loading) }
                }
                .confirmationDialog("Delete workout?", isPresented: $deleting) { Button("Delete", role: .destructive) { Task { do { try await account.deleteWorkout(workout); dismiss() } catch { self.error = error.localizedDescription } } } }
        }.interactiveDismissDisabled(account.saving)
    }
    private func previous(_ name: String) -> String? {
        let match = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !match.isEmpty else { return nil }
        for session in account.workouts.filter({ $0.id != workout.id && $0.day <= workout.day }).sorted(by: { $0.day > $1.day }) {
            if let exercise = session.exercises.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == match }) {
                return "Previous (\(session.day)): " + exercise.sets.map { "\($0.reps) × \($0.pounds.formatted()) lb @ \($0.rir) RIR" }.joined(separator: "; ")
            }
        }
        return "No previous sets for this exercise."
    }
}

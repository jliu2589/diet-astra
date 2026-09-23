import SwiftUI

struct GoalsEditor: View {
    let account: AccountStore
    @State private var goals = UserGoals.example
    @State private var error: String?
    @State private var saved = false
    var body: some View {
        Form {
            Section {
                Text("A little intention.\nA lasting difference.").font(.system(.title2, design: .serif))
                Text("Choose your own targets. Initial values are examples, not personalized recommendations.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Body weight") {
                decimal("Target (lb)", value: $goals.target_weight)
                decimal("Change (lb/week)", value: $goals.weekly_rate)
                Text("Negative means loss; positive means gain; zero means maintain. Supported range: −2 to +2 lb/week.").font(.caption)
            }
            Section("Daily nutrition") {
                integer("Calories (kcal)", value: $goals.calories)
                integer("Protein (g)", value: $goals.protein)
                integer("Carbohydrates (g)", value: $goals.carbs)
                integer("Fat (g)", value: $goals.fat)
            }
            Section("Movement") { Stepper("\(goals.workouts) workouts per week", value: $goals.workouts, in: 0...14) }
            if let error { Text(error).foregroundStyle(.red) }
            if saved { Label("Goals saved", systemImage: "checkmark.circle") }
            Button(account.saving ? "Saving…" : "Save goals") { Task { do { try await account.saveGoals(goals); saved = true; error = nil } catch { self.error = error.localizedDescription } } }
                .disabled(!goals.valid || account.saving || account.loading)
            Section("Projection · estimate") {
                if let weight = account.weightProgress.trendWeight {
                    LabeledContent("Trend weight", value: "\(weight.formatted(.number.precision(.fractionLength(1)))) lb")
                    LabeledContent("Target minus trend", value: "\((goals.target_weight - weight).formatted(.number.sign(strategy: .always()).precision(.fractionLength(1)))) lb")
                }
                if let date = account.weightProgress.goalDate(target: goals.target_weight, intendedRate: goals.weekly_rate, now: .now) {
                    LabeledContent("At your intended rate", value: date.formatted(date: .abbreviated, time: .omitted))
                } else { Text("Add a recent weight measurement (within 14 days) and choose a rate toward your target to see a projection.") }
                if let rate = account.weightProgress.weeklyRate {
                    LabeledContent("Observed rate", value: "\(rate.formatted(.number.precision(.fractionLength(2)))) lb/week")
                    if let date = account.weightProgress.goalDate(target: goals.target_weight, intendedRate: rate, now: .now) { LabeledContent("At your observed rate", value: date.formatted(date: .abbreviated, time: .omitted)) }
                }
                Text("A straight-line estimate from recent trend weight, not a promise. Your calorie target does not guarantee this rate.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Maintenance · preliminary") {
                if let calories = account.maintenance.calories {
                    LabeledContent("Estimated maintenance", value: "\(calories) kcal/day")
                    LabeledContent("Target minus estimate", value: "\(goals.calories - calories) kcal/day")
                    let rate = Double(goals.calories - calories) * 7 / 3500
                    if let date = account.weightProgress.goalDate(target: goals.target_weight, intendedRate: rate, now: .now) { LabeledContent("At this calorie target", value: date.formatted(date: .abbreviated, time: .omitted)) }
                }
                Text(account.maintenance.explanation).font(.caption)
            }
        }.navigationTitle("Goals").navigationBarTitleDisplayMode(.inline)
            .onAppear { goals = account.goals ?? UserGoals(user_id: account.userID ?? UUID()) }
            .onChange(of: goals) { _, _ in saved = false }
    }
    private func decimal(_ title: String, value: Binding<Double>) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
    }
    private func integer(_ title: String, value: Binding<Int>) -> some View {
        HStack { Text(title); Spacer(); TextField(title, value: value, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
    }
}

struct AccountSettings: View {
    let account: AccountStore
    @State private var name = ""
    @State private var message: String?
    @State private var signingOut = false
    var body: some View {
        Form {
            Section("Profile") {
                Text(account.email).textSelection(.enabled)
                TextField("Display name", text: $name)
                Button("Save name") { Task { do { try await account.saveName(name); message = "Profile saved." } catch { message = error.localizedDescription } } }.disabled(account.saving || account.loading || name.count > 100)
            }
            Section("Apple Health") {
                NavigationLink("Weight, steps & activity") { HealthOverview(account: account) }
                Text(account.healthMessage).font(.caption)
            }
            Section("Privacy") {
                Text("Your confirmed records are stored in your private Supabase account. Photos are used for analysis and discarded by Astra; no photo library is stored. OpenAI receives only the meal text/photo you explicitly submit. Provider retention policies still apply.").font(.caption)
                Text("There is no offline save queue. Failed saves keep your editor open so you can retry. Signing out clears all loaded records from memory.").font(.caption)
            }
            if let message { Text(message).font(.caption) }
            if let error = account.error { Text(error).foregroundStyle(.red) }
            Button("Refresh account data") { Task { await account.reload() } }.disabled(account.loading || account.saving)
            Button("Sign out", role: .destructive) { signingOut = true }.disabled(account.saving)
        }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline).onAppear { name = account.name }
            .confirmationDialog("Sign out of this device?", isPresented: $signingOut) { Button("Sign out", role: .destructive) { Task { await account.signOut() } } }
    }
}

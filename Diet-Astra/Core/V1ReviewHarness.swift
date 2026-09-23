#if DEBUG
import SwiftUI

// Explicit UI-test entry point. No authenticated session, fixture backend, or successful fake saves.
struct V1ReviewHarness: View {
    @State private var account = AccountStore()
    @State private var meal: SavedMeal?
    @State private var weight: SavedWeight?
    @State private var workout: SavedWorkout?
    @State private var composer = false
    @State private var photo = false
    private let user = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var body: some View {
        NavigationStack {
            List {
                Button("Review meal editor") { meal = SavedMeal(user_id: user, day: DayKey.string(.now), occurred_at: .now, title: "Lunch", foods: [FoodItem(name: "Rice", grams: 250, calories: 325, protein: 6.75, carbs: 70, fat: 0.75)], note: "Verify cooked portion", estimated: true) }
                Button("Review weight editor") { weight = SavedWeight(user_id: user, measured_at: .now, pounds: 150) }
                Button("Review workout editor") { workout = SavedWorkout(user_id: user, day: DayKey.string(.now)) }
                Button("Review text composer") { composer = true }
                Button("Review photo composer") { photo = true }
                NavigationLink("Review goals") { GoalsEditor(account: account) }
                NavigationLink("Review Apple Health") { HealthOverview(account: account) }
                NavigationLink("Review settings") { AccountSettings(account: account) }
            }.navigationTitle("V1 UI checks")
        }.sheet(item: $meal) { MealEditor(account: account, meal: $0) }
            .sheet(item: $weight) { WeightEditor(account: account, entry: $0) }
            .sheet(item: $workout) { StrengthEditor(account: account, workout: $0) }
            .sheet(isPresented: $composer) { LiveMealComposer(account: account, date: .now) }
            .sheet(isPresented: $photo) { LiveMealComposer(account: account, date: .now, photoMode: true) }
    }
}
#endif

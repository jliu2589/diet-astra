import SwiftUI
import Observation
import Supabase

private struct AccountKey: EnvironmentKey { static let defaultValue: AccountStore? = nil }
extension EnvironmentValues {
    var accountStore: AccountStore? { get { self[AccountKey.self] } set { self[AccountKey.self] = newValue } }
}

@MainActor @Observable
final class AccountStore {
    let backend = Backend.configured()
    let diary = DemoDiary(seedSamples: false)
    var userID: UUID?
    var email = ""
    var name = ""
    var goals: UserGoals?
    var meals: [SavedMeal] = []
    var weights: [SavedWeight] = []
    var workouts: [SavedWorkout] = []
    var completed: Set<String> = []
    var authBusy = false
    var loading = false
    var saving = false
    var error: String?
    var healthLoading = false
    private(set) var healthEnabled = false
    private(set) var healthUpdatedAt: Date?
    var healthMessage = "Apple Health is not connected."
    private(set) var health = HealthSnapshot()
    private let healthService = HealthService()
    private var saveToken: UUID?
    private var generation = UUID()
    private var healthGeneration = UUID()
    var weightProgress: WeightProgress {
        WeightProgress(points: WeightProgress.merging(manual: weights.map { .init(date: $0.measured_at, pounds: $0.pounds) }, health: health.weights, calendar: .astra), calendar: .astra)
    }
    var maintenance: MaintenanceEstimate {
        let intake = Dictionary(grouping: meals, by: \.day).mapValues { $0.reduce(0) { $0 + $1.totals.calories } }
        return .calculate(weights: weightProgress.points, intake: intake, complete: completed, now: .now)
    }
    func observeSession() async {
        guard let backend else { return }
        for await (_, session) in backend.client.auth.authStateChanges {
            if Task.isCancelled { return }
            let next = session?.user.id
            if next != userID {
                clear()
                userID = next
                email = session?.user.email ?? ""
                if let next {
                    healthEnabled = UserDefaults.standard.bool(forKey: "astra.health.enabled.\(next.uuidString)")
                    await reload()
                    await refreshHealth()
                }
            }
        }
    }
    func signIn(email: String, password: String) async {
        guard let backend else { return }
        authBusy = true; error = nil
        do { _ = try await backend.client.auth.signIn(email: email, password: password) }
        catch { self.error = "Sign-in failed. Check your email, password, and connection." }
        authBusy = false
    }
    func signOut() async {
        guard !saving else { return }
        do { try await backend?.client.auth.signOut(scope: .local); clear() }
        catch { self.error = "Could not sign out. Please try again." }
    }
    private func clear() {
        generation = UUID(); userID = nil; email = ""; name = ""; goals = nil
        meals = []; weights = []; workouts = []; completed = []; health = HealthSnapshot()
        healthLoading = false; healthEnabled = false; healthUpdatedAt = nil
        healthMessage = "Apple Health is not connected."; error = nil
        diary.goals = .example; diary.replaceRecords([:]); loading = false
        saveToken = nil; saving = false
    }
    func reload() async {
        guard let backend, let userID, !loading, !saving else { return }
        rebuild()
        let token = generation
        loading = true; error = nil
        defer { if token == generation { loading = false } }
        do {
            let m: [SavedMeal] = try await backend.rows("astra_meals", user: userID)
            let w: [SavedWeight] = try await backend.rows("astra_weights", user: userID)
            let t: [SavedWorkout] = try await backend.rows("astra_workouts", user: userID)
            let g: [UserGoals] = try await backend.rows("astra_goals", user: userID, order: "user_id")
            let p: [UserProfile] = try await backend.rows("astra_profiles", user: userID, order: "user_id")
            let c: [NutritionDay] = try await backend.rows("astra_nutrition_days", user: userID, order: "day")
            guard token == generation else { return }
            meals = m; weights = w; workouts = t; goals = g.first; name = p.first?.name ?? ""
            completed = Set(c.filter(\.complete).map(\.day)); rebuild()
        } catch { if token == generation { self.error = AppFailure.unavailable.localizedDescription } }
    }
    // Saves are serialized; caller keeps its draft on failure and UUIDs make retries idempotent.
    func saveMeal(_ meal: SavedMeal) async throws {
        guard meal.valid else { throw AppFailure.invalid }
        let previousDay = meals.first { $0.id == meal.id }?.day
        try await mutate(user: meal.user_id) { backend in try await backend.save(meal, table: "astra_meals") }
        completed.remove(meal.day); if let previousDay { completed.remove(previousDay) }
        meals.removeAll { $0.id == meal.id }; meals.append(meal); rebuild()
    }
    func deleteMeal(_ meal: SavedMeal) async throws {
        try await mutate(user: meal.user_id) { try await $0.delete(meal.id, table: "astra_meals", user: meal.user_id) }
        completed.remove(meal.day)
        meals.removeAll { $0.id == meal.id }; rebuild()
    }
    func saveWeight(_ weight: SavedWeight) async throws {
        guard weight.pounds.isFinite, (1...1500).contains(weight.pounds), weight.measured_at <= .now else { throw AppFailure.invalid }
        try await mutate(user: weight.user_id) { try await $0.save(weight, table: "astra_weights") }
        weights.removeAll { $0.id == weight.id }; weights.append(weight); rebuild()
    }
    func deleteWeight(_ weight: SavedWeight) async throws {
        try await mutate(user: weight.user_id) { try await $0.delete(weight.id, table: "astra_weights", user: weight.user_id) }
        weights.removeAll { $0.id == weight.id }; rebuild()
    }
    func saveGoals(_ goals: UserGoals) async throws {
        guard goals.valid else { throw AppFailure.invalid }
        try await mutate(user: goals.user_id) { try await $0.save(goals, table: "astra_goals") }
        self.goals = goals; rebuild()
    }
    func saveName(_ name: String) async throws {
        guard let userID, name.count <= 100 else { throw AppFailure.invalid }
        try await mutate(user: userID) { try await $0.save(UserProfile(user_id: userID, name: name), table: "astra_profiles") }
        self.name = name
    }
    func saveWorkout(_ workout: SavedWorkout) async throws {
        guard workout.valid else { throw AppFailure.invalid }
        try await mutate(user: workout.user_id) { try await $0.save(workout, table: "astra_workouts") }
        workouts.removeAll { $0.id == workout.id }; workouts.append(workout); rebuild()
    }
    func deleteWorkout(_ workout: SavedWorkout) async throws {
        try await mutate(user: workout.user_id) { try await $0.delete(workout.id, table: "astra_workouts", user: workout.user_id) }
        workouts.removeAll { $0.id == workout.id }; rebuild()
    }
    func markComplete(_ date: Date, complete: Bool) async throws {
        guard let userID else { throw AppFailure.signedOut }
        let key = DayKey.string(date)
        try await mutate(user: userID) { try await $0.save(NutritionDay(user_id: userID, day: key, complete: complete), table: "astra_nutrition_days") }
        if complete { completed.insert(key) } else { completed.remove(key) }
    }
    private func mutate(user: UUID, operation: (Backend) async throws -> Void) async throws {
        guard user == userID, let backend else { throw AppFailure.signedOut }
        guard !saving && !loading else { throw AppFailure.busy }
        let token = generation
        saving = true
        let operationToken = UUID()
        saveToken = operationToken
        defer { if saveToken == operationToken { saving = false; saveToken = nil } }
        do { try await operation(backend) } catch { throw AppFailure.unavailable }
        guard token == generation && user == userID else { throw AppFailure.signedOut }
    }
    func connectHealth() async { await readHealth(requestPermission: true) }
    func refreshHealth() async {
        guard healthEnabled else { return }
        await readHealth(requestPermission: false)
    }
    private func readHealth(requestPermission: Bool) async {
        let token = generation
        guard let userID, !healthLoading else { return }
        guard HealthService.available else {
            healthMessage = "Apple Health is unavailable on this device. Use your iPhone to connect."
            return
        }
        healthLoading = true
        healthGeneration = UUID()
        let healthToken = healthGeneration
        defer { if token == generation && healthToken == healthGeneration { healthLoading = false } }
        do {
            let snapshot = try await healthService.read(requestPermission: requestPermission)
            guard token == generation && healthToken == healthGeneration else { return }
            health = snapshot
            healthEnabled = true
            healthUpdatedAt = .now
            UserDefaults.standard.set(true, forKey: "astra.health.enabled.\(userID.uuidString)")
            healthMessage = "Showing available records from the past year. Missing data can mean no records or access is off."
            rebuild()
        } catch {
            if token == generation && healthToken == healthGeneration {
                healthMessage = "Refresh failed. Previously loaded Health data may be out of date. Unlock your iPhone and check access in Apple Health, then retry."
            }
        }
    }
    func disconnectHealth() {
        if let userID { UserDefaults.standard.removeObject(forKey: "astra.health.enabled.\(userID.uuidString)") }
        healthGeneration = UUID(); healthLoading = false; healthEnabled = false; healthUpdatedAt = nil
        health = HealthSnapshot()
        healthMessage = "Apple Health is disconnected in Astra. Manage read permissions in the Health app."
        rebuild()
    }
    private func rebuild() {
        var records: [Date: DemoDay] = [:]
        let calendar = Calendar.astra
        func date(_ key: String) -> Date? { DayKey.date(key) }
        for meal in meals {
            guard let d = date(meal.day) else { continue }
            let n = meal.totals
            records[d, default: DemoDay(date: d)].meals.append(MealPreview(id: meal.id, title: meal.title, detail: meal.foods.map(\.name).joined(separator: ", "), date: meal.occurred_at, calories: Int(n.calories.rounded()), protein: Int(n.protein.rounded()), carbs: Int(n.carbs.rounded()), fat: Int(n.fat.rounded()), isEstimate: meal.estimated))
        }
        for (key, group) in Dictionary(grouping: meals, by: \.day) {
            if let d = date(key) { records[d]?.exactNutrition = NutritionTotals(foods: group.flatMap(\.foods)) }
        }
        // Manual measurements override Health for that day; Health remains read-only.
        for point in weightProgress.points.sorted(by: { $0.date < $1.date }) {
            let d = calendar.startOfDay(for: point.date)
            records[d, default: DemoDay(date: d)].weight = point.pounds
        }
        for workout in workouts {
            guard let d = date(workout.day) else { continue }
            records[d, default: DemoDay(date: d)].workout = workout.title
            records[d, default: DemoDay(date: d)].volume += Int(workout.volume.rounded())
            records[d, default: DemoDay(date: d)].workoutCount += 1
        }
        for (key, steps) in health.steps {
            guard let d = date(key) else { continue }; records[d, default: DemoDay(date: d)].steps = steps
        }
        for key in records.keys { records[key]?.meals.sort { $0.date < $1.date } }
        diary.goals = goals ?? .example
        diary.replaceRecords(records)
    }
}

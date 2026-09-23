import Foundation

nonisolated struct FoodItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var grams = 100.0
    // Nutrients are for this entire portion, not per 100 g.
    var calories = 0.0
    var protein = 0.0
    var carbs = 0.0
    var fat = 0.0
    var source = "Manual"
    var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200 &&
        grams.isFinite && grams >= 0.001 && grams <= 10000 &&
        [calories, protein, carbs, fat].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 20000 }
    }
}

nonisolated struct SavedMeal: Codable, Identifiable {
    var id = UUID()
    var user_id: UUID
    var day: String
    var occurred_at: Date
    var title: String
    var foods: [FoodItem]
    var note: String
    var estimated: Bool
    var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 200 && note.count <= 4000 && !foods.isEmpty && foods.count <= 50 && foods.allSatisfy(\.valid) }
    var totals: NutritionTotals { NutritionTotals(foods: foods) }
}

nonisolated struct NutritionTotals: Equatable {
    var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
    init(foods: [FoodItem]) {
        for food in foods { calories += food.calories; protein += food.protein; carbs += food.carbs; fat += food.fat }
    }
}

nonisolated struct SavedWeight: Codable, Identifiable {
    var id = UUID()
    var user_id: UUID
    var measured_at: Date
    var pounds: Double
}

nonisolated struct UserGoals: Codable, Equatable {
    var user_id: UUID
    var target_weight: Double = 140
    var calories: Int = 2500
    var protein: Int = 150
    var carbs: Int = 300
    var fat: Int = 70
    var workouts: Int = 4
    // Signed pounds per week: negative means loss.
    var weekly_rate: Double = -0.5
    var valid: Bool {
        target_weight.isFinite && (40...1000).contains(target_weight) && (800...10000).contains(calories) &&
        [protein, carbs, fat].allSatisfy { (1...1000).contains($0) } && (0...14).contains(workouts) &&
        weekly_rate.isFinite && (-2...2).contains(weekly_rate)
    }
    static var example: UserGoals { UserGoals(user_id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!) }
}

nonisolated struct UserProfile: Codable { var user_id: UUID; var name: String }
nonisolated struct NutritionDay: Codable { var user_id: UUID; var day: String; var complete: Bool }

nonisolated struct StrengthSet: Codable, Identifiable, Equatable {
    var id = UUID()
    var reps = 8
    var pounds = 0.0
    var rir = 2
    var valid: Bool { (1...100).contains(reps) && pounds.isFinite && (0...2000).contains(pounds) && (0...10).contains(rir) }
}
nonisolated struct StrengthExercise: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var sets = [StrengthSet()]
    var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 && !sets.isEmpty && sets.count <= 30 && sets.allSatisfy(\.valid) }
}
nonisolated struct SavedWorkout: Codable, Identifiable {
    var id = UUID()
    var user_id: UUID
    var day: String
    var title = "Strength workout"
    var exercises = [StrengthExercise()]
    var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 200 && !exercises.isEmpty && exercises.count <= 30 && exercises.allSatisfy(\.valid) }
    var volume: Double { exercises.flatMap(\.sets).reduce(0) { $0 + Double($1.reps) * $1.pounds } }
}

extension Calendar {
    nonisolated static var astra: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}

nonisolated enum DayKey {
    static func string(_ date: Date, calendar: Calendar = .astra) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    static func date(_ key: String, calendar: Calendar = .astra) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])), string(date, calendar: calendar) == key else { return nil }
        return date
    }
}

nonisolated enum AppFailure: LocalizedError {
    case invalid, signedOut, unavailable, busy
    var errorDescription: String? {
        switch self {
        case .invalid: "Please check the values before saving."
        case .signedOut: "Sign in again to continue."
        case .unavailable: "Could not complete that request. Check your connection and try again. Your edits have not been discarded."
        case .busy: "Another save is in progress. Please wait."
        }
    }
}

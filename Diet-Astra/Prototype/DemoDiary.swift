import Foundation
import Observation

enum ReviewPeriod: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", month = "Month"
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self { case .day: .day; case .week: .weekOfYear; case .month: .month }
    }
}

struct MealPreview: Identifiable {
    var id = UUID()
    let title: String
    let detail: String
    let date: Date
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    var isEstimate = false
    var photoData: Data?
    var hasPhoto = false
}

struct DemoDay: Identifiable {
    let date: Date
    var meals: [MealPreview] = []
    var weight: Double?
    var steps = 0
    var workout: String?
    var volume = 0
    var workoutCount = 0
    var exactNutrition: NutritionTotals? = nil
    var id: Date { date }
    var calories: Int { exactNutrition.map { Int($0.calories.rounded()) } ?? meals.reduce(0) { $0 + $1.calories } }
    var protein: Int { exactNutrition.map { Int($0.protein.rounded()) } ?? meals.reduce(0) { $0 + $1.protein } }
    var carbs: Int { exactNutrition.map { Int($0.carbs.rounded()) } ?? meals.reduce(0) { $0 + $1.carbs } }
    var fat: Int { exactNutrition.map { Int($0.fat.rounded()) } ?? meals.reduce(0) { $0 + $1.fat } }
    var hasNutrition: Bool { !meals.isEmpty }
}

struct ReviewSummary {
    let days: [DemoDay]
    var loggedDays: [DemoDay] { days.filter(\.hasNutrition) }
    func average(_ value: KeyPath<DemoDay, Int>) -> Int {
        guard !loggedDays.isEmpty else { return 0 }
        return Int((Double(loggedDays.reduce(0) { $0 + $1[keyPath: value] }) / Double(loggedDays.count)).rounded())
    }
    var weights: [Double] { days.compactMap(\.weight) }
    var averageWeight: Double? {
        weights.isEmpty ? nil : weights.reduce(0, +) / Double(weights.count)
    }
    var weightChange: Double? {
        guard weights.count > 1, let first = weights.first, let last = weights.last else { return nil }
        return last - first
    }
    var workouts: Int { days.reduce(0) { $0 + max($1.workoutCount, $1.workout == nil ? 0 : 1) } }
    var volume: Int { days.reduce(0) { $0 + $1.volume } }
}

@MainActor
@Observable
final class DemoDiary {
    var goals = UserGoals.example
    let isDemo: Bool
    var today: Date
    private(set) var records: [Date: DemoDay] = [:]
    let calendar: Calendar

    init(now: Date = .now, calendar: Calendar = .astra, seedSamples: Bool = true) {
        isDemo = seedSamples
        self.calendar = calendar
        today = calendar.startOfDay(for: now)
        guard seedSamples else { return }
        for offset in 0..<366 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            func meal(_ title: String, _ detail: String, _ hour: Int, _ kcal: Int, _ p: Int, _ c: Int, _ f: Int) -> MealPreview {
                MealPreview(title: title, detail: detail,
                            date: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!,
                            calories: kcal, protein: p, carbs: c, fat: f)
            }
            var meals = [
                meal("Breakfast", "Eggs, oats & blueberries", 8, 360, 24, 44, 10),
                meal("Lunch", "Chicken, rice & greens", 12, 540, 36, 61, 17)
            ]
            if offset > 0 {
                meals.append(meal("Dinner", offset % 2 == 0 ? "Salmon, potatoes & asparagus" : "Steak, potatoes & broccoli",
                                  19, 780 + offset % 4 * 165, 52, 84, 26))
                meals.append(meal("Snack", "Greek yogurt, banana & almonds", 16, 370 + offset % 3 * 40, 30, 38, 12))
            }
            let weekday = calendar.component(.weekday, from: date)
            let training = [2, 3, 5, 7].contains(weekday)
            records[date] = DemoDay(date: date, meals: meals.sorted { $0.date < $1.date },
                                   weight: offset % 5 == 2 ? nil : 147.2 + Double(offset) * 0.035 + (offset == 0 ? 0 : sin(Double(offset)) * 0.35),
                                   steps: offset == 0 ? 7_842 : 6_800 + (offset * 397) % 5_000,
                                   workout: training ? (weekday % 2 == 0 ? "Upper body" : "Lower body") : nil,
                                   volume: training ? 8_400 + (offset % 7) * 320 : 0)
        }
    }

    func replaceRecords(_ newRecords: [Date: DemoDay]) {
        records = newRecords
        today = calendar.startOfDay(for: .now)
    }

    func day(_ date: Date) -> DemoDay {
        let key = calendar.startOfDay(for: date)
        return records[key] ?? DemoDay(date: key)
    }

    func days(_ period: ReviewPeriod, containing date: Date) -> [DemoDay] {
        if period == .week { return mondayWeek(containing: date) }
        guard let interval = calendar.dateInterval(of: period.component, for: date) else { return [] }
        var result: [DemoDay] = []
        var cursor = interval.start
        while cursor < interval.end {
            result.append(day(cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    func mondayWeek(containing date: Date) -> [DemoDay] {
        let dayStart = calendar.startOfDay(for: date)
        let daysSinceMonday = (calendar.component(.weekday, from: dayStart) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: dayStart)!
        return (0..<7).map { day(calendar.date(byAdding: .day, value: $0, to: monday)!) }
    }

    func addMeal(text: String, on date: Date, photo: Bool, photoData: Data? = nil) {
        let key = calendar.startOfDay(for: date)
        var record = day(key)
        let hour = calendar.component(.hour, from: .now)
        let minute = calendar.component(.minute, from: .now)
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: key) ?? key
        record.meals.append(MealPreview(title: photo ? "Photo meal" : "Meal", detail: text.isEmpty ? "Chicken, rice & vegetables" : text,
                                       date: time, calories: 620, protein: 42, carbs: 65, fat: 21, isEstimate: true, photoData: photoData, hasPhoto: photo))
        record.meals.sort { $0.date < $1.date }
        records[key] = record
    }

    func setWeight(_ pounds: Double, on date: Date) {
        let key = calendar.startOfDay(for: date)
        var record = day(key)
        record.weight = pounds
        records[key] = record
    }
}

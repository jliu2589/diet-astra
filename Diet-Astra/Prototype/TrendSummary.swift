import Foundation

struct TrendSummary {
    var goals = UserGoals.example
    var complete: Set<String>? = nil
    var calorieTarget: Int { goals.calories }
    let days: [DemoDay]
    let today: Date
    let calendar: Calendar

    // Exclude today's unfinished log and missing days from target comparisons.
    var completedDays: [DemoDay] { days.filter { $0.date < today && $0.hasNutrition && (complete == nil || complete!.contains(DayKey.string($0.date, calendar: calendar))) } }
    var below: Int { completedDays.filter { $0.calories < calorieTarget }.count }
    var above: Int { completedDays.filter { $0.calories > calorieTarget }.count }
    var onTarget: Int { completedDays.filter { $0.calories == calorieTarget }.count }

    struct Point: Identifiable {
        let date: Date
        let metric: String
        let percent: Double
        var id: String { "\(date.timeIntervalSince1970)-\(metric)" }
    }

    var combined: [Point] {
        let weeks = Dictionary(grouping: days) { calendar.dateInterval(of: .weekOfYear, for: $0.date)!.start }
        return weeks.keys.sorted().flatMap { date -> [Point] in
            let summary = ReviewSummary(days: weeks[date]!)
            var points: [Point] = goals.workouts > 0 ? [Point(date: date, metric: "Training", percent: Double(summary.workouts) / Double(goals.workouts) * 100)] : []
            if let weight = summary.averageWeight {
                points.append(Point(date: date, metric: "Weight", percent: weight / goals.target_weight * 100))
            }
            if !summary.loggedDays.isEmpty {
                points.append(Point(date: date, metric: "Calories", percent: Double(summary.average(\.calories)) / Double(calorieTarget) * 100))
            }
            return points
        }
    }
}

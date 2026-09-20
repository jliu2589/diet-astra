import Foundation

struct TrendSummary {
    static let calorieTarget = 2500
    let days: [DemoDay]
    let today: Date
    let calendar: Calendar

    // Exclude today's unfinished log and missing days from target comparisons.
    var completedDays: [DemoDay] { days.filter { $0.date < today && $0.hasNutrition } }
    var below: Int { completedDays.filter { $0.calories < Self.calorieTarget }.count }
    var above: Int { completedDays.filter { $0.calories > Self.calorieTarget }.count }
    var onTarget: Int { completedDays.filter { $0.calories == Self.calorieTarget }.count }

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
            var points = [Point(date: date, metric: "Training", percent: Double(summary.workouts) / 4 * 100)]
            if let weight = summary.averageWeight {
                points.append(Point(date: date, metric: "Weight", percent: weight / 140 * 100))
            }
            if !summary.loggedDays.isEmpty {
                points.append(Point(date: date, metric: "Calories", percent: Double(summary.average(\.calories)) / Double(Self.calorieTarget) * 100))
            }
            return points
        }
    }
}

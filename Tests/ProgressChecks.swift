import Foundation

@main struct ProgressChecks {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        func day(_ i: Int) -> Date { calendar.date(byAdding: .day, value: i, to: start)! }
        let user = UUID()
        let foods = [FoodItem(name: "Rice", grams: 250, calories: 325, protein: 6.75, carbs: 70, fat: 0.75), FoodItem(name: "Chicken", grams: 150, calories: 247.5, protein: 46.5, carbs: 0, fat: 5.4)]
        let meal = SavedMeal(user_id: user, day: DayKey.string(start, calendar: calendar), occurred_at: start, title: "Lunch", foods: foods, note: "", estimated: true)
        precondition(meal.valid && meal.totals.calories == 572.5 && meal.totals.protein == 53.25)
        precondition(!FoodItem(name: "", grams: 100).valid)
        precondition(!FoodItem(name: "x", grams: .nan).valid)
        precondition(!FoodItem(name: "x", calories: -1).valid)
        let encoded = try JSONEncoder().encode(meal)
        let decoded = try JSONDecoder().decode(SavedMeal.self, from: encoded)
        precondition(decoded.id == meal.id && decoded.foods == foods)
        let points = (0..<28).map { WeightProgress.Point(date: day($0), pounds: 180 - Double($0) / 7) }
        let progress = WeightProgress(points: points, calendar: calendar)
        precondition(abs(progress.weeklyRate! + 1) < 0.000001, "Calendar regression survives DST")
        precondition(abs(progress.trendWeight! - (180 - 24.0 / 7)) < 0.000001)
        precondition(WeightProgress(points: Array(points.prefix(6)), calendar: calendar).weeklyRate == nil)
        let merged = WeightProgress.merging(manual: [points[0]], health: [WeightProgress.Point(date: points[0].date, pounds: 999), points[1]], calendar: calendar)
        precondition(merged.count == 2 && !merged.contains { $0.pounds == 999 }, "Manual day overrides Health without duplication")
        precondition(progress.goalDate(target: 160, intendedRate: -1, now: day(60)) == nil, "Stale weight must not imply a current projection")
        let duplicates = WeightProgress(points: points + [points[0]], calendar: calendar)
        precondition(duplicates.daily.count == 28 && abs(duplicates.weeklyRate! + 1) < 0.000001)
        precondition(progress.goalDate(target: 160, intendedRate: -1, now: day(28)) != nil)
        precondition(progress.goalDate(target: 160, intendedRate: 1, now: day(28)) == nil)
        precondition(progress.goalDate(target: 160, intendedRate: 0, now: day(28)) == nil)
        precondition(progress.goalDate(target: .nan, intendedRate: -1, now: day(28)) == nil)
        let keys = (0..<28).map { DayKey.string(day($0), calendar: calendar) }
        let intake = Dictionary(uniqueKeysWithValues: keys.map { ($0, 2000.0) })
        let complete = Set(keys)
        let estimate = MaintenanceEstimate.calculate(weights: points, intake: intake, complete: complete, now: day(28), calendar: calendar)
        precondition(estimate.calories == 2500, "Losing 1 lb/week at 2000 intake implies 2500 approximate maintenance")
        precondition(MaintenanceEstimate.calculate(weights: points, intake: intake, complete: complete.subtracting([keys[5]]), now: day(28), calendar: calendar).calories == nil)
        precondition(MaintenanceEstimate.calculate(weights: Array(points.prefix(8)), intake: intake, complete: complete, now: day(28), calendar: calendar).calories == nil)
        precondition(DayKey.date("2026-02-30", calendar: calendar) == nil)
        precondition(DayKey.date("garbage", calendar: calendar) == nil)
        for i in 0..<40 { precondition(DayKey.date(DayKey.string(day(i), calendar: calendar), calendar: calendar) == day(i)) }
        let workout = SavedWorkout(user_id: user, day: keys[0], exercises: [StrengthExercise(name: "Squat", sets: [StrengthSet(reps: 5, pounds: 100, rir: 2), StrengthSet(reps: 8, pounds: 80, rir: 1)])])
        precondition(workout.valid && workout.volume == 1140)
        precondition(!StrengthSet(reps: 0).valid && !StrengthSet(rir: 11).valid)
        print("Progress checks passed: nutrition totals/round-trip, DST dates, sparse/duplicate weights, trend/rate, projections, maintenance sufficiency, workout volume")
    }
}

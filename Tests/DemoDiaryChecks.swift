import Foundation

@main
struct DemoDiaryChecks {
    @MainActor
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 12))!
        let diary = DemoDiary(now: now, calendar: calendar)
        precondition(diary.records.count == 366)
        for range in [7, 28, 90, 180, 365] {
            let start = calendar.date(byAdding: .day, value: -(range - 1), to: diary.today)!
            let records = diary.records.values.filter { $0.date >= start && $0.date <= diary.today }
            precondition(records.count == range, "Every selectable trend range needs full sample coverage")
        }
        let today = diary.day(now)
        precondition(today.calories == 900 && today.protein == 60 && today.carbs == 105 && today.fat == 27)
        precondition(today.weight == 147.2 && today.steps == 7_842)
        precondition(diary.days(.day, containing: now).count == 1)
        precondition(diary.days(.week, containing: now).count == 7)
        precondition(diary.days(.month, containing: now).count == 30)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        precondition(diary.day(tomorrow).meals.isEmpty && diary.day(tomorrow).weight == nil)
        let summary = ReviewSummary(days: [today, diary.day(tomorrow)])
        precondition(summary.average(\.calories) == 900, "Empty days must not reduce averages")
        precondition(summary.averageWeight == 147.2 && summary.weightChange == nil)
        let earlier = calendar.date(byAdding: .day, value: -1, to: now)!
        let before = diary.day(earlier).calories
        diary.addMeal(text: "A test meal", on: earlier, photo: false)
        precondition(diary.day(earlier).calories == before + 620)
        precondition(diary.day(now).calories == 900, "Meal must be added to selected day")
        diary.addMeal(text: "Rice underneath the chicken", on: now, photo: true)
        precondition(diary.day(now).calories == 1_520, "Photo submission updates the current day")
        precondition(diary.day(now).meals.contains { $0.title == "Photo meal" && $0.detail == "Rice underneath the chicken" })
        let meals = diary.day(earlier).meals
        precondition(meals.map(\.date) == meals.map(\.date).sorted())
        diary.setWeight(146.8, on: tomorrow)
        precondition(diary.day(tomorrow).weight == 146.8)
        let changed = ReviewSummary(days: [today, diary.day(tomorrow)])
        precondition(abs(changed.weightChange! + 0.4) < 0.00001)
        precondition(DemoDiary(now: now, calendar: calendar).day(tomorrow).weight == nil, "Prototype changes must not persist")
        // Calendar arithmetic should retain whole days across daylight saving changes.
        let march = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        precondition(diary.days(.month, containing: march).count == 31)
        let photo = Data([1, 2, 3])
        diary.addMeal(text: "Photo", on: earlier, photo: true, photoData: photo)
        precondition(diary.day(earlier).meals.contains { $0.hasPhoto && $0.photoData == photo })
        precondition(diary.day(tomorrow).meals.filter(\.hasPhoto).isEmpty)
        let trends = TrendSummary(days: Array(diary.records.values), today: diary.today, calendar: calendar)
        precondition(trends.below > 0 && trends.above > 0)
        precondition(trends.below + trends.above + trends.onTarget == trends.completedDays.count)
        precondition(!trends.completedDays.contains { $0.date == diary.today })
        precondition(Set(trends.combined.map(\.metric)) == Set(["Weight", "Calories", "Training"]))
        precondition(trends.combined.allSatisfy { $0.percent.isFinite })
        let targetDays = [2499, 2500, 2501].enumerated().map { index, calories in
            let date = calendar.date(byAdding: .day, value: -index - 1, to: diary.today)!
            let meal = MealPreview(title: "Test", detail: "", date: date, calories: calories, protein: 0, carbs: 0, fat: 0)
            return DemoDay(date: date, meals: [meal])
        }
        let targetCheck = TrendSummary(days: targetDays + [diary.day(now), diary.day(tomorrow)], today: diary.today, calendar: calendar)
        precondition(targetCheck.below == 1 && targetCheck.above == 1 && targetCheck.onTarget == 1)
        for date in [now, march, tomorrow] {
            let week = diary.mondayWeek(containing: date)
            precondition(week.count == 7)
            precondition(calendar.component(.weekday, from: week.first!.date) == 2)
            precondition(calendar.component(.weekday, from: week.last!.date) == 1)
            precondition(week.contains { calendar.isDate($0.date, inSameDayAs: date) })
        }
        print("All demo diary checks passed.")
    }
}

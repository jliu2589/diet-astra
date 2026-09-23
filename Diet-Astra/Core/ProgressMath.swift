import Foundation

nonisolated struct WeightProgress {
    struct Point { let date: Date; let pounds: Double }
    static func merging(manual: [Point], health: [Point], calendar: Calendar) -> [Point] {
        let manualDays = Set(manual.map { calendar.startOfDay(for: $0.date) })
        return manual + health.filter { !manualDays.contains(calendar.startOfDay(for: $0.date)) }
    }
    let points: [Point]
    let calendar: Calendar
    // Collapse multiple measurements into a daily average before fitting a line.
    var daily: [Point] {
        Dictionary(grouping: points.filter { $0.pounds.isFinite && $0.pounds > 0 }) { calendar.startOfDay(for: $0.date) }
            .map { Point(date: $0.key, pounds: $0.value.reduce(0) { $0 + $1.pounds } / Double($0.value.count)) }.sorted { $0.date < $1.date }
    }
    var weeklyRate: Double? {
        guard let last = daily.last else { return nil }
        let windowStart = calendar.date(byAdding: .day, value: -27, to: last.date)!
        let recent = daily.filter { $0.date >= windowStart }
        guard let first = recent.first, recent.count >= 7,
              calendar.dateComponents([.day], from: first.date, to: last.date).day! >= 13 else { return nil }
        let xs = recent.map { Double(calendar.dateComponents([.day], from: first.date, to: $0.date).day!) }
        let ys = recent.map(\.pounds)
        let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
        let denominator = xs.reduce(0) { $0 + pow($1 - mx, 2) }
        guard denominator > 0 else { return nil }
        return zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) } / denominator * 7
    }
    var trendWeight: Double? {
        guard let last = daily.last else { return nil }
        let recent = daily.filter { calendar.dateComponents([.day], from: $0.date, to: last.date).day! < 7 }
        return recent.reduce(0) { $0 + $1.pounds } / Double(recent.count)
    }
    func goalDate(target: Double, intendedRate: Double, now: Date) -> Date? {
        guard let last = daily.last, last.date <= now,
              calendar.dateComponents([.day], from: last.date, to: now).day! <= 14,
              let current = trendWeight, target.isFinite, intendedRate.isFinite, abs(intendedRate) > 0,
              (target - current) * intendedRate > 0 else { return nil }
        let days = (target - current) / intendedRate * 7
        guard days > 0 && days <= 3650 else { return nil }
        return calendar.date(byAdding: .day, value: Int(ceil(days)), to: now)
    }
}

nonisolated struct MaintenanceEstimate {
    let calories: Int?
    let explanation: String
    static func calculate(weights: [WeightProgress.Point], intake: [String: Double], complete: Set<String>, now: Date, calendar: Calendar = .astra) -> Self {
        // A continuous 28-day interval avoids treating unlogged food as zero intake.
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -28, to: end)!
        let dates = (0..<28).map { calendar.date(byAdding: .day, value: $0, to: start)! }
        guard dates.allSatisfy({ complete.contains(DayKey.string($0, calendar: calendar)) && (intake[DayKey.string($0, calendar: calendar)] ?? 0) >= 500 }) else {
            return Self(calories: nil, explanation: "Learning: mark 28 consecutive past days of food logs complete. No estimate is shown for incomplete intake.")
        }
        let usable = weights.filter { $0.date >= start && $0.date < end }
        let progress = WeightProgress(points: usable, calendar: calendar)
        guard progress.daily.count >= 14, let first = progress.daily.first, let last = progress.daily.last,
              calendar.dateComponents([.day], from: first.date, to: last.date).day! >= 21,
              let rate = progress.weeklyRate, abs(rate) <= 2 else {
            return Self(calories: nil, explanation: "Learning: need at least 14 weight days spanning three weeks, without a rapid weight change.")
        }
        let average = dates.reduce(0.0) { $0 + intake[DayKey.string($1, calendar: calendar)]! } / 28
        let value = average - rate * 3500 / 7
        guard value.isFinite, (800...6000).contains(value) else { return Self(calories: nil, explanation: "The observations are inconsistent. Check food portions and weight measurements.") }
        return Self(calories: Int(value.rounded()), explanation: "Preliminary estimate from 28 complete food logs and weight trend. Water shifts, logging errors and metabolic changes limit accuracy; this is not a calorie prescription.")
    }
}

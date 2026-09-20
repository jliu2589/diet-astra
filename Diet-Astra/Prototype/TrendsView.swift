import Charts
import SwiftUI

private enum TrendMetric: String, CaseIterable, Identifiable {
    case weight = "Weight", calories = "Calories", training = "Training", all = "All"
    var id: String { rawValue }
    var unit: String {
        switch self { case .weight: "lb"; case .calories: "kcal / day"; case .all: "% of goal"; case .training: "workouts" }
    }
}

private struct TrendPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct TrendsView: View {
    let diary: DemoDiary
    @State private var metric = TrendMetric.weight
    @State private var range = 28
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rangeLabel: String {
        switch range {
        case 7: "1 week"
        case 28: "4 weeks"
        case 90: "3 months"
        case 180: "6 months"
        default: "1 year"
        }
    }

    private var axisStride: Int {
        switch range {
        case 7: 1
        case 28: 7
        case 90: 28
        case 180: 56
        default: 84
        }
    }

    private var days: [DemoDay] {
        if metric == .training && range == 7 { return diary.mondayWeek(containing: diary.today) }
        let start = diary.calendar.date(byAdding: .day, value: -(range - 1), to: diary.today)!
        return diary.records.values.filter { $0.date >= start && $0.date <= diary.today }.sorted { $0.date < $1.date }
    }
    private var points: [TrendPoint] {
        switch metric {
        case .weight: return days.compactMap { day in day.weight.map { TrendPoint(date: day.date, value: $0) } }
        case .calories: return days.filter(\.hasNutrition).map { TrendPoint(date: $0.date, value: Double($0.calories)) }
        case .all: return []
        case .training:
            let weeks = Dictionary(grouping: days) { diary.calendar.dateInterval(of: .weekOfYear, for: $0.date)!.start }
            return weeks.map { TrendPoint(date: $0.key, value: Double($0.value.filter { $0.workout != nil }.count)) }.sorted { $0.date < $1.date }
        }
    }
    private var headline: String {
        if metric == .all { return "Together" }
        if metric == .weight { return (points.last?.value ?? 0).formatted(.number.precision(.fractionLength(1))) }
        if metric == .training { return days.filter { $0.workout != nil }.count.formatted() }
        let summary = ReviewSummary(days: days)
        return summary.average(\.calories).formatted()
    }
    private var description: String {
        switch metric {
        case .weight:
            let change = (points.last?.value ?? 0) - (points.first?.value ?? 0)
            return "\(change.formatted(.number.sign(strategy: .always()).precision(.fractionLength(1)))) lb across this period"
        case .calories: return "Average intake · goal 2,500 kcal per day"
        case .all: return "Weekly averages and workout totals · % of each goal"
        case .training: return "Sessions completed · goal 4 per week"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("THE LONG VIEW").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                    Text("Small steps.\nA clearer picture.").font(.system(size: 34, weight: .regular, design: .serif))
                }
                Picker("Metric", selection: $metric) {
                    ForEach(TrendMetric.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                    .accessibilityIdentifier("trendMetric")
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(metric == .all ? "Your trends together" : metric == .weight ? "Latest weight" : metric == .training ? "Workout frequency" : "Daily average")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Picker("Time range", selection: $range) {
                            Text("1 week").tag(7)
                            Text("4 weeks").tag(28)
                            Text("3 months").tag(90)
                            Text("6 months").tag(180)
                            Text("1 year").tag(365)
                        }.pickerStyle(.menu).font(.caption)
                            .accessibilityIdentifier("trendRange")
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(headline).font(.system(size: 48, weight: .regular, design: .serif)).monospacedDigit()
                        Text(metric.unit).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(description).font(.subheadline).foregroundStyle(AstraStyle.accent)
                    if metric == .all {
                        combinedChart.frame(height: 220).padding(.top, 12)
                    } else if metric == .training && range == 7 {
                        dailyTrainingChart.frame(height: 220).padding(.top, 12)
                    } else {
                        mainChart.frame(height: 220).padding(.top, 12)
                    }
                    Text(metric == .all ? "100% = 140 lb, 2,500 kcal/day, or 4 workouts/week. Edge weeks may be partial. These are relative goals, not a shared unit." : metric == .training ? (range == 7 ? "This week · Monday–Sunday. One bar per day; remaining days are empty." : "Weekly totals. The first and last weeks may be partial.") : "\(points.count) sample measurements · \(rangeLabel)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Divider()
                calorieBalance
                if metric == .training {
                    strengthChart
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric == .weight ? "Look at the direction." : "Consistency, over time.")
                            .font(.system(.title3, design: .serif))
                        Text(metric == .weight ? "Daily changes are easier to put in context when you can see several weeks together." : "Each point is a logged day. Today's partial intake is included; days without logs are excluded.")
                            .font(.subheadline).foregroundStyle(.secondary).lineSpacing(4)
                    }
                }
                Text("Sample analytics · no health data connected")
                    .font(.caption2).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
            }.padding(22)
        }
        .background(AstraStyle.background)
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: metric)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: range)
    }

    private var dailyTrainingChart: some View {
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return Chart(Array(days.enumerated()), id: \.element.id) { index, day in
            BarMark(x: .value("Day", weekdays[index]),
                    y: .value("Workouts", day.workout == nil ? 0 : 1), width: .ratio(0.65))
                .foregroundStyle(AstraStyle.accent).cornerRadius(4)
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                .accessibilityValue(day.date > diary.today ? "Upcoming" : day.workout == nil ? "Rest day" : "1 workout")
        }
        .chartXScale(domain: weekdays)
        .chartXAxis { AxisMarks(values: weekdays) { _ in AxisValueLabel() } }
        .chartYScale(domain: 0...1)
        .chartYAxis { AxisMarks(values: [0, 1]) }
        .accessibilityIdentifier("dailyTrainingChart")
        .accessibilityLabel("Daily workouts, Monday through Sunday")
    }

    private var mainChart: some View {
        Chart {
            ForEach(points) { point in
                if metric == .training {
                    BarMark(x: .value("Week", point.date, unit: .weekOfYear), y: .value("Workouts", point.value))
                        .foregroundStyle(AstraStyle.accent).cornerRadius(4)
                } else {
                    LineMark(x: .value("Date", point.date), y: .value(metric.rawValue, point.value))
                        .foregroundStyle(AstraStyle.accent).lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            if metric == .calories || metric == .training {
                RuleMark(y: .value("Goal", metric == .calories ? 2500 : 4))
                    .foregroundStyle(.secondary.opacity(0.4)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: .automatic(includesZero: metric != .weight))
        .chartXAxis {
            if metric == .training {
                // Weekly bars expand the domain to whole weeks; daily ticks overcrowd short ranges.
                AxisMarks(values: .stride(by: .weekOfYear, count: max(1, axisStride / 7))) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: axisStride)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
        .accessibilityLabel("\(metric.rawValue) over \(rangeLabel)")
    }

    private var summary: TrendSummary {
        TrendSummary(days: days, today: diary.today, calendar: diary.calendar)
    }

    private var combinedChart: some View {
        Chart {
            ForEach(summary.combined) { point in
                LineMark(x: .value("Week", point.date), y: .value("Percent of goal", point.percent))
                    .foregroundStyle(by: .value("Metric", point.metric))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Week", point.date), y: .value("Percent of goal", point.percent))
                    .foregroundStyle(by: .value("Metric", point.metric))
            }
            RuleMark(y: .value("Goal", 100)).foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(dash: [4, 4]))
        }
        .chartForegroundStyleScale(["Weight": AstraStyle.accent, "Calories": Color.orange, "Training": Color.blue])
        .chartYAxisLabel("% of goal")
        .accessibilityIdentifier("combinedTrends")
        .accessibilityLabel("Weight, calories, and training as percentages of their goals")
    }

    private var calorieBalance: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Calories vs. target", detail: rangeLabel)
            Text("\(summary.below) below · \(summary.above) above · \(summary.onTarget) on target")
                .font(.subheadline).accessibilityIdentifier("calorieBalanceCounts")
            Chart {
                ForEach(summary.completedDays) { day in
                    BarMark(x: .value("Day", day.date, unit: .day),
                            y: .value("Calories from target", day.calories - TrendSummary.calorieTarget))
                        .foregroundStyle(day.calories > TrendSummary.calorieTarget ? Color.orange : AstraStyle.accent)
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(abs(day.calories - TrendSummary.calorieTarget)) calories \(day.calories > TrendSummary.calorieTarget ? "above" : "below") target")
                }
                RuleMark(y: .value("Target", 0)).foregroundStyle(.secondary)
            }
            .frame(height: 170)
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: axisStride)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
            .chartYAxisLabel("kcal from target")
            .accessibilityIdentifier("calorieBalanceChart")
            HStack {
                Label("Below", systemImage: "circle.fill").foregroundStyle(AstraStyle.accent)
                Label("Above", systemImage: "circle.fill").foregroundStyle(.orange)
            }.font(.caption)
            Text("Daily bars relative to 2,500 kcal. Today's unfinished log and days without meals are excluded. Sample data.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var strengthChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Strength, steadily", detail: "Squat · 5 reps")
            Text("135 lb").font(.system(.title, design: .serif))
            Text("Sample top set · \(rangeLabel)").font(.caption).foregroundStyle(.secondary)
            Chart((0..<6).map { index in
                let daysAgo = (5 - index) * (range - 1) / 5
                return TrendPoint(date: diary.calendar.date(byAdding: .day, value: -daysAgo, to: diary.today)!,
                                  value: 135 - Double(daysAgo) * 0.06)
            }) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight (lb)", point.value)).foregroundStyle(AstraStyle.accent)
                PointMark(x: .value("Date", point.date), y: .value("Weight (lb)", point.value)).foregroundStyle(AstraStyle.accent)
            }
            .chartYScale(domain: 100...145).frame(height: 140)
            .accessibilityLabel("Sample squat strength progression over \(rangeLabel)")
        }
    }
}

#Preview("Trends") {
    NavigationStack { TrendsView(diary: DemoDiary()) }.tint(AstraStyle.accent)
}

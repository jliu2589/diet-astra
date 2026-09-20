import Charts
import SwiftUI

struct TodayView: View {
    let diary: DemoDiary
    @State private var selectedDate = Date.now
    @State private var period = ReviewPeriod.day
    @State private var showingCalendar = false
    @State private var showingWeight = false
    @State private var selectedMeal: MealPreview?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var day: DemoDay { diary.day(selectedDate) }
    private var summary: ReviewSummary { ReviewSummary(days: diary.days(period, containing: selectedDate)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                dateHeader
                if period == .day {
                    NutritionSummaryView(calories: day.calories, protein: day.protein, carbs: day.carbs, fat: day.fat)
                    weightRow
                    mealGallery
                    mealList
                    activityRow
                } else {
                    periodReview
                }
                Text("Sample data · for design review")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.top, 4)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 16)
        }
        .background(AstraStyle.background)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if period == .day {
                MealEntryDock(diary: diary, date: selectedDate)
                    .id(diary.calendar.startOfDay(for: selectedDate))
            }
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarNavigationView(date: $selectedDate, period: $period)
        }
        .sheet(isPresented: $showingWeight) {
            DemoWeightSheet(diary: diary, date: selectedDate)
        }
        .sheet(item: $selectedMeal) { meal in MealDetailView(meal: meal) }
    }

    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(period == .day ? (diary.calendar.isDateInToday(selectedDate) ? "YOUR DAY, AT A GLANCE" : "DAILY REVIEW") : "\(period.rawValue.uppercased())LY REVIEW")
                .font(.caption2.weight(.semibold)).tracking(1.6).foregroundStyle(.secondary)
            HStack(spacing: 0) {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Previous \(period.rawValue.lowercased())")
                Button { showingCalendar = true } label: {
                    VStack(spacing: 3) {
                        Text(dateTitle).font(.system(.title3, design: .serif).weight(.medium))
                            .multilineTextAlignment(.center)
                        if period != .day {
                            Text(period.rawValue + " view").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(dateTitle). Open calendar")
                .accessibilityIdentifier("reviewDate")
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("Next \(period.rawValue.lowercased())")
            }
            .foregroundStyle(.primary).buttonStyle(.plain)
            if !diary.calendar.isDateInToday(selectedDate) || period != .day {
                Button("Back to today") { selectedDate = .now; period = .day }
                    .font(.caption).frame(maxWidth: .infinity, minHeight: 32)
            }
        }
    }

    private var dateTitle: String {
        switch period {
        case .day: selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .week:
            if let first = summary.days.first, let last = summary.days.last {
                first.date.formatted(.dateTime.month(.abbreviated).day()) + " – " + last.date.formatted(.dateTime.month(.abbreviated).day().year())
            } else { "This week" }
        case .month: selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }

    private func move(_ amount: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            selectedDate = diary.calendar.date(byAdding: period.component, value: amount, to: selectedDate) ?? selectedDate
        }
    }

    private var weightRow: some View {
        Button { showingWeight = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "scalemass").font(.title3).foregroundStyle(AstraStyle.accent)
                    .frame(width: 42, height: 42).background(AstraStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body weight").font(.subheadline.weight(.medium))
                    Text(day.weight == nil ? "A small check-in. A clearer picture." : "Daily check-in · sample")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if let weight = day.weight {
                    Text("\(weight.formatted(.number.precision(.fractionLength(1)))) lb")
                        .font(.system(.title3, design: .serif)).monospacedDigit()
                } else {
                    Image(systemName: "plus").frame(width: 30, height: 44)
                }
            }
            .foregroundStyle(.primary).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.weight == nil ? "Add weight for selected day" : "Update sample weight for selected day")
        .accessibilityIdentifier("weightCheckIn")
    }

    private var mealGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Meal photos", detail: "\(day.meals.filter(\.hasPhoto).count) photos")
            if day.meals.allSatisfy({ !$0.hasPhoto }) {
                Text("Your meal photos for this day will appear here. Tap the camera to add one.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(day.meals.filter(\.hasPhoto)) { meal in
                            Button { selectedMeal = meal } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    MealPhotoView(data: meal.photoData).frame(width: 130, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(meal.date, format: .dateTime.hour().minute()).font(.caption)
                                }
                            }.buttonStyle(.plain)
                                .accessibilityLabel("View meal photo at \(meal.date.formatted(date: .omitted, time: .shortened))")
                                .accessibilityIdentifier("mealPhotoThumbnail")
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
    }

    private var mealList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Meals", detail: "\(day.meals.count) logged")
                .padding(.bottom, 4)
            if day.meals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A fresh page.").font(.system(.title3, design: .serif))
                    Text("Tap + below to add your first meal.").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 18)
            }
            ForEach(day.meals) { meal in
                Button { selectedMeal = meal } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Text(meal.date, format: .dateTime.hour().minute())
                            .font(.caption2).foregroundStyle(.secondary).frame(width: 53, alignment: .leading).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(meal.title).font(.subheadline.weight(.semibold))
                            Text(meal.detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            Text("\(meal.calories) kcal · \(meal.protein) g protein")
                                .font(.caption).foregroundStyle(AstraStyle.accent)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 5)
                    }
                    .padding(.vertical, 14).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider()
            }
        }
    }

    private var activityRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Movement")
            HStack {
                Label("\(day.steps.formatted()) steps", systemImage: "figure.walk")
                Spacer()
                Text(day.workout == nil ? "Rest day" : "1 workout").foregroundStyle(.secondary)
            }.font(.subheadline)
            if let workout = day.workout {
                HStack {
                    Label(workout, systemImage: "dumbbell")
                    Spacer()
                    Text("\(day.volume.formatted()) lb lifted").foregroundStyle(.secondary)
                }.font(.caption)
            }
        }
    }

    private var periodReview: some View {
        VStack(alignment: .leading, spacing: 24) {
            NutritionSummaryView(calories: summary.average(\.calories), protein: summary.average(\.protein),
                                 carbs: summary.average(\.carbs), fat: summary.average(\.fat), averaged: true)
            Text("Based on \(summary.loggedDays.count) days with meals logged. Empty days are excluded from averages.")
                .font(.caption).foregroundStyle(.secondary)
            if summary.loggedDays.isEmpty {
                ContentUnavailableView("Nothing logged yet", systemImage: "calendar", description: Text("Choose an earlier period to explore your sample history."))
            } else {
                SectionHeading(title: "Daily intake", detail: "kcal")
                Chart(summary.loggedDays) { day in
                    BarMark(x: .value("Date", day.date, unit: .day), y: .value("Calories", day.calories))
                        .foregroundStyle(AstraStyle.accent.opacity(0.7)).cornerRadius(3)
                }.frame(height: 140).accessibilityLabel("Daily calorie intake for selected period")
                Divider()
                SectionHeading(title: "The bigger picture")
                HStack(alignment: .top) {
                    summaryMetric("Average weight", summary.averageWeight.map { $0.formatted(.number.precision(.fractionLength(1))) + " lb" } ?? "—")
                    Spacer()
                    summaryMetric("Weight change", summary.weightChange.map { $0.formatted(.number.sign(strategy: .always()).precision(.fractionLength(1))) + " lb" } ?? "—")
                }
                Divider()
                HStack(alignment: .top) {
                    summaryMetric("Workouts", "\(summary.workouts)")
                    Spacer()
                    summaryMetric("Total volume", "\(summary.volume.formatted()) lb")
                }
                Text("Weight change compares the first and last recorded measurements. Volume is total weight × reps across sample workouts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func summaryMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .serif))
        }
    }
}

struct DemoWeightSheet: View {
    let diary: DemoDiary
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section(date.formatted(date: .complete, time: .omitted)) {
                    HStack {
                        TextField("Weight", text: $text).keyboardType(.decimalPad).focused($focused)
                            .accessibilityIdentifier("mockWeight")
                        Text("lb").foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Save sample weight") {
                        if let pounds = WeightStore.parsePounds(text) { diary.setWeight(pounds, on: date); dismiss() }
                    }.disabled(WeightStore.parsePounds(text) == nil)
                } footer: { Text("This updates the UI demo only. Your saved weight journal is separate.") }
            }
            .navigationTitle("Weight check-in").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                if let weight = diary.day(date).weight { text = weight.formatted(.number.precision(.fractionLength(1))) }
                focused = true
            }
        }.presentationDetents([.medium])
    }
}

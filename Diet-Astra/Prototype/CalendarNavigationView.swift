import SwiftUI

struct CalendarNavigationView: View {
    @Binding var date: Date
    @Binding var period: ReviewPeriod
    @Environment(\.dismiss) private var dismiss
    @State private var month: Date
    @State private var choice: Date
    @State private var mode: ReviewPeriod
    private let calendar = Calendar.current

    init(date: Binding<Date>, period: Binding<ReviewPeriod>) {
        _date = date; _period = period
        _month = State(initialValue: date.wrappedValue)
        _choice = State(initialValue: date.wrappedValue)
        _mode = State(initialValue: period.wrappedValue)
    }

    private var weeks: [[Date]] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let start = calendar.dateInterval(of: .weekOfYear, for: interval.start)?.start else { return [] }
        var rows: [[Date]] = []
        var cursor = start
        while cursor < interval.end {
            rows.append((0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: cursor) })
            cursor = calendar.date(byAdding: .day, value: 7, to: cursor)!
        }
        return rows
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Picker("Review period", selection: $mode) {
                        ForEach(ReviewPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack {
                        Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                            .accessibilityLabel("Previous month")
                        Spacer()
                        Text(month, format: .dateTime.month(.wide).year()).font(.title3.weight(.semibold))
                        Spacer()
                        Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                            .accessibilityLabel("Next month")
                    }
                    VStack(spacing: 4) {
                        HStack(spacing: 0) {
                            ForEach(0..<7) { index in
                                Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                                    .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                            }
                            if mode == .week { Color.clear.frame(width: 44, height: 12) }
                        }
                        ForEach(weeks, id: \.first) { week in
                            HStack(spacing: 0) {
                                ForEach(week, id: \.self) { day in
                                    Button {
                                        choice = day
                                        if !calendar.isDate(day, equalTo: month, toGranularity: .month) { month = day }
                                    } label: {
                                        Text(day, format: .dateTime.day())
                                            .font(.subheadline.weight(calendar.isDateInToday(day) ? .bold : .regular))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .foregroundStyle(isSelected(day) ? AstraStyle.background : Color.primary)
                                            .background(isSelected(day) ? AstraStyle.accent : .clear, in: RoundedRectangle(cornerRadius: mode == .day ? 22 : 6))
                                            .opacity(calendar.isDate(day, equalTo: month, toGranularity: .month) ? 1 : 0.35)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                                    .accessibilityAddTraits(isSelected(day) ? .isSelected : [])
                                }
                                if mode == .week {
                                    Button { choice = week[0] } label: {
                                        Image(systemName: "arrow.right").font(.caption).frame(width: 44, height: 44)
                                    }.accessibilityLabel("Select week of \(week[0].formatted(date: .abbreviated, time: .omitted))")
                                }
                            }
                        }
                    }
                    Text(mode == .day ? "Choose a date to revisit your day." : mode == .week ? "Tap a day or row arrow to select its week." : "Browse a month, then open its summary.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Show \(mode.rawValue.lowercased())") {
                        date = mode == .month ? month : choice
                        period = mode
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                    Button("Jump to today") { month = .now; choice = .now; mode = .day }
                        .frame(minHeight: 44)
                }.padding(20)
            }
            .background(AstraStyle.background)
            .navigationTitle("Your timeline").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
    }

    private func isSelected(_ day: Date) -> Bool {
        if mode == .month { return calendar.isDate(day, equalTo: month, toGranularity: .month) }
        return calendar.isDate(day, equalTo: choice, toGranularity: mode.component)
    }

    private func moveMonth(_ amount: Int) {
        month = calendar.date(byAdding: .month, value: amount, to: month) ?? month
        choice = calendar.dateInterval(of: .month, for: month)?.start ?? month
    }
}

#Preview("Week selection") {
    CalendarNavigationView(date: .constant(.now), period: .constant(.week)).tint(AstraStyle.accent)
}

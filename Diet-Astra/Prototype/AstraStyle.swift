import SwiftUI

// A small palette shared by the prototype, with explicit light and dark colors.
enum AstraStyle {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.65, green: 0.80, blue: 0.68, alpha: 1)
        : UIColor(red: 0.24, green: 0.39, blue: 0.30, alpha: 1)
    })
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.075, green: 0.085, blue: 0.08, alpha: 1)
        : UIColor(red: 0.975, green: 0.972, blue: 0.957, alpha: 1)
    })
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct RoundButton: View {
    let symbol: String
    let label: String
    var prominent = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 23 : 18, weight: .medium))
                .frame(width: prominent ? 58 : 44, height: prominent ? 58 : 44)
                .foregroundStyle(prominent ? AstraStyle.background : Color.primary)
                .background(prominent ? AstraStyle.accent : AstraStyle.surface, in: Circle())
                .overlay(Circle().strokeBorder(.primary.opacity(0.06)))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct NutritionSummaryView: View {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    var averaged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(averaged ? "DAILY AVERAGE" : "NOURISHMENT")
                    .font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Text(averaged ? "per logged day" : "Daily goal").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    calorieNumber
                    VStack(alignment: .leading, spacing: 2) {
                        Text(calories.formatted()).font(.system(size: 52, weight: .regular, design: .serif))
                        Text("/ 2,500 kcal").foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: min(Double(calories) / 2_500, 1))
                    .tint(AstraStyle.accent)
                    .accessibilityLabel("Calories, \(calories) of 2500 kilocalories")
            }
            HStack(alignment: .top, spacing: 18) {
                macro("Protein", protein, 150, emphasized: true)
                macro("Carbs", carbs, 300)
                macro("Fat", fat, 70)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(AstraStyle.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var calorieNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(calories.formatted()).font(.system(size: 52, weight: .regular, design: .serif)).monospacedDigit()
            Text("/ 2,500 kcal").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func macro(_ name: String, _ value: Int, _ goal: Int, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text("\(value) g").font(.headline).monospacedDigit()
            ProgressView(value: min(Double(value) / Double(goal), 1))
                .tint(emphasized ? AstraStyle.accent : AstraStyle.accent.opacity(0.45))
            Text("of \(goal) g").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(value) of \(goal) grams")
    }
}

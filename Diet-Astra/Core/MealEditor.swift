import SwiftUI

struct MealEditor: View {
    let account: AccountStore
    @State var meal: SavedMeal
    var existing = false
    @State private var error: String?
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Meal name", text: $meal.title)
                    DatePicker("Date", selection: Binding(get: { DayKey.date(meal.day) ?? .now }, set: { meal.day = DayKey.string($0) }), in: ...Date.now, displayedComponents: .date)
                    DatePicker("Time", selection: $meal.occurred_at, displayedComponents: .hourAndMinute)
                    Toggle("Includes estimated nutrition", isOn: $meal.estimated)
                }
                ForEach($meal.foods) { $food in
                    Section {
                        TextField("Food", text: $food.name)
                        number("Portion (g)", value: $food.grams)
                        number("Calories (kcal)", value: $food.calories)
                        number("Protein (g)", value: $food.protein)
                        number("Carbohydrates (g)", value: $food.carbs)
                        number("Fat (g)", value: $food.fat)
                        Text(food.source).font(.caption).foregroundStyle(.secondary)
                        Button("Remove food", role: .destructive) { meal.foods.removeAll { $0.id == food.id } }
                    } footer: { Text("Nutrition values are for the whole portion. Changing grams does not automatically change these values; update them together.") }
                }
                Button("Add food", systemImage: "plus") { meal.foods.append(FoodItem()) }.disabled(meal.foods.count >= 50)
                Section("Meal totals") {
                    LabeledContent("Calories", value: "\(meal.totals.calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                    Text("\(meal.totals.protein.formatted()) g protein · \(meal.totals.carbs.formatted()) g carbs · \(meal.totals.fat.formatted()) g fat").font(.caption)
                    TextField("Notes or assumptions", text: $meal.note, axis: .vertical)
                    if meal.estimated { Text("Review foods, portions and nutrition before saving. Photo and AI estimates can be inaccurate.").font(.caption).foregroundStyle(.secondary) }
                }
                if let error { Text(error).foregroundStyle(.red) }
                if existing { Button("Delete meal", role: .destructive) { deleting = true }.disabled(account.saving) }
            }
            .scrollContentBackground(.hidden).background(AstraStyle.background)
            .navigationTitle(existing ? "Edit meal" : "Review meal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(account.saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(account.saving ? "Saving…" : "Save") {
                        Task {
                            do {
                                let time = Calendar.current.dateComponents([.hour, .minute], from: meal.occurred_at)
                                if let day = DayKey.date(meal.day) { meal.occurred_at = Calendar.current.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: day) ?? day }
                                try await account.saveMeal(meal); dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }.disabled(!meal.valid || account.saving || account.loading)
                }
            }
            .confirmationDialog("Delete this meal?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete meal", role: .destructive) { Task { do { try await account.deleteMeal(meal); dismiss() } catch { self.error = error.localizedDescription } } }
            }
        }.interactiveDismissDisabled(account.saving)
    }
    private func number(_ label: String, value: Binding<Double>) -> some View {
        HStack { Text(label); Spacer(); TextField(label, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
    }
}

struct LiveMealComposer: View {
    let account: AccountStore
    let date: Date
    var photoMode = false
    @State private var text = ""
    @State private var photo: Data?
    @State private var loadingPhoto = false
    @State private var error: String?
    @State private var busy = false
    @State private var dictating = false
    @State private var draft: SavedMeal?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if photoMode {
                        if let photo { MealPhotoView(data: photo).frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 18)) }
                        else { ContentUnavailableView("Add a meal photo", systemImage: "camera", description: Text("Take a photo or choose one from your library.")) }
                        MealPhotoSource(photoData: $photo, loading: $loadingPhoto, errorMessage: $error)
                    }
                    Text(photoMode ? "Anything else to know?" : "What did you eat?").font(.system(.title2, design: .serif))
                    TextField(photoMode ? "Portions, ingredients, or what you left" : "200g steak, rice and broccoli", text: $text, axis: .vertical).lineLimit(3...8)
                        .padding().background(AstraStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                    Button("Dictate", systemImage: "mic") { dictating = true }
                    Text("Analyze sends this text\(photoMode ? " and photo" : "") to our secure server and OpenAI. Review the estimate before saving. Astra does not retain photos.").font(.caption).foregroundStyle(.secondary)
                    if busy { ProgressView("Interpreting your meal…") }
                    if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
                    Button("Analyze and review") { Task { await analyze() } }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(busy || loadingPhoto || (photoMode ? photo == nil : text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    Button("Enter foods and nutrition manually") { makeManual() }.disabled(busy)
                }.padding(22).disabled(busy)
            }.scrollDismissesKeyboard(.interactively).background(AstraStyle.background)
                .navigationTitle(photoMode ? "Photo meal" : "Add meal").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
        }
        .interactiveDismissDisabled(busy)
        .sheet(isPresented: $dictating) { DictationView { text = $0 } }
        .sheet(item: $draft, onDismiss: { if let id = savedDraftID, account.meals.contains(where: { $0.id == id }) { dismiss() } }) { meal in
            MealEditor(account: account, meal: meal)
        }
    }
    @State private var savedDraftID: UUID?
    private func makeManual() {
        guard let user = account.userID else { return }
        let meal = SavedMeal(user_id: user, day: DayKey.string(date), occurred_at: date, title: "Meal", foods: [FoodItem()], note: text, estimated: false)
        savedDraftID = meal.id; draft = meal
    }
    private func analyze() async {
        guard let backend = account.backend, let user = account.userID, !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let result = try await backend.interpret(text: text, photo: photo)
            guard account.userID == user else { return }
            let meal = SavedMeal(user_id: user, day: DayKey.string(date), occurred_at: date, title: result.title, foods: result.foods, note: result.note, estimated: true)
            savedDraftID = meal.id; draft = meal
        } catch { self.error = "Could not interpret this meal. Try a clearer description, check your connection, or enter nutrition manually." }
    }
}

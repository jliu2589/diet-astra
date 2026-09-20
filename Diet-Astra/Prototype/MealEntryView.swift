import SwiftUI

enum MealSubmissionPhase { case composing, processing, success }

struct MealEntryDock: View {
    let diary: DemoDiary
    let date: Date
    @State private var expanded = false
    @State private var text = ""
    @State private var phase = MealSubmissionPhase.composing
    @State private var showingPhoto = false
    @State private var usedSampleVoice = false
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    if phase == .composing {
                        HStack {
                            Text("Add a meal").font(.subheadline.weight(.semibold))
                            Spacer()
                            Button { focused = false; animate { expanded = false } } label: {
                                Image(systemName: "xmark").frame(width: 44, height: 32)
                            }.accessibilityLabel("Close meal composer")
                        }
                        TextField("What did you eat?", text: $text, axis: .vertical)
                            .lineLimit(1...4).focused($focused)
                            .accessibilityIdentifier("mealText")
                            .font(.body).submitLabel(.done)
                        HStack {
                            Button {
                                text = "200g steak, 250g potatoes and some broccoli"
                                usedSampleVoice = true
                            } label: { Image(systemName: "mic").frame(width: 44, height: 44) }
                                .accessibilityLabel("Insert sample dictation; no microphone recording")
                            Text(usedSampleVoice ? "Sample dictation inserted" : "Text or sample voice input")
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                            Button {
                                focused = false
                                phase = .processing
                            } label: {
                                Image(systemName: "arrow.up").font(.headline)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(AstraStyle.background)
                                    .background(AstraStyle.accent, in: Circle())
                            }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                            .accessibilityLabel("Add meal to selected day")
                            .accessibilityIdentifier("sendMeal")
                        }
                    } else {
                        SubmissionStatusView(phase: phase)
                    }
                }
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.07)))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                RoundButton(symbol: "camera", label: "Add meal from photo") { showingPhoto = true }
                RoundButton(symbol: "plus", label: "Add meal", prominent: true) {
                    animate { expanded = true }
                    focused = true
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background {
            if expanded { AstraStyle.background.opacity(0.8).ignoresSafeArea(edges: .bottom) }
        }
        .sheet(isPresented: $showingPhoto) { PhotoMealSheet(diary: diary, date: date) }
        .task(id: phase) {
            guard phase == .processing else { return }
            do {
                try await Task.sleep(for: .seconds(1.2))
                diary.addMeal(text: text.trimmingCharacters(in: .whitespacesAndNewlines), on: date, photo: false)
                animate { phase = .success }
            } catch { return }
        }
        .task(id: phase == .success) {
            guard phase == .success else { return }
            do {
                try await Task.sleep(for: .seconds(1.3))
                animate { expanded = false }
                text = ""; usedSampleVoice = false; phase = .composing
            } catch { return }
        }
    }

    private func animate(_ changes: () -> Void) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.88), changes)
    }
}

struct SubmissionStatusView: View {
    let phase: MealSubmissionPhase
    var body: some View {
        HStack(spacing: 16) {
            if phase == .processing {
                ProgressView().controlSize(.regular).frame(width: 32, height: 32)
            } else {
                Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(AstraStyle.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(phase == .processing ? "Putting it together…" : "Meal added")
                    .font(.headline)
                Text(phase == .processing ? "Preparing a sample nutrition estimate" : "Your daily summary is up to date.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}

struct PhotoMealSheet: View {
    let diary: DemoDiary
    let date: Date
    @State private var context = ""
    @State private var phase = MealSubmissionPhase.composing
    @State private var sampleVoice = false
    @State private var photoData: Data?
    @State private var loadingPhoto = false
    @State private var photoError: String?
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !focused {
                        MealPhotoView(data: photoData).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    if phase == .composing {
                        if !focused {
                            MealPhotoSource(photoData: $photoData, loading: $loadingPhoto, errorMessage: $photoError)
                            if loadingPhoto { ProgressView("Loading photo…") }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Anything else to know?").font(.title3.weight(.semibold))
                            Text("A portion size, a hidden ingredient, or what you left on the plate.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        HStack(alignment: .bottom, spacing: 6) {
                            TextField("e.g. Rice underneath the chicken", text: $context, axis: .vertical)
                                .lineLimit(3...5).focused($focused)
                                .accessibilityIdentifier("photoContext")
                            Button {
                                context = "Rice underneath the chicken. Only ate half."
                                sampleVoice = true
                                focused = false
                            } label: { Image(systemName: "mic").frame(width: 44, height: 44) }
                                .accessibilityLabel("Insert sample voice context; no recording")
                        }
                        .padding(14).background(AstraStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                        if sampleVoice { Text("Sample dictation inserted").font(.caption).foregroundStyle(.secondary) }
                        Text(photoData == nil ? "Sample image · choose your own photo above" : "Photo stays on this device · nutrition is a mock estimate")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        SubmissionStatusView(phase: phase)
                    }
                }.padding(22)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AstraStyle.background)
            .safeAreaInset(edge: .bottom) {
                if phase == .composing {
                    Button {
                        focused = false
                        phase = .processing
                    } label: {
                        Text("Add meal").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityIdentifier("submitPhotoMeal")
                    .disabled(loadingPhoto)
                    .padding(.horizontal, 22).padding(.bottom, 12)
                    .background(AstraStyle.background)
                } else if phase == .success {
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).padding()
                }
            }
            .navigationTitle("Photo meal").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.disabled(phase == .processing)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done editing") { focused = false }
                }
            }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .alert("Photo unavailable", isPresented: Binding(get: { photoError != nil }, set: { if !$0 { photoError = nil } })) {
            Button("OK", role: .cancel) { photoError = nil }
        } message: { Text(photoError ?? "") }
        .interactiveDismissDisabled(phase == .processing)
        .task(id: phase) {
            guard phase == .processing else { return }
            do {
                try await Task.sleep(for: .seconds(1.5))
                diary.addMeal(text: context, on: date, photo: true, photoData: photoData)
                phase = .success
            } catch { return }
        }
    }
}

// Deliberately a labeled illustration, not a camera feed or generated food analysis.
struct MealImagePlaceholder: View {
    var body: some View {
        ZStack {
            Color(red: 0.83, green: 0.84, blue: 0.77)
            Ellipse().fill(.black.opacity(0.10)).frame(width: 244, height: 190).offset(y: 14).blur(radius: 12)
            Circle().fill(Color(red: 0.96, green: 0.95, blue: 0.91)).frame(width: 224)
            Circle().strokeBorder(Color.black.opacity(0.05), lineWidth: 2).frame(width: 195)
            ZStack {
                Ellipse().fill(Color(red: 0.82, green: 0.68, blue: 0.46)).frame(width: 102, height: 70).rotationEffect(.degrees(-30)).offset(x: -24, y: -26)
                ForEach(0..<5) { index in
                    Capsule().fill(Color(red: 0.66, green: 0.44, blue: 0.25))
                        .frame(width: 88, height: 8).rotationEffect(.degrees(-30))
                        .offset(x: -28 + Double(index) * 5, y: -42 + Double(index) * 9)
                }
                ForEach(0..<7) { index in
                    Circle().fill(Color(red: 0.34 + Double(index % 2) * 0.08, green: 0.47, blue: 0.26))
                        .frame(width: 35).offset(x: 38 + sin(Double(index) * 2) * 20, y: -8 + cos(Double(index) * 2) * 40)
                }
                Ellipse().fill(Color(red: 0.89, green: 0.85, blue: 0.71)).frame(width: 87, height: 58).rotationEffect(.degrees(15)).offset(x: -28, y: 42)
            }
            VStack { Spacer(); Text("SAMPLE MEAL IMAGE").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.black.opacity(0.55)).padding(12) }
        }
        .accessibilityLabel("Illustrated placeholder of chicken, rice, and greens")
    }
}

struct MealDetailView: View {
    let meal: MealPreview
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(meal.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                    if meal.hasPhoto {
                        MealPhotoView(data: meal.photoData).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    Text(meal.detail).font(.system(.title, design: .serif))
                    NutritionSummaryView(calories: meal.calories, protein: meal.protein, carbs: meal.carbs, fat: meal.fat)
                    Label("Sample nutrition", systemImage: "info.circle").font(.subheadline.weight(.medium))
                    Text(meal.isEstimate ? "This prototype uses a fixed sample estimate, not an analysis of your input. Editing estimates before saving belongs to a later functional feature." : "This meal is part of the sample diary. Nutrition values are for visual review.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(22)
            }
            .background(AstraStyle.background)
            .navigationTitle(meal.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents(meal.hasPhoto ? [.large] : [.medium, .large]).presentationDragIndicator(.visible)
    }
}

#Preview("Photo entry") {
    PhotoMealSheet(diary: DemoDiary(), date: .now).tint(AstraStyle.accent)
}

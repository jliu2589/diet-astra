import SwiftUI

struct ProfileMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingWeightJournal = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Text("AM").font(.system(.title2, design: .serif))
                            .frame(width: 58, height: 58).background(AstraStyle.accent.opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Alex Morgan").font(.title3.weight(.semibold))
                            Text("Your space to build better habits.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 12)
                }.listRowBackground(Color.clear)
                Section {
                    NavigationLink { GoalsView() } label: { Label("Goals", systemImage: "scope").padding(.vertical, 8) }
                    NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape").padding(.vertical, 8) }
                }
                Section {
                    Button { showingWeightJournal = true } label: {
                        Label("Saved weight journal", systemImage: "scalemass").padding(.vertical, 8)
                    }
                } footer: {
                    Text("Your original on-device weight log. Separate from this sample diary.")
                }
                Section {
                    Text("DESIGNED FOR THE LONG RUN")
                        .font(.caption2.weight(.medium)).tracking(1.6).foregroundStyle(.secondary)
                    Text("Demo profile · sample goals").font(.caption).foregroundStyle(.secondary)
                }.listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden).background(AstraStyle.background)
            .navigationTitle("Your Astra").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .sheet(isPresented: $showingWeightJournal) {
            WeightView()
                .safeAreaInset(edge: .bottom) {
                    Button("Close journal") { showingWeightJournal = false }
                        .frame(maxWidth: .infinity, minHeight: 44).background(.regularMaterial)
                }
                .presentationDragIndicator(.visible)
        }
    }
}

struct GoalsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A little intention.\nA lasting difference.").font(.system(.title2, design: .serif))
                    Text("Your sample goals, all in one place.").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 12)
            }.listRowBackground(Color.clear)
            Section("Body weight") {
                LabeledContent("Goal", value: "140 lb")
                LabeledContent("Sample current weight", value: "147.2 lb")
            }
            Section("Daily nutrition") {
                LabeledContent("Calories", value: "2,500 kcal")
                LabeledContent("Protein", value: "150 g")
                LabeledContent("Carbohydrates", value: "300 g")
                LabeledContent("Fat", value: "70 g")
            }
            Section("Movement") {
                LabeledContent("Strength workouts", value: "4 per week")
            }
            Section { Text("Goals are examples for this UI review. Goal configuration will be added in a later feature.").font(.caption).foregroundStyle(.secondary) }
                .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden).background(AstraStyle.background)
        .navigationTitle("Goals").navigationBarTitleDisplayMode(.inline)
    }
}

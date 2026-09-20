import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Preferences") {
                LabeledContent("Weight unit", value: "Pounds (lb)")
                LabeledContent("Appearance", value: "Follows iPhone")
            }
            Section("Your data") {
                LabeledContent("Review & trends", value: "Sample data")
                LabeledContent("Connections", value: "None")
                Text("Prototype meals and check-ins reset when the app restarts. Your saved weight journal stays on this device.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Text("Diet Astra").font(.system(.title2, design: .serif))
                Text("A considered approach to everyday health.").font(.subheadline).foregroundStyle(.secondary)
            }.listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden).background(AstraStyle.background)
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
    }
}

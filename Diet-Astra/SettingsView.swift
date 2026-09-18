import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Your preferences",
                systemImage: "gearshape",
                description: Text("App preferences will be available here.")
            )
            .navigationTitle("Settings")
        }
    }
}

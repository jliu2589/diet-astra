import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Your day at a glance",
                systemImage: "sun.max",
                description: Text("Daily calories, macros, and activity will appear here.")
            )
            .navigationTitle("Today")
        }
    }
}

import SwiftUI

struct WorkoutsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Your workout log",
                systemImage: "dumbbell",
                description: Text("Strength exercises, sets, and reps will appear here.")
            )
            .navigationTitle("Workouts")
        }
    }
}

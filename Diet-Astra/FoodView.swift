import SwiftUI

struct FoodView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Your food log",
                systemImage: "fork.knife",
                description: Text("Meal logging and nutrition details are coming soon.")
            )
            .navigationTitle("Food")
        }
    }
}

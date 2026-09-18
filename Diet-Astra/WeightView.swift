import SwiftUI

struct WeightView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Your weight journey",
                systemImage: "scalemass",
                description: Text("Weight entries, trends, and goals will appear here.")
            )
            .navigationTitle("Weight")
        }
    }
}

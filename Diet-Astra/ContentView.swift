import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }

            Tab("Food", systemImage: "fork.knife") {
                FoodView()
            }

            Tab("Weight", systemImage: "scalemass") {
                WeightView()
            }

            Tab("Workouts", systemImage: "dumbbell") {
                WorkoutsView()
            }

            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}

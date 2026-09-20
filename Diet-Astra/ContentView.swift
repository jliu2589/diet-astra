import SwiftUI

struct ContentView: View {
    private enum Destination: Hashable { case today, trends }
    @State private var diary = DemoDiary()
    @State private var showingMenu = false
    @State private var destination = Destination.today

    var body: some View {
        TabView(selection: $destination) {
            Tab("Today", systemImage: "sun.max", value: Destination.today) {
                NavigationStack {
                    TodayView(diary: diary)
                        .toolbar { appToolbar }
                }
            }
            Tab("Trends", systemImage: "chart.xyaxis.line", value: Destination.trends) {
                NavigationStack {
                    TrendsView(diary: diary)
                        .toolbar { appToolbar }
                }
            }
        }
        .tint(AstraStyle.accent)
        .sheet(isPresented: $showingMenu) { ProfileMenuView() }
    }

    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showingMenu = true } label: {
                Image(systemName: "line.3.horizontal").frame(width: 32, height: 32)
            }
            .accessibilityLabel("Open profile menu")
            .accessibilityIdentifier("profileMenu")
        }
        ToolbarItem(placement: .principal) {
            Text("ASTRA").font(.system(size: 13, weight: .semibold)).tracking(4)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Text("DEMO").font(.system(size: 9, weight: .semibold)).tracking(1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.primary.opacity(0.045), in: Capsule())
                .accessibilityLabel("UI prototype with sample data")
        }
    }
}

#Preview { ContentView() }
#Preview("Dark") { ContentView().preferredColorScheme(.dark) }

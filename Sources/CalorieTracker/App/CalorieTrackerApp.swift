import SwiftUI
import SwiftData

@main
struct CalorieTrackerApp: App {

    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
        }
        .modelContainer(for: [FoodEntry.self, FoodItem.self])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "fork.knife") }

            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

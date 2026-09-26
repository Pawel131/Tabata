import SwiftData
import SwiftUI

@main
struct TabataApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            SetupView()
                .tabItem { Label("Timer", systemImage: "timer") }
            HistoryView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}

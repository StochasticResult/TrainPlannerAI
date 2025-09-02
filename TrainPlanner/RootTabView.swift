import SwiftUI

struct RootTabView: View {
    @ObservedObject var store: ChecklistStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var nutritionStore: NutritionStore
    @ObservedObject var dayContext: DayContext

    var body: some View {
        TabView {
            ContentShellView(store: store, profileStore: profileStore, dayContext: dayContext)
                .tabItem { Label("计划", systemImage: "checklist") }
            NutritionTrackerView(store: nutritionStore, initialDate: dayContext.date, theme: profileStore.profile.theme)
                .tabItem { Label("饮食", systemImage: "fork.knife") }
        }
    }
}

// 将原 ContentView 包一层，保留原交互
struct ContentShellView: View {
    @ObservedObject var store: ChecklistStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var dayContext: DayContext
    var body: some View {
        ContentView(store: store)
            .onAppear { dayContext.date = Calendar.current.startOfDay(for: Date()) }
    }
}



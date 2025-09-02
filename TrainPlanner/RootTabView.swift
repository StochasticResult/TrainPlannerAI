import SwiftUI

/// 顶部切换的两个模块
enum AppTab: String, CaseIterable, Identifiable {
    case plan
    case nutrition

    var id: String { rawValue }

    /// 显示在分段控制中的文字
    var title: String {
        switch self {
        case .plan: return "计划"
        case .nutrition: return "营养"
        }
    }

    /// 对应 SF Symbols 图标
    var systemImage: String {
        switch self {
        case .plan: return "checklist"
        case .nutrition: return "fork.knife"
        }
    }
}

struct RootTabView: View {
    @ObservedObject var store: ChecklistStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var nutritionStore: NutritionStore
    @ObservedObject var dayContext: DayContext
    @State private var selectedTab: AppTab = .plan

    var body: some View {
        Group {
            switch selectedTab {
            case .plan:
                ContentShellView(store: store, profileStore: profileStore, dayContext: dayContext, selectedTab: $selectedTab)
            case .nutrition:
                NutritionTrackerView(store: nutritionStore, initialDate: dayContext.date, theme: profileStore.profile.theme, selectedTab: $selectedTab)
            }
        }
    }
}

// 将原 ContentView 包一层，保留原交互
struct ContentShellView: View {
    @ObservedObject var store: ChecklistStore
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var dayContext: DayContext
    @Binding var selectedTab: AppTab
    var body: some View {
        ContentView(store: store, selectedTab: $selectedTab)
            .onAppear { dayContext.date = Calendar.current.startOfDay(for: Date()) }
    }
}



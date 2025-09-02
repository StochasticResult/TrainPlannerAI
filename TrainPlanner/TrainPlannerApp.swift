//
//  TrainPlannerApp.swift
//  TrainPlanner
//
//  Created by Yuri Zhang on 8/20/25.
//

import SwiftUI

@main
struct TrainPlannerApp: App {
    @StateObject private var store = ChecklistStore()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var nutritionStore = NutritionStore()
    @StateObject private var dayContext = DayContext()
    var body: some Scene {
        WindowGroup {
            RootTabView(store: store, profileStore: profileStore, nutritionStore: nutritionStore, dayContext: dayContext)
                .onAppear { RawInputGateway.shared.configure(store: store) }
                
        }
    }
}

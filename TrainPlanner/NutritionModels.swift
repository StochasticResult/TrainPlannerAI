import Foundation
import SwiftUI

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack, other
    var id: String { rawValue }
    var displayName: String {
        switch self { case .breakfast: return L("meal.breakfast"); case .lunch: return L("meal.lunch"); case .dinner: return L("meal.dinner"); case .snack: return L("meal.snack"); case .other: return L("meal.other") }
    }
}

struct MealEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date
    var type: MealType
    var calories: Int?
    var proteinGrams: Int?
    var fatGrams: Int?
    var carbsGrams: Int?
    var vitamins: [String: Double]?

    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), type: MealType = .other, calories: Int? = nil, proteinGrams: Int? = nil, fatGrams: Int? = nil, carbsGrams: Int? = nil, vitamins: [String: Double]? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.type = type
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.carbsGrams = carbsGrams
        self.vitamins = vitamins
    }
}

struct DayNutritionSummary: Equatable {
    var calories: Int
    var proteinGrams: Int
    var fatGrams: Int
    var carbsGrams: Int
}

final class NutritionStore: ObservableObject {
    @Published private(set) var byDay: [String: [MealEntry]] = [:]
    @Published var dailyCalorieGoal: Int = UserDefaults.standard.integer(forKey: "nutrition.goal.calories")
    @Published var dailyProteinGoal: Int = UserDefaults.standard.integer(forKey: "nutrition.goal.protein")
    @Published var dailyFatGoal: Int = UserDefaults.standard.integer(forKey: "nutrition.goal.fat")
    @Published var dailyCarbGoal: Int = UserDefaults.standard.integer(forKey: "nutrition.goal.carb")

    private let storageKey = "nutrition.storage.v1"

    init() {
        load()
    }

    func entries(for date: Date) -> [MealEntry] {
        let key = Self.dayKey(from: date)
        return (byDay[key] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func addEntry(_ entry: MealEntry, for date: Date) {
        let key = Self.dayKey(from: date)
        var arr = byDay[key] ?? []
        arr.append(entry)
        byDay[key] = arr
        save()
    }

    func deleteEntry(id: UUID, for date: Date) {
        let key = Self.dayKey(from: date)
        if var arr = byDay[key], let idx = arr.firstIndex(where: { $0.id == id }) {
            arr.remove(at: idx)
            byDay[key] = arr
            save()
        }
    }

    func updateEntry(id: UUID, for date: Date, transform: (inout MealEntry) -> Void) {
        let key = Self.dayKey(from: date)
        guard var arr = byDay[key], let idx = arr.firstIndex(where: { $0.id == id }) else { return }
        var item = arr[idx]
        transform(&item)
        arr[idx] = item
        byDay[key] = arr
        save()
    }

    func setDetails(
        id: UUID,
        for date: Date,
        title: String? = nil,
        type: MealType? = nil,
        calories: Int? = nil,
        proteinGrams: Int? = nil,
        fatGrams: Int? = nil,
        carbsGrams: Int? = nil,
        vitamins: [String: Double]? = nil
    ) {
        updateEntry(id: id, for: date) { e in
            if let t = title { e.title = t }
            if let tp = type { e.type = tp }
            if let c = calories { e.calories = c }
            if let p = proteinGrams { e.proteinGrams = p }
            if let f = fatGrams { e.fatGrams = f }
            if let c = carbsGrams { e.carbsGrams = c }
            if let v = vitamins { e.vitamins = v }
        }
    }

    func summary(for date: Date) -> DayNutritionSummary {
        let items = entries(for: date)
        let cals = items.compactMap { $0.calories }.reduce(0, +)
        let pro = items.compactMap { $0.proteinGrams }.reduce(0, +)
        let fat = items.compactMap { $0.fatGrams }.reduce(0, +)
        let car = items.compactMap { $0.carbsGrams }.reduce(0, +)
        return DayNutritionSummary(calories: cals, proteinGrams: pro, fatGrams: fat, carbsGrams: car)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey), let decoded = try? JSONDecoder().decode([String: [MealEntry]].self, from: data) {
            byDay = decoded
        }
    }

    private func save() { if let data = try? JSONEncoder().encode(byDay) { UserDefaults.standard.set(data, forKey: storageKey) } }

    func setGoals(calories: Int? = nil, protein: Int? = nil, fat: Int? = nil, carbs: Int? = nil) {
        if let c = calories { dailyCalorieGoal = c; UserDefaults.standard.set(c, forKey: "nutrition.goal.calories") }
        if let p = protein { dailyProteinGoal = p; UserDefaults.standard.set(p, forKey: "nutrition.goal.protein") }
        if let f = fat { dailyFatGoal = f; UserDefaults.standard.set(f, forKey: "nutrition.goal.fat") }
        if let cb = carbs { dailyCarbGoal = cb; UserDefaults.standard.set(cb, forKey: "nutrition.goal.carb") }
    }

    static func dayKey(from date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Calendar.current.startOfDay(for: date)) }
}



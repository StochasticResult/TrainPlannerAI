import SwiftUI

struct NutritionTrackerView: View {
    @ObservedObject var store: NutritionStore
    @StateObject private var langMgr = LanguageManager.shared
    let initialDate: Date
    let theme: ThemeColor
    
    @State private var selectedDate: Date
    @State private var newMealText: String = ""
    @State private var isShowingAISheet: Bool = false
    @State private var aiDraft: String = ""
    
    // Quick Add State
    @State private var quickAddType: MealType = .breakfast
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage? = nil
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    
    init(store: NutritionStore, initialDate: Date, theme: ThemeColor) {
        self.store = store
        self.initialDate = initialDate
        self.theme = theme
        _selectedDate = State(initialValue: initialDate)
    }

    private var summary: DayNutritionSummary { store.summary(for: selectedDate) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Dashboard Card
                    NutritionDashboardCard(summary: summary, goals: (store.dailyCalorieGoal, store.dailyProteinGoal, store.dailyFatGoal, store.dailyCarbGoal))
                    
                    // Meal Sections
                    VStack(spacing: 16) {
                        MealSection(title: L("meal.breakfast"), icon: "sun.max.fill", color: .orange, type: .breakfast, entries: entries(for: .breakfast), onDelete: deleteEntry)
                        MealSection(title: L("meal.lunch"), icon: "sun.min.fill", color: .blue, type: .lunch, entries: entries(for: .lunch), onDelete: deleteEntry)
                        MealSection(title: L("meal.dinner"), icon: "moon.stars.fill", color: .indigo, type: .dinner, entries: entries(for: .dinner), onDelete: deleteEntry)
                        MealSection(title: L("meal.snack"), icon: "carrot.fill", color: .green, type: .snack, entries: entries(for: .snack), onDelete: deleteEntry)
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for bottom bar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("tab.diet"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !Calendar.current.isDateInToday(selectedDate) {
                        Button("今天") { withAnimation { selectedDate = Date() } }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                QuickInputBar(
                    text: $newMealText,
                    selectedType: $quickAddType,
                    onSend: addQuick,
                    onAI: {
                        aiDraft = newMealText
                        isShowingAISheet = true
                    },
                    onCamera: { src in
                        pickerSource = src
                        showImagePicker = true
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingAISheet) {
            AIComposeView(date: selectedDate, draft: aiDraft, onCancel: { isShowingAISheet = false }, onSubmit: { prompt in
                isShowingAISheet = false
                NutritionService.shared.handle(prompt: prompt, date: selectedDate, store: store) { _ in }
            })
        }
        .sheet(isPresented: $showImagePicker, onDismiss: processImage) {
            ImagePicker(image: $pickedImage, sourceType: pickerSource)
        }
    }
    
    private func entries(for type: MealType) -> [MealEntry] {
        store.entries(for: selectedDate).filter { $0.type == type }
    }
    
    private func deleteEntry(_ id: UUID) {
        withAnimation {
            store.deleteEntry(id: id, for: selectedDate)
        }
    }
    
    private func addQuick() {
        let t = newMealText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.addEntry(MealEntry(title: t, type: quickAddType), for: selectedDate)
        newMealText = ""
        Haptics.success()
    }
    
    private func processImage() {
        guard let _ = pickedImage else { return }
        // In real app, upload image to AI. Here we simulate or use the existing placeholder logic
        let caption = "图片记录：请识别这顿饭的食物并估算营养素"
        NutritionService.shared.handle(prompt: caption, date: selectedDate, store: store) { _ in }
        pickedImage = nil
    }
}

// MARK: - Dashboard Component
struct NutritionDashboardCard: View {
    let summary: DayNutritionSummary
    let goals: (cal: Int, pro: Int, fat: Int, carb: Int)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("今日摄入")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(summary.calories)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("/ \(max(goals.cal, 1)) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // Ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: CGFloat(summary.calories) / CGFloat(max(goals.cal, 1)))
                        .stroke(Color.purple.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 60, height: 60)
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                NutrientBar(label: "碳水", val: summary.carbsGrams, goal: goals.carb, color: .blue)
                NutrientBar(label: "蛋白质", val: summary.proteinGrams, goal: goals.pro, color: .pink)
                NutrientBar(label: "脂肪", val: summary.fatGrams, goal: goals.fat, color: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct NutrientBar: View {
    let label: String
    let val: Int
    let goal: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(color)
                        .frame(width: min(geo.size.width, geo.size.width * (CGFloat(val) / CGFloat(max(goal, 1)))))
                }
            }
            .frame(height: 6)
            
            Text("\(val)/\(goal)g")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Meal Section Component
struct MealSection: View {
    let title: String
    let icon: String
    let color: Color
    let type: MealType
    let entries: [MealEntry]
    let onDelete: (UUID) -> Void
    
    var totalCal: Int { entries.compactMap { $0.calories }.reduce(0, +) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(totalCal) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            
            if !entries.isEmpty {
                Divider().padding(.leading)
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.body)
                            HStack(spacing: 6) {
                                if let c = entry.calories { Text("\(c) kcal").font(.caption2).foregroundStyle(.secondary) }
                                if let p = entry.proteinGrams { Text("P:\(p)").font(.caption2).foregroundStyle(.pink) }
                                if let f = entry.fatGrams { Text("F:\(f)").font(.caption2).foregroundStyle(.orange) }
                                if let c = entry.carbsGrams { Text("C:\(c)").font(.caption2).foregroundStyle(.blue) }
                            }
                        }
                        Spacer()
                        Button {
                            onDelete(entry.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    // Separator
                    if entry.id != entries.last?.id {
                        Divider().padding(.leading)
                    }
                }
            } else {
                Divider().padding(.leading)
                Text("点击下方添加记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Quick Input Bar
struct QuickInputBar: View {
    @Binding var text: String
    @Binding var selectedType: MealType
    let onSend: () -> Void
    let onAI: () -> Void
    let onCamera: (UIImagePickerController.SourceType) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                // Meal Type Selector
                Menu {
                    ForEach(MealType.allCases) { t in
                        Button { selectedType = t } label: {
                            Label(t.displayName, systemImage: iconFor(t))
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: iconFor(selectedType))
                            .font(.system(size: 20))
                        Text(selectedType.displayName.prefix(1))
                            .font(.caption2)
                            .bold()
                    }
                    .foregroundStyle(.purple)
                    .frame(width: 40)
                }
                
                // Input Field
                HStack {
                    TextField("记录食物...", text: $text)
                        .submitLabel(.send)
                        .onSubmit(onSend)
                    
                    if text.isEmpty {
                        Button(action: onAI) {
                            Image(systemName: "wand.and.stars").foregroundStyle(.secondary)
                        }
                        Menu {
                            Button(action: { onCamera(.camera) }) { Label("拍照", systemImage: "camera") }
                            Button(action: { onCamera(.photoLibrary) }) { Label("相册", systemImage: "photo.on.rectangle") }
                        } label: {
                            Image(systemName: "camera").foregroundStyle(.secondary)
                        }
                    } else {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.purple)
                        }
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(12)
            .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        }
    }
    
    func iconFor(_ t: MealType) -> String {
        switch t {
        case .breakfast: return "sun.max.fill"
        case .lunch: return "sun.min.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        case .other: return "fork.knife"
        }
    }
}

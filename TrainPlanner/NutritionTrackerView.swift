import SwiftUI

struct NutritionTrackerView: View {
    @ObservedObject var store: NutritionStore
    @StateObject private var langMgr = LanguageManager.shared
    let initialDate: Date
    let theme: ThemeColor
    @State private var dayOffset: Int = 0
    @State private var newMealText: String = ""
    @State private var isShowingAISheet: Bool = false
    @State private var aiDraft: String = ""
    @State private var expandVitamins: Bool = false
    @State private var filter: MealType? = nil
    @State private var quickType: MealType? = nil
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage? = nil
    @State private var source: UIImagePickerController.SourceType = .photoLibrary

    private func dateFor(offset: Int) -> Date {
        let base = Calendar.current.startOfDay(for: initialDate)
        return base.addingTimeInterval(TimeInterval(offset * 86400))
    }
    private var date: Date { dateFor(offset: dayOffset) }

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            card
            inputBar
        }
        .padding(20)
        .onAppear { dayOffset = 0 }
    }

    private var header: some View {
        HStack {
            Button { dayOffset -= 1 } label: { Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)) }
            Spacer()
            Text(date.readableTitle).font(.system(size: 20, weight: .bold))
            Spacer()
            Button { dayOffset += 1 } label: { Image(systemName: "chevron.right").font(.system(size: 18, weight: .semibold)) }
        }
    }

    private var card: some View {
        let summary = store.summary(for: date)
        return VStack(alignment: .leading, spacing: 16) {
            // 大号卡片：剩余热量
            let calGoal = max(store.dailyCalorieGoal, 1)
            let leftCal = max(0, calGoal - summary.calories)
            let calRatio = Double(summary.calories) / Double(calGoal)
            BigNumberCard(title: L("nut.calories"), valueText: "\(leftCal)", subtitle: L("nut.left"), ratio: calRatio, color: .orange)
            // 三个 mini 卡片
            HStack(spacing: 12) {
                let cbGoal = max(store.dailyCarbGoal, 1)
                let cbLeft = max(0, cbGoal - summary.carbsGrams)
                MacroMiniCard(title: L("nut.carbs"), valueText: "\(cbLeft)g", ratio: Double(summary.carbsGrams)/Double(cbGoal), color: .blue, systemImage: "bread.slice")
                let pGoal = max(store.dailyProteinGoal, 1)
                let pLeft = max(0, pGoal - summary.proteinGrams)
                MacroMiniCard(title: L("nut.protein"), valueText: "\(pLeft)g", ratio: Double(summary.proteinGrams)/Double(pGoal), color: .pink, systemImage: "egg")
                let fGoal = max(store.dailyFatGoal, 1)
                let fLeft = max(0, fGoal - summary.fatGrams)
                MacroMiniCard(title: L("nut.fat"), valueText: "\(fLeft)g", ratio: Double(summary.fatGrams)/Double(fGoal), color: .purple, systemImage: "cheese")
            }
            Divider()
            // 分段筛选 + 小计
            Picker(L("nut.meal"), selection: $filter) {
                ForEach(MealType.allCases) { t in Text(t.displayName).tag(t as MealType?) }
                Text(L("nut.all")).tag(nil as MealType?)
            }
            .pickerStyle(.segmented)
            let items = store.entries(for: date)
            let filtered = filter == nil ? items : items.filter { $0.type == filter }
            List(filtered) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title).font(.body)
                        Spacer()
                        Text(item.type.displayName).font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        if let c = item.calories { chip("\(c) kcal", .orange) }
                        if let p = item.proteinGrams { chip("P \(p) g", .pink) }
                        if let f = item.fatGrams { chip("F \(f) g", .purple) }
                        if let c = item.carbsGrams { chip("C \(c) g", .blue) }
                    }
                    if expandVitamins, let v = item.vitamins, !v.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(v.keys.sorted(), id: \.self) { k in
                                let val = v[k] ?? 0
                                Text("\(k): \(val, specifier: "%.1f") mg").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 300)
            if !filtered.isEmpty {
                let sc = filtered.compactMap { $0.calories }.reduce(0, +)
                let sp = filtered.compactMap { $0.proteinGrams }.reduce(0, +)
                let sf = filtered.compactMap { $0.fatGrams }.reduce(0, +)
                let scb = filtered.compactMap { $0.carbsGrams }.reduce(0, +)
                HStack(spacing: 10) {
                    chip(L("nut.subtotal") + ": \(sc) kcal", .orange)
                    chip("P \(sp) g", .pink)
                    chip("F \(sf) g", .purple)
                    chip("C \(scb) g", .blue)
                }
            }
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expandVitamins.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expandVitamins ? "chevron.down" : "chevron.right")
                        Text(L("act.view_micro"))
                    }.font(.caption)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    BokehBackground(base: theme.primary, animated: false)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                )
        )
    }

    private func goalsBar(summary: DayNutritionSummary) -> some View {
        HStack(spacing: 12) {
            progressRing(title: L("nut.calories"), value: Double(summary.calories), goal: Double(max(store.dailyCalorieGoal, 1)), color: .orange)
            progressRing(title: L("nut.protein"), value: Double(summary.proteinGrams), goal: Double(max(store.dailyProteinGoal, 1)), color: .pink)
            progressRing(title: L("nut.fat"), value: Double(summary.fatGrams), goal: Double(max(store.dailyFatGoal, 1)), color: .purple)
            progressRing(title: L("nut.carbs"), value: Double(summary.carbsGrams), goal: Double(max(store.dailyCarbGoal, 1)), color: .blue)
            Spacer()
            Menu {
                Button(L("nut.set_goal_2000")) { store.setGoals(calories: 2000) }
                Button(L("nut.set_goal_prot")) { store.setGoals(protein: 120) }
                Button(L("nut.set_goal_fat")) { store.setGoals(fat: 70) }
                Button(L("nut.set_goal_carb")) { store.setGoals(carbs: 250) }
                Button(L("nut.clear_goals")) { store.setGoals(calories: 0, protein: 0, fat: 0, carbs: 0) }
            } label: {
                Image(systemName: "gearshape").foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private func progressRing(title: String, value: Double, goal: Double, color: Color) -> some View {
        let ratio = min(max(goal > 0 ? value / goal : 0, 0), 1)
        return VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color(.tertiarySystemFill), lineWidth: 8).frame(width: 44, height: 44)
                Circle().trim(from: 0, to: ratio).stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 44, height: 44)
                Text("\(Int(ratio*100))%").font(.system(size: 10, weight: .bold))
            }
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: ratio) { newVal in
            if newVal >= 1.0 { Haptics.success() }
        }
    }

    private func metric(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption2).foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(color))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(L("nut.input_placeholder"), text: $newMealText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addQuick)
            Button {
                aiDraft = newMealText
                isShowingAISheet = true
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            Menu {
                Button(L("act.take_photo")) { source = .camera; showImagePicker = true }
                Button(L("act.album")) { source = .photoLibrary; showImagePicker = true }
            } label: {
                Image(systemName: "camera")
            }
            .buttonStyle(.bordered)
            Button(action: addQuick) {
                Image(systemName: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            Menu {
                ForEach(MealType.allCases) { t in Button(t.displayName) { quickType = t } }
            } label: {
                Image(systemName: "fork.knife")
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $isShowingAISheet) {
            AIComposeView(date: date, draft: aiDraft, onCancel: { isShowingAISheet = false }, onSubmit: { prompt in
                isShowingAISheet = false
                NutritionService.shared.handle(prompt: prompt, date: date, store: store) { _ in }
            })
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            if let img = pickedImage {
                let caption = "图片记录：请识别这顿饭的食物并估算营养素"
                NutritionService.shared.handle(prompt: caption, date: date, store: store) { _ in }
                pickedImage = nil
            }
        }) {
            ImagePicker(image: $pickedImage, sourceType: source)
        }
    }

    private func addQuick() {
        let t = newMealText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        store.addEntry(MealEntry(title: t, type: quickType ?? .other), for: date)
        newMealText = ""
    }
}

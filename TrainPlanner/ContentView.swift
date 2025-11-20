import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var store: ChecklistStore
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var langMgr = LanguageManager.shared
    @State private var dayOffset: Int = 0
    @State private var cachedAvatar: UIImage? = nil

    // 拖拽与动效状态
    @State private var dragOffset: CGSize = .zero              // 左滑时用于驱动当前卡片位移
    @State private var swipeOutOffsetX: CGFloat = 0            // 左滑提交时当前卡片飞出
    @State private var isCommittingSwipe: Bool = false         // 提交过程中禁用交互
    @State private var isEditingModeFromChild: Bool = false    // 子视图编辑模式

    // 右滑：从左侧带回上一天卡片（持久层滑入）
    @State private var prevSlideAnimX: CGFloat? = nil           // 非空时驱动上一张卡片的滑入动画
    @State private var incomingTodayOffsetX: CGFloat? = nil     // 存在时显示今天卡片，x 从 -width 到 0

    // 新增：按钮切换到明天时用于控制下层卡片“更慢”的上浮动画
    @State private var stackReveal: CGFloat = 0

    @State private var isShowingDatePicker: Bool = false
    @State private var selectedDate: Date = Date()

    @State private var isShowingProfile = false
    @State private var isShowingSearch = false
    
    @State private var pendingOps: [AIService.Operation] = []
    @State private var pendingOpsSummary: String = ""
    @State private var showAIReview = false
    @State private var showAILoading = false
    @State private var aiLoadingText = "" // initialized in init or onAppear? No, just use default in usage
    @State private var showAITip = false
    @State private var aiTipText = ""

    private let swipeThreshold: CGFloat = 120

    // 仅允许在卡片顶部或底部区域触发翻页，避免与列表左滑删除冲突
    // 将顶部判定区略微上移，减少与首条任务重叠（原 130 → 112）
    private let topDragZoneHeight: CGFloat = 112
    private let bottomDragZoneHeight: CGFloat = 110
    @State private var isCardSwipeAllowedForCurrentGesture: Bool? = nil
    
    init(store: ChecklistStore) {
        self.store = store
        _aiLoadingText = State(initialValue: L("ui.ai_thinking"))
        _aiTipText = State(initialValue: L("ai.tip_busy"))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ZStack {
                    cardView(for: dateFor(offset: dayOffset + 2))
                        .id("stack-bottom-\(dayOffset+2)")
                        .scaleEffect(thirdCardScale)
                        .offset(x: -12, y: thirdCardOffsetY)
                        .opacity(thirdCardOpacity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(.systemBackground).opacity(0.48))
                        )

                    cardView(for: dateFor(offset: dayOffset + 1))
                        .id("stack-mid-\(dayOffset+1)")
                        .scaleEffect(secondCardScale)
                        .offset(x: -6, y: secondCardOffsetY)
                        .opacity(secondCardOpacity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color(.systemBackground).opacity(0.18))
                        )

                    interactiveCard
                        .id("stack-top-\(dayOffset)")

                    if let x = prevSlideAnimX {
                        let width = UIScreen.main.bounds.width
                        let prog = clamp01(1 - abs(x) / width)
                        cardView(for: dateFor(offset: dayOffset - 1))
                            .id("incoming-prev-\(dayOffset-1)")
                            .scaleEffect(0.98 + 0.02 * prog)
                            .opacity(0.85 + 0.15 * prog)
                            .offset(x: x)
                            .transition(.identity)
                            .allowsHitTesting(false)
                            .zIndex(4)
                    }

                    if let x = incomingTodayOffsetX {
                        let width = UIScreen.main.bounds.width
                        let prog = clamp01(1 - abs(x) / width)
                        cardView(for: dateFor(offset: 0))
                            .id("incoming-today")
                            .scaleEffect(0.985 + 0.015 * prog)
                            .opacity(0.9 + 0.1 * prog)
                            .offset(x: x)
                            .transition(.identity)
                            .allowsHitTesting(false)
                            .zIndex(4)
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
                    .padding(.vertical, 16)
            }
        }
        // 已移除：屏幕边缘滑动唤出日期选择与 Profile
        // 避免键盘改变全局安全区导致顶栏/头像重新布局
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $isShowingDatePicker) { datePickerSheet }
        .sheet(isPresented: $isShowingProfile) { ProfileView(store: profileStore, checklist: store) }
        .sheet(isPresented: $isShowingSearch) {
            GlobalSearchView(store: store) { d, _ in
                // 跳转到包含该任务的日期
                let target = Calendar.current.startOfDay(for: d)
                let today = Calendar.current.startOfDay(for: Date())
                dayOffset = daysBetween(startOf: today, and: target)
            }
        }
        .sheet(isPresented: $showAIReview) {
            AIReviewSheet(operations: pendingOps, aiSummary: pendingOpsSummary, onCancel: { showAIReview = false }, onConfirm: {
                AIService.shared.execute(operations: pendingOps, dateContext: dateFor(offset: dayOffset), store: store)
                showAIReview = false
            })
        }
        // 使用 overlay 而非 fullScreenCover，真正让底层内容可见
        .overlay(alignment: .center) {
            if showAILoading {
                AILoadingOverlay(text: aiLoadingText) {
                    AIService.shared.cancelActive(); showAILoading = false
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .overlay(alignment: .center) {
            if showAITip {
                AIFriendlyTipView(text: aiTipText) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) { showAITip = false }
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(11)
            }
        }
        .onChange(of: dayOffset) { _ in resetTransitions() }
        .onAppear { refreshAvatarCache() }
        .onChange(of: profileStore.profile.avatarImageData) { _ in refreshAvatarCache() }
    }

    private var datePickerSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker(
                    L("ui.select_date"),
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .onChange(of: selectedDate) { newValue in
                    dayOffset = daysBetween(startOf: Calendar.current.startOfDay(for: Date()), and: Calendar.current.startOfDay(for: newValue))
                }
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("ui.today")) {
                        // 修复：点“今天”后同步更新 DatePicker 的选中日期
                        selectedDate = Date()
                        animateGoToToday()
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button(L("act.complete")) { isShowingDatePicker = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 叠层参数（仅左滑时用来露出下一张）
    private var progress: CGFloat { min(max(abs(dragOffset.width) / swipeThreshold, 0), 1) }
    private var smoothProgress: CGFloat { smooth(progress) }
    private var reveal: CGFloat { max(smoothProgress, stackReveal) }
    private var secondCardScale: CGFloat { dragOffset.width < 0 || stackReveal > 0 ? (0.95 + 0.05 * reveal) : 0.95 }
    private var thirdCardScale: CGFloat { dragOffset.width < 0 || stackReveal > 0 ? (0.90 + 0.05 * min(reveal, 0.6)) : 0.90 }
    private var secondCardOffsetY: CGFloat { dragOffset.width < 0 || stackReveal > 0 ? (20 - 20 * reveal) : 20 }
    private var thirdCardOffsetY: CGFloat { dragOffset.width < 0 || stackReveal > 0 ? (40 - 20 * min(reveal, 0.6)) : 40 }
    private var secondCardOpacity: Double { dragOffset.width < 0 || stackReveal > 0 ? (0.85 + Double(0.10 * reveal)) : 0.85 }
    private var thirdCardOpacity: Double { dragOffset.width < 0 || stackReveal > 0 ? (0.60 + Double(0.20 * min(reveal, 0.6))) : 0.60 }

    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            Button { isShowingDatePicker = true } label: {
                Image(systemName: "calendar.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(profileStore.profile.theme.primary, .white)
                    .font(.system(size: 26))
            }
            Spacer()
            Text("doAI")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 10) {
                Button { isShowingSearch = true } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
                }
                Button { isShowingProfile = true } label: {
                    if let ui = cachedAvatar {
                        Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill).frame(width: 32, height: 32).clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill").font(.system(size: 28)).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - 顶层卡片（仅左滑随手指移动；右滑不移动）
    private var interactiveCard: some View {
        let date = dateFor(offset: dayOffset)
        let width = UIScreen.main.bounds.width
        let cardHeight: CGFloat = min(620, UIScreen.main.bounds.height * 0.75)
        // 仅在向左滑（去下一天）时移动当前卡片；右滑去上一天不推动当前卡片
        let moveX = (dragOffset.width < 0 ? dragOffset.width : 0) + swipeOutOffsetX
        let leaveOpacity = 1 - 0.30 * Double(smooth(clamp01(abs(moveX) / width)))
        let prevProg: CGFloat = { if let x = prevSlideAnimX { return clamp01(1 - abs(x) / width) } else { return 0 } }()
        let smPrev: CGFloat = smooth(prevProg)
        let isPrevOverlayActive = prevSlideAnimX != nil
        return cardView(for: date)
            .overlay(alignment: .topLeading) { if dragOffset.width > 40 { labelView(text: L("ui.prev_day"), color: profileStore.profile.theme.primary) } }
            .overlay(alignment: .topTrailing) { if dragOffset.width < -40 { labelView(text: L("ui.next_day"), color: profileStore.profile.theme.primary) } }
            .offset(x: moveX, y: dragOffset.height)
            .rotationEffect(.degrees(Double(moveX / width) * 8))
            // 上一张滑入时，当前卡片顺滑缩放与轻微淡出，使用平滑曲线避免突变
            .scaleEffect(1 - 0.02 * smPrev)
            .opacity(leaveOpacity * (1 - 0.08 * Double(smPrev)))
            .allowsHitTesting(!isCommittingSwipe)
            .zIndex(3)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        guard !isCommittingSwipe && !isEditingModeFromChild else { return }
                        if isCardSwipeAllowedForCurrentGesture == nil {
                            let y = value.startLocation.y
                            isCardSwipeAllowedForCurrentGesture = (y <= topDragZoneHeight) || (y >= cardHeight - bottomDragZoneHeight)
                        }
                        guard isCardSwipeAllowedForCurrentGesture == true else { return }
                        let dx = value.translation.width
                        if dx >= 0 {
                            let width = UIScreen.main.bounds.width
                            withAnimation(nil) { dragOffset = .zero } // 当前卡片不随右滑移动
                            withAnimation(nil) { prevSlideAnimX = -width + min(dx, width) } // 仅驱动上一天卡片
                        } else {
                            prevSlideAnimX = nil
                            withAnimation(nil) { dragOffset = value.translation }
                        }
                    }
                    .onEnded { value in
                        defer { isCardSwipeAllowedForCurrentGesture = nil }
                        guard !isCommittingSwipe && !isEditingModeFromChild else { return }
                        guard isCardSwipeAllowedForCurrentGesture == true else { return }
                        let dx = value.translation.width
                        if dx > swipeThreshold { commitPreviousViaSlideIn() }
                        else if dx < -swipeThreshold { commitNextViaSwipeOut() }
                        else {
                            if prevSlideAnimX != nil {
                                let width = UIScreen.main.bounds.width
                                withAnimation(.easeOut(duration: 0.16)) { prevSlideAnimX = -width }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { prevSlideAnimX = nil }
                            }
                            withAnimation(nil) { dragOffset = .zero }
                        }
                    }
            )
    }

    private func labelView(text: String, color: Color) -> some View {
        Text(text).font(.system(size: 28, weight: .heavy)).foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(text == L("ui.prev_day") ? -15 : 15)).padding(24).opacity(0.9)
    }

    // MARK: - 卡片内容
    private func cardView(for date: Date) -> some View {
        DayCardView(
            date: date,
            tasks: store.tasks(for: date),
            theme: profileStore.profile.theme,
            onToggle: { id in store.toggle(taskId: id, completedOn: date) },
            onAddTask: { title in store.addTask(title: title, for: date) },
            onAIPrompt: { prompt, ctxDate in
                let needConfirm = AIConfig.shared.requireConfirmBeforeExecute
                if needConfirm {
                    showAILoading = true; aiLoadingText = L("ui.ai_thinking")
                    AIService.shared.plan(prompt: prompt, date: ctxDate, store: store) { ops, summary in
                        showAILoading = false
                        if summary.trimmingCharacters(in: .whitespacesAndNewlines) == AIService.noActionToken {
                            aiTipText = L("ai.tip_fail")
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) { showAITip = true }
                            return
                        }
                        if ops.isEmpty && summary.isEmpty {
                            aiTipText = L("ai.tip_busy")
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) { showAITip = true }
                        } else {
                            pendingOps = ops; pendingOpsSummary = summary; showAIReview = true
                        }
                    }
                } else {
                    showAILoading = true; aiLoadingText = L("ui.loading")
                    AIService.shared.handlePrompt(prompt, date: ctxDate, store: store) { finalText in
                        showAILoading = false
                        let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed == AIService.noActionToken {
                            aiTipText = L("ai.tip_fail")
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.92)) { showAITip = true }
                        } else if trimmed == "__TOOLS_EXECUTED__" {
                            // 工具已在本地执行，无需额外提示
                        }
                    }
                }
            },
            onDelete: { offsets in store.deleteTasks(at: offsets, for: date) },
            onDeleteById: { id in store.deleteTask(id: id) },
            onReorder: { indices, newOffset in store.reorderTasks(for: date, from: indices, to: newOffset) },
            disableRowSwipe: (dragOffset.width != 0) || (prevSlideAnimX != nil) || isCommittingSwipe,
            onUpdateDetails: { id, title, due, start, repeatRule, repeatEnd, priority, notes, labels, duration, reminderOffsets in
                store.setDetails(
                    taskId: id,
                    for: date,
                    title: title,
                    dueDate: due,
                    startAt: start,
                    repeatRule: repeatRule,
                    repeatEndDate: repeatEnd,
                    priority: priority,
                    notes: notes,
                    labels: labels,
                    durationMinutes: duration,
                    reminderOffsets: reminderOffsets
                )
            },
            onEditingModeChanged: { isEditingModeFromChild = $0 }
        )
        .frame(height: min(620, UIScreen.main.bounds.height * 0.75))
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LinearGradient(colors: [profileStore.profile.theme.primary.opacity(0.08), Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(
                            BokehBackground(base: profileStore.profile.theme.primary, animated: false)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                        )
                )
                .shadow(color: profileStore.profile.theme.primary.opacity(0.18), radius: 16, x: 0, y: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .onReceive(NotificationCenter.default.publisher(for: .deferTasksRequested)) { noti in
            guard let d = noti.object as? Date else { return }
            let day = Calendar.current.startOfDay(for: d)
            let me = Calendar.current.startOfDay(for: date)
            guard day == me else { return }
            store.deferIncompleteTasks(on: day)
            Haptics.medium()
        }
    }

    // MARK: - 底部按钮（与手势一致）
    private var bottomBar: some View {
        HStack(spacing: 24) {
            gradientCircleButton(systemName: "chevron.left", color: profileStore.profile.theme.primary, diameter: 64, iconSize: 28) {
                guard !isCommittingSwipe && !isEditingModeFromChild else { return }
                commitPreviousViaSlideIn()
            }
            Button(action: { guard !isCommittingSwipe && !isEditingModeFromChild else { return }; animateGoToToday() }) {
                Image(systemName: "calendar")
            }
            .buttonStyle(CircleGradientButtonStyle(color: .orange, diameter: 80, iconSize: 34))
            gradientCircleButton(systemName: "chevron.right", color: profileStore.profile.theme.primary, diameter: 64, iconSize: 28) {
                guard !isCommittingSwipe && !isEditingModeFromChild else { return }
                withAnimation(.easeOut(duration: 0.26)) { stackReveal = 1 }
                commitNextViaSwipeOut()
            }
        }
    }

    private func gradientCircleButton(systemName: String, color: Color, diameter: CGFloat, iconSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: systemName) }.buttonStyle(CircleGradientButtonStyle(color: color, diameter: diameter, iconSize: iconSize))
    }

    private struct CircleGradientButtonStyle: ButtonStyle {
        let color: Color; let diameter: CGFloat; let iconSize: CGFloat
        func makeBody(configuration: Configuration) -> some View {
            let gradient = LinearGradient(colors: [color.opacity(0.95), color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            return configuration.label.font(.system(size: iconSize, weight: .bold)).foregroundStyle(.white)
            .frame(width: diameter, height: diameter).background(gradient).clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: color.opacity(0.35), radius: 12, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    // MARK: - 提交动画
    private func commitNextViaSwipeOut() {
        guard !isCommittingSwipe else { return }
        isCommittingSwipe = true
        Haptics.medium()
        let width = UIScreen.main.bounds.width
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0.1)) { swipeOutOffsetX = -width * 1.1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(nil) { goToNextDay(); swipeOutOffsetX = 0; dragOffset = .zero; stackReveal = 0 }
            isCommittingSwipe = false
        }
    }

    private func commitPreviousViaSlideIn() {
        guard !isCommittingSwipe else { return }
        isCommittingSwipe = true
        Haptics.medium()
        let width = UIScreen.main.bounds.width
        // 若已有手势中间状态，则从当前位置继续；否则从左侧外开始
        if prevSlideAnimX == nil { withAnimation(nil) { prevSlideAnimX = -width } }
        // 使用与“去下一天”一致的弹簧参数滑入
        withAnimation(.spring(response: 0.28, dampingFraction: 0.90, blendDuration: 0.1)) { prevSlideAnimX = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(nil) { goToPreviousDay(); prevSlideAnimX = nil; dragOffset = .zero }
            isCommittingSwipe = false
        }
    }

    private func animateGoToToday() {
        guard !isCommittingSwipe else { return }
        if dayOffset == 0 { return }
        isCommittingSwipe = true
        Haptics.success()
        let width = UIScreen.main.bounds.width
        let startX: CGFloat = dayOffset > 0 ? -width : width
        incomingTodayOffsetX = startX
        withAnimation(.spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0.12)) { incomingTodayOffsetX = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(nil) { dayOffset = 0; prevSlideAnimX = nil; incomingTodayOffsetX = nil; dragOffset = .zero; stackReveal = 0 }
            isCommittingSwipe = false
        }
    }

    // MARK: - 工具函数
    private func dateFor(offset: Int) -> Date { Calendar.current.startOfDay(for: Date()).adding(days: offset) }
    private func daysBetween(startOf: Date, and endOf: Date) -> Int { Calendar.current.dateComponents([.day], from: startOf, to: endOf).day ?? 0 }
    private func goToNextDay() { dayOffset += 1 }
    private func goToPreviousDay() { dayOffset -= 1 }

    private func clamp01(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }
    private func smooth(_ p: CGFloat) -> CGFloat { CGFloat(sin(Double(clamp01(p)) * .pi / 2.0)) }

    private func resetTransitions() { prevSlideAnimX = nil; incomingTodayOffsetX = nil; swipeOutOffsetX = 0; withAnimation(nil) { dragOffset = .zero; stackReveal = 0 }; isCommittingSwipe = false }

    private func refreshAvatarCache() {
        if let data = profileStore.profile.avatarImageData, let ui = UIImage(data: data) {
            cachedAvatar = ui
        } else {
            cachedAvatar = nil
        }
    }
}

#Preview { ContentView(store: ChecklistStore()) }

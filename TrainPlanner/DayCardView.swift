import SwiftUI

struct DayCardView: View {
    let date: Date
    let tasks: [DailyTask]
    let theme: ThemeColor
    let onToggle: (UUID) -> Void
    let onAddTask: (String) -> Void
    // 新增：AI 自然语言入口（占位回调，稍后接 API）
    var onAIPrompt: ((String, Date) -> Void)? = nil
    let onDelete: (IndexSet) -> Void
    let onDeleteById: ((UUID) -> Void)?
    let onReorder: ((IndexSet, Int) -> Void)?
    // 外层翻页手势进行中时，禁用行内滑动删除
    var disableRowSwipe: Bool = false

    // 扩展：更多详情参数
    var onUpdateDetails: ((UUID, String?, Date?, Date?, RepeatRule, Date?, TaskPriority?, String?, [String]?, Int?, [Int]?) -> Void)? = nil

    // 新增：编辑模式变更回调，便于外层禁用左右滑动
    var onEditingModeChanged: ((Bool) -> Void)? = nil

    @State private var newTaskTitle: String = ""
    @State private var editingTask: DailyTask? = nil
    @State private var tempTitle: String = ""
    @State private var tempDueDate: Date? = nil
    @State private var tempStartAt: Date? = nil
    @State private var tempRepeat: RepeatRule = .none
    @State private var tempRepeatEnd: Date? = nil

    // 新增编辑字段
    @State private var tempPriority: TaskPriority = .none
    @State private var tempNotes: String = ""
    @State private var tempLabelsText: String = ""  // 逗号分隔
    @State private var tempDuration: Int? = nil
    @State private var tempReminderOffsetsText: String = "" // 逗号分隔，单位分钟

    @State private var isEditingMode: Bool = false
    @State private var editMode: EditMode = .inactive
    @State private var showTools: Bool = false

    @State private var showNotesTask: DailyTask? = nil

    // 删除确认
    @State private var pendingDelete: IndexSet? = nil
    @State private var showDeleteAlert: Bool = false
    // 滑动删除确认
    @State private var showSwipeDeleteAlert: Bool = false
    @State private var pendingDeleteIdBySwipe: UUID? = nil
    @State private var deleteConfirmResponder: ((Bool) -> Void)? = nil

    @StateObject private var keyboard = KeyboardObserver()
    @FocusState private var isAddBarFocused: Bool

    // AI 输入
    @State private var isShowingAISheet: Bool = false
    @State private var aiPromptDraft: String = ""

    // 进度统计
    private var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        let done = tasks.filter { $0.isDone }.count
        return Double(done) / Double(max(tasks.count, 1))
    }
    private var completionText: String {
        tasks.isEmpty ? "0/0" : "\(tasks.filter{ $0.isDone }.count)/\(tasks.count)"
    }

    // 列表筛选
    enum Filter: String, CaseIterable, Identifiable { case all = "全部", todo = "未完成", done = "已完成"; var id: String { rawValue } }
    @State private var filter: Filter = .all
    @State private var localQuery: String = ""
    @State private var selectedLabel: String? = nil
    private var filteredTasks: [DailyTask] {
        let base: [DailyTask] = {
            switch filter {
            case .all: return tasks
            case .todo: return tasks.filter { !$0.isDone }
            case .done: return tasks.filter { $0.isDone }
            }
        }()
        let byLabel = selectedLabel.flatMap { lbl in lbl.isEmpty ? base : base.filter { $0.labels.contains(lbl) } } ?? base
        let q = localQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return byLabel }
        return byLabel.filter { t in
            if t.title.lowercased().contains(q) { return true }
            if t.notes.lowercased().contains(q) { return true }
            if t.labels.joined(separator: ",").lowercased().contains(q) { return true }
            return false
        }
    }
    private var allLabels: [String] { Array(Set(tasks.flatMap { $0.labels })).sorted() }

    var body: some View {
        VStack(spacing: 16) {
            header
            Divider()
            taskList
            addBar
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        // 不让系统为键盘自动上推整页，由我们单独抬起输入条
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(nil, value: keyboard.currentHeight)
        .animation(nil, value: isAddBarFocused)
        .sheet(item: $editingTask, onDismiss: { editingTask = nil }) { task in
            TaskEditorView(task: task) { title, due, start, repeatRule, repeatEnd, priority, notes, labels, duration, offsets in
                onUpdateDetails?(task.id, title, due, start, repeatRule, repeatEnd, priority, notes, labels, duration, offsets)
            }
        }
        .sheet(item: $showNotesTask) { t in
            TaskNotesView(task: t) { newTitle, newNotes in
                onUpdateDetails?(t.id, newTitle, t.dueDate, t.startAt, t.repeatRule, t.repeatEndDate, nil, newNotes, nil, t.durationMinutes, t.reminderOffsets)
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("删除任务"),
                message: Text("此操作将移动到最近删除，可在设置中恢复。"),
                primaryButton: .destructive(Text("删除")) {
                    if let idx = pendingDelete { onDelete(idx); pendingDelete = nil }
                },
                secondaryButton: .cancel { pendingDelete = nil }
            )
        }
        .sheet(isPresented: $isShowingAISheet) {
            AIComposeView(date: date, draft: aiPromptDraft, onCancel: { isShowingAISheet = false }, onSubmit: { prompt in
                isShowingAISheet = false
                aiPromptDraft = ""
                // 暂时：将自然语句作为标题直接创建；后续接入 API 后由 onAIPrompt 触发智能解析
                if let ai = onAIPrompt {
                    ai(prompt, date)
                } else {
                    onAddTask(prompt)
                }
            })
        }
        .confirmationDialog("删除任务", isPresented: $showSwipeDeleteAlert, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                deleteConfirmResponder?(true)
                if let id = pendingDeleteIdBySwipe { onDeleteById?(id) }
                pendingDeleteIdBySwipe = nil; deleteConfirmResponder = nil
            }
            Button("取消", role: .cancel) {
                deleteConfirmResponder?(false)
                pendingDeleteIdBySwipe = nil; deleteConfirmResponder = nil
            }
        } message: {
            Text("此操作将移动到最近删除，可在设置中恢复。")
        }
        .onAppear {
            isEditingMode = false
            editMode = .inactive
            onEditingModeChanged?(false)
        }
        .onChange(of: isEditingMode) { newValue in
            editMode = newValue ? .active : .inactive
            onEditingModeChanged?(newValue)
        }
        .onChange(of: date) { _ in
            isEditingMode = false
            editMode = .inactive
            editingTask = nil
            onEditingModeChanged?(false)
        }
    }

    private func saveEditsAndDismiss() {
        let labels = tempLabelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let offsets = tempReminderOffsetsText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let t = editingTask {
            onUpdateDetails?(t.id, tempTitle, tempDueDate, tempStartAt, tempRepeat, tempRepeatEnd, tempPriority, tempNotes, labels, tempDuration, offsets)
        }
        editingTask = nil
    }

    private func loadEdits(_ task: DailyTask) {
        tempTitle = task.title
        tempDueDate = task.dueDate
        tempStartAt = task.startAt ?? Date()
        tempRepeat = task.repeatRule
        tempRepeatEnd = task.repeatEndDate
        tempPriority = task.priority
        tempNotes = task.notes
        tempLabelsText = task.labels.joined(separator: ", ")
        tempDuration = task.durationMinutes
        tempReminderOffsetsText = task.reminderOffsets.map { String($0) }.joined(separator: ", ")
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.readableTitle)
                        .font(.system(size: 28, weight: .bold))
                    Text(relativeSubtitle(for: date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 14) {
                    Button { isEditingMode.toggle() } label: {
                        Image(systemName: isEditingMode ? "line.3.horizontal.circle.fill" : "line.3.horizontal.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isEditingMode ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                    Button { withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) { toggleTools() } } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(showTools ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if showTools { toolsBar }
            HStack(spacing: 12) {
                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 8)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: completionRatio)
                        .stroke(AngularGradient(colors: [theme.primary.opacity(0.95), theme.secondary.opacity(0.8), theme.primary.opacity(0.95)], center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.25), value: completionRatio)
                    Text("\(Int(completionRatio * 100))%")
                        .font(.system(size: 10, weight: .bold))
                }
                Text("完成 \(completionText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func toggleTools() { showTools.toggle() }

    private var toolsBar: some View {
        VStack(spacing: 10) {
            Picker("筛选", selection: $filter) {
                ForEach(Filter.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("在当天列表内搜索标题、备注或标签", text: $localQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !localQuery.isEmpty {
                    Button(role: .cancel) { localQuery = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                // 未完推明天（移入工具条，默认收起）
                Button {
                    NotificationCenter.default.post(name: .deferTasksRequested, object: date)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.right")
                        Text("推明天")
                    }
                }
                .buttonStyle(.bordered)
                .tint(theme.primary)
                .disabled(tasks.filter { !$0.isDone && $0.repeatRule == .none && $0.dueDate == nil }.isEmpty)
            }
            if !allLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: { selectedLabel = nil }) {
                            Text("全部标签")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill((selectedLabel == nil) ? Color.blue.opacity(0.15) : Color(.tertiarySystemFill)))
                        }
                        ForEach(allLabels, id: \.self) { lbl in
                            Button(action: { selectedLabel = (selectedLabel == lbl ? nil : lbl) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag")
                                    Text(lbl)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill((selectedLabel == lbl) ? Color.blue.opacity(0.2) : Color(.tertiarySystemFill)))
                            }
                        }
                    }
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var taskList: some View {
        ScrollViewReader { proxy in
            List {
                if filteredTasks.isEmpty {
                    VStack(spacing: 10) {
                        EmptyIllustrationView(theme: theme.primary)
                        Button {
                            aiPromptDraft = "明天 9 点提醒我喝水，标签健康，高优先级"
                            isShowingAISheet = true
                        } label: {
                            Label("试试让 AI 帮你创建", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                if isEditingMode {
                    ForEach(filteredTasks) { task in
                        taskRow(task)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .id(task.id)
                    }
                    .onMove { indices, newOffset in
                        onReorder?(indices, newOffset)
                    }
                } else {
                    ForEach(filteredTasks) { task in
                        taskRow(task)
                            .onLongPressGesture(minimumDuration: 0.35) { isEditingMode = true; onEditingModeChanged?(true) }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .id(task.id)
                    }
                    .onDelete {
                        idx in pendingDelete = idx; showDeleteAlert = true; Haptics.warning()
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .listStyle(.plain)
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            // 禁止列表 diff 动画，避免添加/删除时的莫名动画
            .transaction { t in t.animation = nil }
        }
    }

    @ViewBuilder
    private func taskRow(_ task: DailyTask) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: {
                    onToggle(task.id)
                    Haptics.light()
                }) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(task.isDone ? .green : .secondary)
                        .scaleEffect(task.isDone ? 1.15 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.9), value: task.isDone)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 18))
                            .strikethrough(task.isDone, color: .secondary)
                            .foregroundStyle(task.isDone ? .secondary : .primary)
                        if let start = task.startAt {
                            Text(timeString(start))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                                .accessibilityLabel(Text("开始时间 \(voiceTimeString(start))"))
                        }
                        if task.priority != .none {
                            Text(task.priority.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(priorityColor(task.priority).opacity(0.15)))
                                .foregroundStyle(priorityColor(task.priority))
                        }
                    }
                    HStack(spacing: 6) {
                        if task.repeatRule != .none { chip(text: "重复", color: .purple) }
                        if task.dueDate != nil { chip(text: "截止", color: .orange) }
                        if !task.labels.isEmpty { chip(text: task.labels.joined(separator: ", "), color: .blue) }
                    }
                }
                Spacer()
                if !isEditingMode {
                    Button { editingTask = task } label: {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.8))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture { if !isEditingMode { showNotesTask = task } }
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            // 丝滑滑动删除：自定义行内拖拽，显示渐变背景与图标（带确认，回弹复位）
            .modifier(SwipeToActModifier(
                isEnabled: !isEditingMode && !disableRowSwipe,
                onRequestDelete: { responder in
                    pendingDeleteIdBySwipe = task.id
                    deleteConfirmResponder = responder
                    showSwipeDeleteAlert = true
                },
                onComplete: {
                    if !task.isDone {
                        onToggle(task.id)
                        Haptics.success()
                    }
                }
            ))

            if let due = task.dueDate, task.startAt ?? task.createdAt <= Date() {
                progressOrOverdueView(task: task, due: due)
            }
        }
    }

    @ViewBuilder
    private func progressOrOverdueView(task: DailyTask, due: Date) -> some View {
        if !task.isDone && Date() <= due {
            progressBar(createdAt: task.startAt ?? task.createdAt, dueDate: due)
        } else if Date() > due {
            overdueBadge(dueDate: due)
        }
    }

    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p { case .none: return .gray; case .low: return .blue; case .medium: return .orange; case .high: return .red }
    }

    private func chip(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.gradient))
    }

    private func progressBar(createdAt: Date, dueDate: Date) -> some View {
        let total = max(dueDate.timeIntervalSince(createdAt), 60)
        let elapsed = max(Date().timeIntervalSince(createdAt), 0)
        let ratio = min(max(elapsed / total, 0), 1)
        let color = progressColor(for: ratio)
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(LinearGradient(colors: [color.opacity(0.9), color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, CGFloat(ratio) * geo.size.width))
                }
            }
            .frame(height: 10)
            HStack {
                Text("进度 \(Int(ratio * 100))%").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(dueDateLabel(dueDate)).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    private func progressColor(for ratio: Double) -> Color { ratio < 0.5 ? .blue : (ratio < 0.75 ? .orange : .red) }

    private func dueDateLabel(_ due: Date) -> String { let f = DateFormatter(); f.dateFormat = "MM/dd HH:mm"; return "截止 " + f.string(from: due) }
    private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date) }
    private func voiceTimeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateStyle = .none; f.timeStyle = .short; return f.string(from: date) }

    private func overdueBadge(dueDate: Date) -> some View {
        let days = overdueDays(since: dueDate)
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
            Text("已逾期 \(days) 天").font(.caption).foregroundStyle(.red)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.red.opacity(0.12)))
    }

    private func overdueDays(since due: Date) -> Int {
        let secs = max(Date().timeIntervalSince(due), 0)
        let days = Int(ceil(secs / 86_400))
        return max(days, 1)
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
            TextField("添加任务或输入想做的事…", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .onSubmit(add)
                .focused($isAddBarFocused)
            Spacer()
            // 手动创建（圆形按钮）
            Button(action: add) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            // AI 创建（魔法棒）
            Button(action: { aiPromptDraft = newTaskTitle; isShowingAISheet = true }) {
                Image(systemName: "wand.and.stars").font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(.purple)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemBackground))
        )
        .padding(.bottom, isAddBarFocused ? max(0, keyboard.currentHeight) : 0)
        .animation(nil, value: keyboard.currentHeight)
        // 已移除：AI 建议安全区 inset
    }

    private func relativeSubtitle(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
        switch diff {
        case 0: return "今天"
        case 1: return "明天"
        case -1: return "昨天"
        case 2: return "后天"
        case -2: return "前天"
        case let d where d > 2: return "\(d)天后"
        default: return "\(-diff)天前"
        }
    }

    private func tempRepeatPickerTag(_ rule: RepeatRule) -> Int { switch rule { case .none: return 0; case .everyDay: return 1; case .everyNDays(let n): return n } }
    private func tagToRepeat(_ tag: Int) -> RepeatRule { switch tag { case 0: return .none; case 1: return .everyDay; default: return .everyNDays(max(2, tag)) } }

    private func add() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        onAddTask(title)
        newTaskTitle = ""
    }

    private func applySuggestion(_ text: String) {
        aiPromptDraft = text
        isShowingAISheet = true
        Haptics.light()
    }
}

// MARK: - 丝滑滑动删除修饰器（类似 Gmail）
private struct SwipeToActModifier: ViewModifier {
    let isEnabled: Bool
    // 删除前确认：回传一个 responder，调用 responder(true/false) 以通知是否删除
    let onRequestDelete: (@escaping (Bool) -> Void) -> Void
    // 右滑完成：无确认，触发即执行
    let onComplete: () -> Void
    @State private var offsetX: CGFloat = 0
    @State private var isDragging: Bool = false

    private let revealWidth: CGFloat = 84   // 露出按钮宽度
    private let commitThreshold: CGFloat = 120 // 触发删除阈值
    private let completeThreshold: CGFloat = 110 // 触发完成阈值（右滑）

    func body(content: Content) -> some View {
        ZStack {
            // 左侧（右滑完成）背景
            HStack {
                let pc = min(1, max(0, (offsetX) / completeThreshold))
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .scaleEffect(0.8 + 0.2 * pc)
                        .opacity(isEnabled ? (0.4 + 0.6 * pc) : 0)
                    Spacer()
                }
                .padding(.leading, 16)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [.green.opacity(0.85), .green], startPoint: .leading, endPoint: .trailing))
                .opacity(isEnabled && offsetX > 0 ? 1 : 0)
                Spacer().frame(width: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 右侧（左滑删除）背景
            HStack {
                Spacer().frame(width: 0)
                let pd = min(1, max(0, (-offsetX) / commitThreshold))
                HStack {
                    Spacer()
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .scaleEffect(0.7 + 0.3 * pd)
                        .opacity(isEnabled ? (0.4 + 0.6 * pd) : 0)
                        .padding(.trailing, 20)
                }
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [.red.opacity(0.85), .red], startPoint: .leading, endPoint: .trailing))
                .opacity(isEnabled && offsetX < 0 ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 前景内容
            content
                .offset(x: isEnabled ? offsetX : 0)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { v in
                    guard isEnabled else { return }
                    isDragging = true
                    let dx = v.translation.width
                    // 允许双向：左滑删除 / 右滑完成
                    offsetX = max(-200, min(200, dx))
                }
                .onEnded { v in
                    guard isEnabled else { return }
                    isDragging = false
                    let dx = v.translation.width
                    if dx >= completeThreshold {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) { offsetX = 0 }
                        Haptics.light()
                        onComplete()
                    } else if dx <= -commitThreshold {
                        // 回弹复位后再请求确认
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) { offsetX = 0 }
                        Haptics.light()
                        onRequestDelete { confirmed in
                            if confirmed {
                                Haptics.warning()
                            }
                        }
                    } else if dx <= -revealWidth {
                        // 停在露出位置（左）
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) { offsetX = -revealWidth }
                    } else if dx >= revealWidth {
                        // 停在露出位置（右）
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) { offsetX = revealWidth }
                    } else {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.95)) { offsetX = 0 }
                    }
                }
        )
    }
}

// SuggestionChip 已迁移到 UIComponents.swift 作为公共组件

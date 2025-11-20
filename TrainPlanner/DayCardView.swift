import SwiftUI

struct DayCardView: View {
    let date: Date
    let tasks: [DailyTask]
    let theme: ThemeColor
    let onToggle: (UUID) -> Void
    let onAddTask: (String) -> Void
    var onAIPrompt: ((String, Date) -> Void)? = nil
    let onDelete: (IndexSet) -> Void
    let onDeleteById: ((UUID) -> Void)?
    let onReorder: ((IndexSet, Int) -> Void)?
    
    // 兼容旧接口参数（暂不使用或仅做简单适配）
    var disableRowSwipe: Bool = false
    var onUpdateDetails: ((UUID, String?, Date?, Date?, RepeatRule, Date?, TaskPriority?, String?, [String]?, Int?, [Int]?) -> Void)? = nil
    var onEditingModeChanged: ((Bool) -> Void)? = nil

    @State private var newTaskTitle: String = ""
    @State private var editingTask: DailyTask? = nil
    @State private var isShowingAISheet: Bool = false
    @State private var aiPromptDraft: String = ""
    
    @State private var searchText: String = ""
    @State private var filter: Filter = .all
    
    @FocusState private var isInputFocused: Bool
    
    enum Filter: String, CaseIterable, Identifiable {
        case all = "全部", todo = "未完成", done = "已完成"
        var id: String { rawValue }
    }

    var filteredTasks: [DailyTask] {
        let base = tasks.filter {
            switch filter {
            case .all: return true
            case .todo: return !$0.isDone
            case .done: return $0.isDone
            }
        }
        if searchText.isEmpty { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏（模拟原生大标题，因为外层 NavigationTitle 可能被 TabView 占用）
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.readableTitle)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(relativeSubtitle(for: date))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // 简单的进度指示
                if !tasks.isEmpty {
                    ZStack {
                        Circle()
                            .stroke(Color(.tertiarySystemFill), lineWidth: 4)
                            .frame(width: 32, height: 32)
                        Circle()
                            .trim(from: 0, to: completionRatio)
                            .stroke(theme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .background(Color(.systemGroupedBackground)) // 与 List 背景一致

            List {
                // 任务列表 Section
                Section {
                    if filteredTasks.isEmpty {
                        if searchText.isEmpty {
                           emptyStateView
                        } else {
                            Text("无匹配任务")
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        }
                    } else {
                        ForEach(filteredTasks) { task in
                            NativeTaskRow(task: task, onToggle: onToggle)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingTask = task
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let deleteById = onDeleteById {
                                            withAnimation { deleteById(task.id) }
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                    Button {
                                        editingTask = task
                                    } label: {
                                        Label("详情", systemImage: "info.circle")
                                    }
                                    .tint(.gray)
                                }
                        }
                        .onMove { indices, newOffset in
                            onReorder?(indices, newOffset)
                        }
                    }
                } header: {
                    HStack {
                        Text("\(filteredTasks.count) 个任务")
                        Spacer()
                        Menu {
                            Picker("筛选", selection: $filter) {
                                ForEach(Filter.allCases) { f in
                                    Label(f.rawValue, systemImage: iconForFilter(f)).tag(f)
                                }
                            }
                        } label: {
                            Label(filter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            
            // 底部快速添加栏
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    Button {
                        isShowingAISheet = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                            .foregroundStyle(.purple)
                    }
                    
                    HStack {
                        if !isInputFocused {
                            Image(systemName: "plus.circle.fill").foregroundStyle(.secondary)
                        }
                        TextField("添加新任务...", text: $newTaskTitle)
                            .focused($isInputFocused)
                            .submitLabel(.done)
                            .onSubmit(addNewTask)
                        if !newTaskTitle.isEmpty {
                            Button {
                                addNewTask()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(theme.primary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(12)
                .background(Color(.systemBackground))
            }
        }
        // Sheet: 任务详情编辑
        .sheet(item: $editingTask) { task in
            TaskEditorView(task: task) { title, due, start, repeatRule, repeatEnd, priority, notes, labels, duration, offsets in
                onUpdateDetails?(task.id, title, due, start, repeatRule, repeatEnd, priority, notes, labels, duration, offsets)
            }
        }
        // Sheet: AI 建议
        .sheet(isPresented: $isShowingAISheet) {
            AIComposeView(date: date, draft: aiPromptDraft, onCancel: { isShowingAISheet = false }, onSubmit: { prompt in
                isShowingAISheet = false
                aiPromptDraft = ""
                if let ai = onAIPrompt {
                    ai(prompt, date)
                } else {
                    onAddTask(prompt)
                }
            })
        }
        .onAppear {
            // 清除之前的编辑模式
            onEditingModeChanged?(false)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("没有任务")
                .foregroundStyle(.secondary)
            Button("让 AI 帮我规划") {
                isShowingAISheet = true
            }
            .buttonStyle(.bordered)
            .tint(.purple)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .listRowBackground(Color.clear)
    }
    
    private var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        let done = tasks.filter { $0.isDone }.count
        return Double(done) / Double(tasks.count)
    }
    
    private func iconForFilter(_ f: Filter) -> String {
        switch f {
        case .all: return "tray"
        case .todo: return "circle"
        case .done: return "checkmark.circle"
        }
    }
    
    private func addNewTask() {
        let t = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onAddTask(t)
        newTaskTitle = ""
        isInputFocused = true // 保持焦点方便连续输入
    }
    
    private func relativeSubtitle(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
        switch diff {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return date.formatted(date: .long, time: .omitted)
        }
    }
}

// MARK: - 原生风格的任务行
struct NativeTaskRow: View {
    let task: DailyTask
    let onToggle: (UUID) -> Void
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button {
                onToggle(task.id)
                Haptics.medium()
            } label: {
                Image(systemName: task.isDone ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isDone, color: .secondary)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                
                // 任务元数据行 (Priority, Time, Tags)
                HStack(spacing: 8) {
                    if task.priority != .none {
                        Text(prioritySymbol(task.priority))
                            .foregroundStyle(priorityColor(task.priority))
                            .font(.caption)
                    }
                    
                    if let time = task.startAt {
                        Text(time.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if !task.labels.isEmpty {
                        Text("# \(task.labels.joined(separator: " "))")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        default: return .gray
        }
    }
    
    func prioritySymbol(_ p: TaskPriority) -> String {
        switch p {
        case .high: return "!!!"
        case .medium: return "!!"
        case .low: return "!"
        default: return ""
        }
    }
}

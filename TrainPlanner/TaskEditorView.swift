import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var langMgr = LanguageManager.shared

    let task: DailyTask
    let onSave: (String, Date?, Date?, RepeatRule, Date?, TaskPriority, String, [String], Int?, [Int]) -> Void

    // Form States
    @State private var title: String
    @State private var notes: String
    
    // Time
    @State private var hasStartTime: Bool
    @State private var startAt: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    
    // Repeat
    @State private var repeatRule: RepeatRule
    @State private var hasRepeatEnd: Bool
    @State private var repeatEnd: Date
    
    // Details
    @State private var priority: TaskPriority
    @State private var labelsText: String
    @State private var durationMinutes: Int?
    @State private var reminderOffsetsText: String

    init(task: DailyTask, onSave: @escaping (String, Date?, Date?, RepeatRule, Date?, TaskPriority, String, [String], Int?, [Int]) -> Void) {
        self.task = task
        self.onSave = onSave
        
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
        
        let start = task.startAt
        _hasStartTime = State(initialValue: start != nil)
        _startAt = State(initialValue: start ?? Date())
        
        let due = task.dueDate
        _hasDueDate = State(initialValue: due != nil)
        _dueDate = State(initialValue: due ?? Date())
        
        _repeatRule = State(initialValue: task.repeatRule)
        
        let rEnd = task.repeatEndDate
        _hasRepeatEnd = State(initialValue: rEnd != nil)
        _repeatEnd = State(initialValue: rEnd ?? Date().addingTimeInterval(7*24*3600))
        
        _priority = State(initialValue: task.priority)
        _labelsText = State(initialValue: task.labels.joined(separator: ", "))
        _durationMinutes = State(initialValue: task.durationMinutes)
        _reminderOffsetsText = State(initialValue: task.reminderOffsets.map { String($0) }.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. 核心信息区
                Section {
                    TextField(L("field.title"), text: $title)
                        .font(.body)
                    
                    TextField(L("field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundStyle(.secondary)
                }
                
                // 2. 时间与重复
                Section {
                    // Start Time
                    Toggle(isOn: $hasStartTime) {
                        Label {
                            Text(L("field.start_time"))
                        } icon: {
                            Image(systemName: "clock").foregroundStyle(.blue)
                        }
                    }
                    if hasStartTime {
                        DatePicker(L("field.start_time"), selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                    }
                    
                    // Due Date
                    Toggle(isOn: $hasDueDate.animation()) {
                        Label {
                            Text("截止日期")
                        } icon: {
                            Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(.red)
                        }
                    }
                    .disabled(repeatRule != .none) // 互斥逻辑
                    
                    if hasDueDate {
                        DatePicker("截止时间", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    // Repeat
                    Picker(selection: $repeatRule) {
                        Text(L("rep.none")).tag(RepeatRule.none)
                        Text(L("rep.every_day")).tag(RepeatRule.everyDay)
                        Text(L("rep.every_7_days")).tag(RepeatRule.everyNDays(7))
                        // 更多选项可按需添加
                    } label: {
                        Label {
                            Text(L("field.repeat"))
                        } icon: {
                            Image(systemName: "repeat").foregroundStyle(.gray)
                        }
                    }
                    .disabled(hasDueDate) // 互斥逻辑
                    
                    if repeatRule != .none {
                        Toggle("设置结束日期", isOn: $hasRepeatEnd.animation())
                        if hasRepeatEnd {
                            DatePicker("结束日", selection: $repeatEnd, displayedComponents: .date)
                        }
                    }
                } header: {
                    Text("时间与日程")
                } footer: {
                    if repeatRule != .none {
                        Text(L("status.conflict_due"))
                    } else if hasDueDate {
                        Text(L("status.conflict_repeat"))
                    }
                }
                
                // 3. 属性与标签
                Section {
                    Picker(selection: $priority) {
                        ForEach(TaskPriority.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    } label: {
                        Label {
                            Text(L("field.priority"))
                        } icon: {
                            Image(systemName: "flag.fill").foregroundStyle(priorityColor(priority))
                        }
                    }
                    
                    HStack {
                        Label {
                            Text("标签")
                        } icon: {
                            Image(systemName: "tag.fill").foregroundStyle(.blue)
                        }
                        Spacer()
                        TextField("例如: 工作, 学习", text: $labelsText)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 4. 高级
                Section("高级") {
                    HStack {
                        Text("预计时长 (分钟)")
                        Spacer()
                        TextField("0", value: $durationMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("提前提醒 (分钟)")
                        Spacer()
                        TextField("例如: 10, 30", text: $reminderOffsetsText)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(title.isEmpty ? L("nav.edit_task") : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("act.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("act.save")) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func save() {
        let labels = labelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let offsets = reminderOffsetsText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        // 构造最终参数
        let finalStart = hasStartTime ? startAt : nil
        let finalDue = hasDueDate ? dueDate : nil
        let finalRepeatEnd = (repeatRule != .none && hasRepeatEnd) ? repeatEnd : nil
        
        onSave(title, finalDue, finalStart, repeatRule, finalRepeatEnd, priority, notes, labels, durationMinutes, offsets)
        dismiss()
    }
    
    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        default: return .gray
        }
    }
}

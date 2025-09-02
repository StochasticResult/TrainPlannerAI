import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let task: DailyTask
    let onSave: (String, Date?, Date?, RepeatRule, Date?, TaskPriority, String, [String], Int?, [Int]) -> Void

    @State private var title: String
    @State private var startAt: Date?
    @State private var dueDate: Date?
    @State private var repeatRule: RepeatRule
    @State private var repeatEnd: Date?
    @State private var priority: TaskPriority
    @State private var notes: String
    @State private var labelsText: String
    @State private var durationMinutes: Int?
    @State private var reminderOffsetsText: String

    init(task: DailyTask, onSave: @escaping (String, Date?, Date?, RepeatRule, Date?, TaskPriority, String, [String], Int?, [Int]) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _startAt = State(initialValue: task.startAt)
        _dueDate = State(initialValue: task.dueDate)
        _repeatRule = State(initialValue: task.repeatRule)
        _repeatEnd = State(initialValue: task.repeatEndDate)
        _priority = State(initialValue: task.priority)
        _notes = State(initialValue: task.notes)
        _labelsText = State(initialValue: task.labels.joined(separator: ", "))
        _durationMinutes = State(initialValue: task.durationMinutes)
        _reminderOffsetsText = State(initialValue: task.reminderOffsets.map { String($0) }.joined(separator: ", "))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("标题")) { TextField("任务标题", text: $title) }
                Section(header: Text("开始/截止"), footer: Text(repeatRule != .none ? "已设置重复：截止不可用" : "")) {
                    Toggle(isOn: Binding(get: { startAt != nil }, set: { $0 ? (startAt = startAt ?? Date()) : (startAt = nil) })) { Text("启用开始时间") }
                    if startAt != nil { DatePicker("开始时间", selection: Binding(get: { startAt ?? Date() }, set: { startAt = $0 }), displayedComponents: [.date, .hourAndMinute]) }
                    Toggle(isOn: Binding(get: { dueDate != nil }, set: { on in
                        if on {
                            // 开启截止则清空重复
                            repeatRule = .none
                            repeatEnd = nil
                            dueDate = dueDate ?? Date()
                        } else {
                            dueDate = nil
                        }
                    })) { Text("启用截止日期") }
                    .disabled(repeatRule != .none)
                    if dueDate != nil { DatePicker("截止时间", selection: Binding(get: { dueDate ?? Date() }, set: { dueDate = $0 }), displayedComponents: [.date, .hourAndMinute]) }
                }
                Section(header: Text("重复"), footer: Text(dueDate != nil ? "已设置截止：重复不可用" : "")) {
                    Picker("规则", selection: Binding(get: { repeatRule }, set: { newValue in
                        // 设置重复则清空截止
                        repeatRule = newValue
                        if newValue != .none {
                            dueDate = nil
                        }
                    })) {
                        Text("不重复").tag(RepeatRule.none)
                        Text("每天").tag(RepeatRule.everyDay)
                        Text("每2天").tag(RepeatRule.everyNDays(2))
                        Text("每3天").tag(RepeatRule.everyNDays(3))
                        Text("每7天").tag(RepeatRule.everyNDays(7))
                    }
                    .disabled(dueDate != nil)
                    if repeatRule != .none {
                        Toggle(isOn: Binding(get: { repeatEnd != nil }, set: { $0 ? (repeatEnd = repeatEnd ?? Date().addingTimeInterval(7*24*3600)) : (repeatEnd = nil) })) { Text("设置重复结束日") }
                        if repeatEnd != nil { DatePicker("结束日", selection: Binding(get: { repeatEnd ?? Date() }, set: { repeatEnd = $0 }), displayedComponents: [.date]) }
                    }
                }
                Section(header: Text("优先级与标签")) {
                    Picker("优先级", selection: $priority) { ForEach(TaskPriority.allCases) { p in Text(p.displayName).tag(p) } }
                    .pickerStyle(.menu)
                    TextField("标签（逗号分隔）", text: $labelsText)
                }
                Section(header: Text("备注")) { TextEditor(text: $notes).frame(minHeight: 80) }
                Section(header: Text("时长与提醒")) {
                    TextField("预计时长（分钟）", text: Binding(get: { durationMinutes.map { String($0) } ?? "" }, set: { durationMinutes = Int($0.filter { $0.isNumber }) })).keyboardType(.numberPad)
                    TextField("提醒（分钟，逗号分隔，表示提前）", text: $reminderOffsetsText)
                }
            }
            .navigationTitle("编辑任务")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let labels = labelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        let offsets = reminderOffsetsText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        onSave(title, dueDate, startAt, repeatRule, repeatEnd, priority, notes, labels, durationMinutes, offsets)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}

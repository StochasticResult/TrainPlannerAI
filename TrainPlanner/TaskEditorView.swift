import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var langMgr = LanguageManager.shared // Observe language changes

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
                Section(header: Text(L("field.title"))) { TextField(L("field.title"), text: $title) }
                Section(header: Text(L("field.start_due")), footer: Text(repeatRule != .none ? L("status.conflict_due") : "")) {
                    Toggle(isOn: Binding(get: { startAt != nil }, set: { $0 ? (startAt = startAt ?? Date()) : (startAt = nil) })) { Text(L("field.enable_start")) }
                    if startAt != nil { DatePicker(L("field.start_time"), selection: Binding(get: { startAt ?? Date() }, set: { startAt = $0 }), displayedComponents: [.date, .hourAndMinute]) }
                    Toggle(isOn: Binding(get: { dueDate != nil }, set: { on in
                        if on {
                            // 开启截止则清空重复
                            repeatRule = .none
                            repeatEnd = nil
                            dueDate = dueDate ?? Date()
                        } else {
                            dueDate = nil
                        }
                    })) { Text(L("field.enable_due")) }
                    .disabled(repeatRule != .none)
                    if dueDate != nil { DatePicker(L("field.due_time"), selection: Binding(get: { dueDate ?? Date() }, set: { dueDate = $0 }), displayedComponents: [.date, .hourAndMinute]) }
                }
                Section(header: Text(L("field.repeat")), footer: Text(dueDate != nil ? L("status.conflict_repeat") : "")) {
                    Picker(L("field.repeat_rule"), selection: Binding(get: { repeatRule }, set: { newValue in
                        // 设置重复则清空截止
                        repeatRule = newValue
                        if newValue != .none {
                            dueDate = nil
                        }
                    })) {
                        Text(L("rep.none")).tag(RepeatRule.none)
                        Text(L("rep.every_day")).tag(RepeatRule.everyDay)
                        Text(L("rep.every_2_days")).tag(RepeatRule.everyNDays(2))
                        Text(L("rep.every_3_days")).tag(RepeatRule.everyNDays(3))
                        Text(L("rep.every_7_days")).tag(RepeatRule.everyNDays(7))
                    }
                    .disabled(dueDate != nil)
                    if repeatRule != .none {
                        Toggle(isOn: Binding(get: { repeatEnd != nil }, set: { $0 ? (repeatEnd = repeatEnd ?? Date().addingTimeInterval(7*24*3600)) : (repeatEnd = nil) })) { Text(L("field.repeat_end")) }
                        if repeatEnd != nil { DatePicker(L("field.end_date"), selection: Binding(get: { repeatEnd ?? Date() }, set: { repeatEnd = $0 }), displayedComponents: [.date]) }
                    }
                }
                Section(header: Text(L("field.prio_tags"))) {
                    Picker(L("field.priority"), selection: $priority) { ForEach(TaskPriority.allCases) { p in Text(p.displayName).tag(p) } }
                    .pickerStyle(.menu)
                    TextField(L("field.tags_hint"), text: $labelsText)
                }
                Section(header: Text(L("field.notes"))) { TextEditor(text: $notes).frame(minHeight: 80) }
                Section(header: Text(L("field.duration_remind"))) {
                    TextField(L("field.duration_hint"), text: Binding(get: { durationMinutes.map { String($0) } ?? "" }, set: { durationMinutes = Int($0.filter { $0.isNumber }) })).keyboardType(.numberPad)
                    TextField(L("field.reminder_hint"), text: $reminderOffsetsText)
                }
            }
            .navigationTitle(L("nav.edit_task"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("act.save")) {
                        let labels = labelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        let offsets = reminderOffsetsText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        onSave(title, dueDate, startAt, repeatRule, repeatEnd, priority, notes, labels, durationMinutes, offsets)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button(L("act.cancel")) { dismiss() } }
            }
        }
    }
}

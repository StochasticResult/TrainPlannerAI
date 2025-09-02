import SwiftUI

struct TaskNotesView: View {
    @Environment(\.dismiss) private var dismiss

    let task: DailyTask
    let onSave: (String, String) -> Void

    @State private var title: String
    @State private var notes: String

    init(task: DailyTask, onSave: @escaping (String, String) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("标题")) {
                    TextField("标题", text: $title)
                }
                Section(header: Text("内容")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 180)
                }
            }
            .navigationTitle("详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(title, notes)
                        dismiss()
                    }
                }
            }
        }
    }
}

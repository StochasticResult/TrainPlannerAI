import SwiftUI

struct TaskNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var langMgr = LanguageManager.shared

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
                Section(header: Text(L("field.title"))) {
                    TextField(L("field.title"), text: $title)
                }
                Section(header: Text(L("field.content"))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 180)
                }
            }
            .navigationTitle(L("nav.details"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("act.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("act.save")) {
                        onSave(title, notes)
                        dismiss()
                    }
                }
            }
        }
    }
}

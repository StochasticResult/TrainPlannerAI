import SwiftUI
import Foundation

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: ChecklistStore
    let onSelect: (Date, UUID?) -> Void

    @State private var query: String = ""
    enum Status: String, CaseIterable, Identifiable { case all = "全部", todo = "未完成", done = "已完成"; var id: String { rawValue } }
    @State private var status: Status = .all

    private struct Item: Identifiable {
        let id: UUID
        let title: String
        let notes: String
        let labels: [String]
        let date: Date
        let isDone: Bool
    }

    private var items: [Item] {
        store.tasksById.values.map { t in
            Item(
                id: t.id,
                title: t.title,
                notes: t.notes,
                labels: t.labels,
                date: Calendar.current.startOfDay(for: t.startAt ?? t.createdAt),
                isDone: t.isDone
            )
        }
    }

    private var filtered: [Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { it in
            let statusOK: Bool = {
                switch status {
                case .all: return true
                case .todo: return !it.isDone
                case .done: return it.isDone
                }
            }()
            guard statusOK else { return false }
            if q.isEmpty { return false }
            if it.title.lowercased().contains(q) { return true }
            if it.notes.lowercased().contains(q) { return true }
            if it.labels.joined(separator: ",").lowercased().contains(q) { return true }
            return false
        }
        .sorted { ($0.date, $0.title) > ($1.date, $1.title) }
    }

    private var grouped: [(date: Date, items: [Item])] {
        let groups = Dictionary(grouping: filtered, by: { $0.date })
        return groups.keys.sorted(by: >).map { d in (d, groups[d]!.sorted { $0.title < $1.title }) }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索标题、备注或标签", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                Section {
                    Picker("状态", selection: $status) {
                        ForEach(Status.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    .pickerStyle(.segmented)
                }
                if grouped.isEmpty && !query.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "questionmark.circle").font(.system(size: 28)).foregroundStyle(.secondary)
                        Text("没有匹配项").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                ForEach(grouped, id: \.date) { group in
                    Section(header: Text(group.date.readableTitle)) {
                        ForEach(group.items) { it in
                            Button {
                                onSelect(group.date, it.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: it.isDone ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(it.isDone ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(it.title)
                                            .foregroundStyle(.primary)
                                        HStack(spacing: 6) {
                                            if !it.labels.isEmpty {
                                                Text(it.labels.joined(separator: ", "))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if !it.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                Text(it.notes)
                                                    .lineLimit(1)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}



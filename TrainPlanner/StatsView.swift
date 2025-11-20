import SwiftUI

struct StatsView: View {
    @ObservedObject var store: ChecklistStore
    @StateObject private var langMgr = LanguageManager.shared

    enum RangeKind: String, CaseIterable, Identifiable { 
        case last7, last30, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .last7: return L("stat.range_last7")
            case .last30: return L("stat.range_last30")
            case .all: return L("stat.range_all")
            }
        }
    }
    @State private var range: RangeKind = .last7

    private var filteredTasks: [DailyTask] {
        switch range {
        case .all:
            return Array(store.tasksById.values)
        case .last7:
            return filterBy(days: 7)
        case .last30:
            return filterBy(days: 30)
        }
    }

    private var total: Int { filteredTasks.count }
    private var doneCount: Int { filteredTasks.filter({ $0.isDone }).count }
    private var todoCount: Int { total - doneCount }

    private var labelCounts: [(String, Int)] {
        let labels = filteredTasks.flatMap { $0.labels }
        let grouped = Dictionary(grouping: labels, by: { $0 })
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    private var priorityCounts: [(TaskPriority, Int)] {
        let grouped = Dictionary(grouping: filteredTasks, by: { $0.priority })
        return TaskPriority.allCases.map { p in (p, grouped[p]?.count ?? 0) }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker(L("stat.range"), selection: $range) {
                        ForEach(RangeKind.allCases) { r in Text(r.label).tag(r) }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text(L("stat.overall"))) {
                    HStack {
                        Text(L("stat.total_tasks"))
                        Spacer()
                        Text("\(total)")
                    }
                    HStack {
                        Text(L("stat.completed"))
                        Spacer()
                        Text("\(doneCount)")
                    }
                    HStack {
                        Text(L("stat.incomplete"))
                        Spacer()
                        Text("\(todoCount)")
                    }
                    ProgressView(value: total == 0 ? 0 : Double(doneCount) / Double(total)) {
                        Text(L("stat.completion_rate"))
                    }
                }

                Section(header: Text(L("stat.priority_dist"))) {
                    ForEach(priorityCounts, id: \.0) { (p, c) in
                        HStack {
                            Text(p.displayName)
                            Spacer()
                            Text("\(c)")
                        }
                    }
                }

                Section(header: Text(L("stat.tags_top10"))) {
                    ForEach(Array(labelCounts.prefix(10)), id: \.0) { (label, c) in
                        HStack {
                            Text(label)
                            Spacer()
                            Text("\(c)")
                        }
                    }
                    if labelCounts.isEmpty {
                        Text(L("stat.no_tags")).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L("tab.stats"))
        }
    }

    private func filterBy(days: Int) -> [DailyTask] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date().addingTimeInterval(TimeInterval(-days * 86400)))
        return store.tasksById.values.filter { t in
            let day = cal.startOfDay(for: t.startAt ?? t.createdAt)
            return day >= start
        }
    }
}

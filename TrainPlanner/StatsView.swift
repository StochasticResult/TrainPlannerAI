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
        case .all: return Array(store.tasksById.values)
        case .last7: return filterBy(days: 7)
        case .last30: return filterBy(days: 30)
        }
    }

    private var total: Int { filteredTasks.count }
    private var doneCount: Int { filteredTasks.filter({ $0.isDone }).count }
    private var completionRate: Double { total == 0 ? 0 : Double(doneCount) / Double(total) }

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Range Picker
                    Picker(L("stat.range"), selection: $range) {
                        ForEach(RangeKind.allCases) { r in Text(r.label).tag(r) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Overview Cards Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Completion Rate Card
                        StatCard {
                            VStack {
                                ZStack {
                                    Circle()
                                        .stroke(Color(.tertiarySystemFill), lineWidth: 12)
                                    Circle()
                                        .trim(from: 0, to: completionRate)
                                        .stroke(Color.blue.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                    
                                    VStack(spacing: 2) {
                                        Text("\(Int(completionRate * 100))%")
                                            .font(.title2.bold())
                                        Text(L("stat.completion_rate"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(height: 100)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Counts Card
                        StatCard {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(doneCount)")
                                        .font(.title.bold())
                                        .foregroundStyle(.green)
                                    Text(L("stat.completed"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Divider()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(total)")
                                        .font(.title2.bold())
                                        .foregroundStyle(.primary)
                                    Text(L("stat.total_tasks"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        }
                    }
                    .padding(.horizontal)

                    // Sections
                    VStack(spacing: 16) {
                        // Priority Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L("stat.priority_dist"))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 1) {
                                ForEach(priorityCounts, id: \.0) { (p, c) in
                                    HStack {
                                        Text(p.displayName)
                                            .foregroundStyle(priorityColor(p))
                                        Spacer()
                                        Text("\(c)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                        
                        // Tags Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L("stat.tags_top10"))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if labelCounts.isEmpty {
                                Text(L("stat.no_tags"))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 1) {
                                    ForEach(Array(labelCounts.prefix(10)), id: \.0) { (label, c) in
                                        HStack {
                                            Image(systemName: "tag.fill")
                                                .font(.caption)
                                                .foregroundStyle(.blue.opacity(0.7))
                                            Text(label)
                                            Spacer()
                                            Text("\(c)")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemGroupedBackground))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.top)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("tab.stats"))
            .navigationBarTitleDisplayMode(.large)
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
    
    private func priorityColor(_ p: TaskPriority) -> Color {
        switch p {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .primary
        }
    }
}

// Helper Card View
struct StatCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2) // Optional shadow
    }
}

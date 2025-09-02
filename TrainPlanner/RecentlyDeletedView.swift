import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var checklist: ChecklistStore

    @State private var showClearAlert = false
    @State private var showSingleDeleteAlert = false
    @State private var pendingDeleteId: UUID? = nil

    private var items: [RecentlyDeleted] {
        Array(checklist.recentlyDeleted.values).sorted { $0.deletedAt > $1.deletedAt }
    }

    var body: some View {
        NavigationView {
            Group {
                if checklist.recentlyDeleted.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trash").font(.system(size: 42)).foregroundStyle(.secondary)
                        Text("暂无最近删除").foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.task.title).font(.body)
                                    Text(item.deletedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("恢复") {
                                    // 确保不会弹出删除确认
                                    pendingDeleteId = nil
                                    showSingleDeleteAlert = false
                                    checklist.restoreFromTrash(id: item.id)
                                    Haptics.success()
                                }
                                .buttonStyle(.borderless)
                                Button(role: .destructive) {
                                    pendingDeleteId = item.id
                                    showSingleDeleteAlert = true
                                } label: { Text("删除") }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onDelete { indexSet in
                            for i in indexSet { checklist.purgeTrash(id: items[i].id) }
                            Haptics.error()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("最近删除")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    if !checklist.recentlyDeleted.isEmpty {
                        Button("清空") { showClearAlert = true }
                    }
                }
            }
        }
        .alert("清空最近删除？", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { checklist.purgeAllTrash() }
        } message: {
            Text("此操作不可撤销")
        }
        .alert("彻底删除此项目？", isPresented: $showSingleDeleteAlert) {
            Button("取消", role: .cancel) { pendingDeleteId = nil }
            Button("删除", role: .destructive) {
                if let id = pendingDeleteId { checklist.purgeTrash(id: id) }
                pendingDeleteId = nil
            }
        } message: {
            Text("该操作不可恢复")
        }
    }
}



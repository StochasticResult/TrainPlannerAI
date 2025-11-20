import SwiftUI

struct RecentlyDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var checklist: ChecklistStore
    @StateObject private var langMgr = LanguageManager.shared

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
                        Text(L("ui.empty_deleted")).foregroundStyle(.secondary)
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
                                Button(L("act.restore")) {
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
                                } label: { Text(L("act.delete")) }
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
            .navigationTitle(L("nav.deleted"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("act.close")) { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    if !checklist.recentlyDeleted.isEmpty {
                        Button(L("act.clear")) { showClearAlert = true }
                    }
                }
            }
        }
        .alert(L("alert.clear_trash"), isPresented: $showClearAlert) {
            Button(L("act.cancel"), role: .cancel) {}
            Button(L("act.clear"), role: .destructive) { checklist.purgeAllTrash() }
        } message: {
            Text(L("alert.irreversible"))
        }
        .alert(L("alert.delete_item"), isPresented: $showSingleDeleteAlert) {
            Button(L("act.cancel"), role: .cancel) { pendingDeleteId = nil }
            Button(L("act.delete"), role: .destructive) {
                if let id = pendingDeleteId { checklist.purgeTrash(id: id) }
                pendingDeleteId = nil
            }
        } message: {
            Text(L("alert.irreversible"))
        }
    }
}

import SwiftUI
import UIKit

struct ContentView: View {
    @ObservedObject var store: ChecklistStore
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var langMgr = LanguageManager.shared
    
    @State private var selectedDate: Date = Date()
    @State private var isShowingProfile = false
    
    // AI States
    @State private var pendingOps: [AIService.Operation] = []
    @State private var pendingOpsSummary: String = ""
    @State private var showAIReview = false
    @State private var showAILoading = false
    @State private var aiLoadingText = ""
    @State private var showAITip = false
    @State private var aiTipText = ""
    
    init(store: ChecklistStore) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 主内容区
                DayCardView(
                    date: selectedDate,
                    tasks: store.tasks(for: selectedDate),
                    theme: profileStore.profile.theme,
                    onToggle: { id in store.toggle(taskId: id, completedOn: selectedDate) },
                    onAddTask: { title in store.addTask(title: title, for: selectedDate) },
                    onAIPrompt: handleAIPrompt,
                    onDelete: { offsets in store.deleteTasks(at: offsets, for: selectedDate) },
                    onDeleteById: { id in store.deleteTask(id: id) },
                    onReorder: { indices, newOffset in store.reorderTasks(for: selectedDate, from: indices, to: newOffset) },
                    onUpdateDetails: { id, title, due, start, repeatRule, repeatEnd, priority, notes, labels, duration, reminderOffsets in
                        store.setDetails(
                            taskId: id,
                            for: selectedDate,
                            title: title,
                            dueDate: due,
                            startAt: start,
                            repeatRule: repeatRule,
                            repeatEndDate: repeatEnd,
                            priority: priority,
                            notes: notes,
                            labels: labels,
                            durationMinutes: duration,
                            reminderOffsets: reminderOffsets
                        )
                    }
                )
                // 添加简单的左右滑动切换日期手势
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            let threshold: CGFloat = 60
                            if value.translation.width < -threshold {
                                withAnimation {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                }
                            } else if value.translation.width > threshold {
                                withAnimation {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                }
                            }
                        }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                            .id(selectedDate) // 强制刷新以避免某些状态问题
                        
                        if !Calendar.current.isDateInToday(selectedDate) {
                            Button("今天") {
                                withAnimation { selectedDate = Date() }
                            }
                            .font(.subheadline)
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingProfile = true
                    } label: {
                        if let data = profileStore.profile.avatarImageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill).frame(width: 32, height: 32).clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingProfile) {
                ProfileView(store: profileStore, checklist: store)
            }
            // AI Review Sheet
            .sheet(isPresented: $showAIReview) {
                AIReviewSheet(operations: pendingOps, aiSummary: pendingOpsSummary, onCancel: { showAIReview = false }, onConfirm: {
                    AIService.shared.execute(operations: pendingOps, dateContext: selectedDate, store: store)
                    showAIReview = false
                })
            }
            // AI Loading Overlay
            .overlay {
                if showAILoading {
                    AILoadingOverlay(text: aiLoadingText) {
                        AIService.shared.cancelActive(); showAILoading = false
                    }
                }
            }
            // AI Tip Overlay
            .overlay(alignment: .top) {
                if showAITip {
                    AIFriendlyTipView(text: aiTipText) {
                        withAnimation { showAITip = false }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                }
            }
        }
    }
    
    // MARK: - AI Logic
    private func handleAIPrompt(prompt: String, ctxDate: Date) {
        let needConfirm = AIConfig.shared.requireConfirmBeforeExecute
        if needConfirm {
            showAILoading = true; aiLoadingText = L("ui.ai_thinking")
            AIService.shared.plan(prompt: prompt, date: ctxDate, store: store) { ops, summary in
                showAILoading = false
                if summary.trimmingCharacters(in: .whitespacesAndNewlines) == AIService.noActionToken {
                    aiTipText = L("ai.tip_fail")
                    withAnimation { showAITip = true }
                    return
                }
                if ops.isEmpty && summary.isEmpty {
                    aiTipText = L("ai.tip_busy")
                    withAnimation { showAITip = true }
                } else {
                    pendingOps = ops; pendingOpsSummary = summary; showAIReview = true
                }
            }
        } else {
            showAILoading = true; aiLoadingText = L("ui.loading")
            AIService.shared.handlePrompt(prompt, date: ctxDate, store: store) { finalText in
                showAILoading = false
                let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == AIService.noActionToken {
                    aiTipText = L("ai.tip_fail")
                    withAnimation { showAITip = true }
                }
            }
        }
    }
}

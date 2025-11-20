import SwiftUI

struct AIReviewSheet: View {
    let operations: [AIService.Operation]
    let aiSummary: String
    let onCancel: () -> Void
    let onConfirm: () -> Void
    
    // Use LanguageManager to update UI on change, though this sheet usually dismisses
    @StateObject private var langMgr = LanguageManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                if !aiSummary.isEmpty {
                    Text(aiSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.horizontal)
                }
                List {
                    if operations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("ai.no_changes"))
                                .font(.headline)
                            Text(L("ai.no_changes_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                    } else {
                        ForEach(operations) { op in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: icon(for: op.kind)).foregroundStyle(color(for: op.kind))
                                    Text(op.summary).font(.headline)
                                }
                                Text(op.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(L("ai.review_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("act.cancel"), action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button(L("act.confirm"), action: onConfirm) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func icon(for kind: AIService.OperationKind) -> String {
        switch kind {
        case .create: return "plus.circle.fill"
        case .update: return "slider.horizontal.3"
        case .complete: return "checkmark.circle.fill"
        case .delete: return "trash.fill"
        case .restore: return "arrow.uturn.left.circle.fill"
        case .truncate: return "scissors"
        }
    }

    private func color(for kind: AIService.OperationKind) -> Color {
        switch kind {
        case .create: return .blue
        case .update: return .purple
        case .complete: return .green
        case .delete: return .red
        case .restore: return .orange
        case .truncate: return .pink
        }
    }
}

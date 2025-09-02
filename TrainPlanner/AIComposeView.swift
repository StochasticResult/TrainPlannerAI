import SwiftUI

struct AIComposeView: View {
    let date: Date
    @State var draft: String
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // 头部提示
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars").foregroundStyle(.purple)
                        Text(date.readableTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    // 已移除：AI 建议示例
                }

                // 输入框
                TextEditor(text: $draft)
                    .font(.system(size: 16))
                    .frame(minHeight: 160)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .focused($focused)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true } }

                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .navigationTitle("AI 助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") {
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { onCancel(); return }
                        onSubmit(text)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}



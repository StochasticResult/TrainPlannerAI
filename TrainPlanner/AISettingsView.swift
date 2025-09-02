import SwiftUI

struct AISettingsView: View {
    var body: some View {
        Form {
            Section(footer: Text("模型由 OpenAI Responses API 提供。执行前确认可在设置中关闭/打开。")) {
                AISettingsPanel()
            }
        }
        .navigationTitle("AI 助手设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}



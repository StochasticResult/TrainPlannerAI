import SwiftUI

struct AISettingsView: View {
    @StateObject private var cfg = AIConfig.shared
    @State private var apiKeyInput: String = ""
    @State private var showKey: Bool = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if showKey {
                        TextField("sk-...", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .onChange(of: apiKeyInput) { newValue in
                                cfg.setAPIKey(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                    } else {
                        SecureField("sk-...", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .onChange(of: apiKeyInput) { newValue in
                                cfg.setAPIKey(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                    }
                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("OpenAI Configuration")
            } footer: {
                Text("您的 API Key 仅存储在本地设备上，用于直接与 OpenAI 通信。")
            }
            
            Section {
                Picker(L("prof.model"), selection: $cfg.model) {
                    Text("gpt-4o").tag("gpt-4o")
                    Text("gpt-4o-mini").tag("gpt-4o-mini")
                }
                
                Toggle(L("prof.confirm_exec"), isOn: $cfg.requireConfirmBeforeExecute)
            } header: {
                Text("Behavior")
            } footer: {
                Text("开启确认后，AI 的操作建议将先展示给您，经您点击确认后才会生效。")
            }
            
            Section {
                Button("测试连接", role: .none) {
                    // TODO: Implement a quick ping check
                }
                .disabled(apiKeyInput.isEmpty)
            }
        }
        .navigationTitle(L("prof.ai_settings"))
        .onAppear {
            apiKeyInput = cfg.apiKey ?? ""
        }
    }
}

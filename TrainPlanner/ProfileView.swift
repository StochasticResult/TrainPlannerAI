import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProfileStore
    @ObservedObject var checklist: ChecklistStore

    @State private var showingImagePicker = false
    @State private var inputImage: UIImage? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("头像")) {
                    HStack {
                        Spacer()
                        Button {
                            showingImagePicker = true
                        } label: {
                            ZStack {
                                if let data = store.profile.avatarImageData, let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 88, height: 88)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 88, height: 88)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }

                Section(header: Text("基本信息")) {
                    TextField("昵称", text: Binding(
                        get: { store.profile.displayName },
                        set: { store.setDisplayName($0) }
                    ))
                    TextField("签名", text: Binding(
                        get: { store.profile.bio },
                        set: { store.setBio($0) }
                    ))
                }

                Section(header: Text("主题")) {
                    Picker("颜色", selection: Binding(
                        get: { store.profile.theme },
                        set: { store.setTheme($0) }
                    )) {
                        ForEach(ThemeColor.allCases) { theme in
                            HStack {
                                Circle().fill(theme.primary).frame(width: 16, height: 16)
                                Text(theme.rawValue)
                            }.tag(theme)
                        }
                    }
                    // 即时预览卡片
                    VStack(alignment: .leading, spacing: 8) {
                        Text("预览")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    BokehBackground(base: store.profile.theme.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                )
                                .shadow(color: store.profile.theme.primary.opacity(0.18), radius: 12, x: 0, y: 8)
                            HStack(spacing: 8) {
                                Circle().fill(store.profile.theme.primary).frame(width: 8, height: 8)
                                Text("今日进度 · 68%")
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("未完推明天")
                                    .font(.caption2)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(store.profile.theme.primary.opacity(0.15)))
                            }
                            .padding(12)
                        }
                        .frame(height: 72)
                    }
                    // 主题预设网格
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主题预设")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(ThemeColor.allCases) { preset in
                                Button {
                                    store.setTheme(preset)
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(LinearGradient(colors: [preset.primary.opacity(0.18), preset.primary.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        VStack(spacing: 6) {
                                            Circle().fill(preset.primary).frame(width: 16, height: 16)
                                            Text(preset.rawValue)
                                                .font(.caption2)
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(8)
                                    }
                                }
                                .buttonStyle(.plain)
                                .frame(height: 64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(preset == store.profile.theme ? preset.primary.opacity(0.6) : Color.black.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                    }
                }

                Section(header: Text("每日提醒")) {
                    Toggle("开启提醒", isOn: Binding(
                        get: { store.profile.reminderEnabled },
                        set: { store.setReminder(enabled: $0) }
                    ))
                    if store.profile.reminderEnabled {
                        DatePicker(
                            "时间",
                            selection: Binding(
                                get: {
                                    var comp = DateComponents()
                                    comp.hour = store.profile.reminderHour
                                    comp.minute = store.profile.reminderMinute
                                    return Calendar.current.date(from: comp) ?? Date()
                                },
                                set: { date in
                                    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                                    store.setReminderTime(hour: c.hour ?? 9, minute: c.minute ?? 0)
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                }

                Section(header: Text("iCloud"), footer: Text("开启后会通过 iCloud Key-Value Store 同步任务与排序。")) {
                    Toggle("启用 iCloud 同步", isOn: Binding(
                        get: { checklist.iCloudEnabled },
                        set: { checklist.setICloudSyncEnabled($0) }
                    ))
                    Button("立即同步") { checklist.syncNow() }
                        .disabled(!checklist.iCloudEnabled)
                }

                // 最近删除独立页面，不在此直接列出
            }
            .navigationTitle("我的档案")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: RecentlyDeletedView(checklist: checklist)) { Text("最近删除") }
                        NavigationLink(destination: StatsView(store: checklist)) { Text("统计") }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars").foregroundStyle(.purple)
                            Text("AI 助手设置").font(.body)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(.thinMaterial)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
                .onDisappear {
                    if let img = inputImage, let data = img.jpegData(compressionQuality: 0.9) {
                        store.setAvatar(imageData: data)
                    }
                }
        }
    }
}

// MARK: - AI 设置面板
struct AISettingsPanel: View {
    @StateObject private var cfg = AIConfig.shared
    @State private var apiKeyInput: String = AIConfig.shared.apiKey ?? ""

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(.purple)
                Text("模型").frame(width: 52, alignment: .leading)
                Spacer()
                Picker("模型", selection: $cfg.model) {
                    Text("gpt-5-nano").tag("gpt-5-nano")
                }
                .pickerStyle(.menu)
            }
            HStack {
                Image(systemName: "key.fill").foregroundStyle(.orange)
                Text("API Key").frame(width: 52, alignment: .leading)
                SecureField("sk-...", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Toggle("执行前需要确认", isOn: $cfg.requireConfirmBeforeExecute)
            HStack {
                Spacer()
                Button("保存") {
                    cfg.setAPIKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
        )
    }
}

// 简易系统相册选择器封装
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    func makeUIViewController(context: Context) -> some UIViewController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        }
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

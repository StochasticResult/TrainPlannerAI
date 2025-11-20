import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProfileStore
    @ObservedObject var checklist: ChecklistStore
    @StateObject private var langMgr = LanguageManager.shared

    @State private var showingImagePicker = false
    @State private var inputImage: UIImage? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L("prof.avatar"))) {
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

                Section(header: Text(L("prof.basic_info"))) {
                    TextField(L("prof.nickname"), text: Binding(
                        get: { store.profile.displayName },
                        set: { store.setDisplayName($0) }
                    ))
                    TextField(L("prof.bio"), text: Binding(
                        get: { store.profile.bio },
                        set: { store.setBio($0) }
                    ))
                    // Language Switcher
                    Picker(L("prof.language"), selection: $langMgr.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                }

                Section(header: Text(L("prof.theme"))) {
                    Picker(L("prof.color"), selection: Binding(
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
                        Text(L("prof.preview"))
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
                                Text(L("ui.today_progress") + " · 68%")
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(L("ui.defer_tmr"))
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
                        Text(L("prof.theme_presets"))
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

                Section(header: Text(L("prof.daily_reminder"))) {
                    Toggle(L("prof.enable_reminder"), isOn: Binding(
                        get: { store.profile.reminderEnabled },
                        set: { store.setReminder(enabled: $0) }
                    ))
                    if store.profile.reminderEnabled {
                        DatePicker(
                            L("prof.time"),
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

                Section(header: Text(L("prof.icloud")), footer: Text(L("prof.icloud_hint"))) {
                    Toggle(L("act.sync_now"), isOn: Binding(
                        get: { checklist.iCloudEnabled },
                        set: { checklist.setICloudSyncEnabled($0) }
                    ))
                    Button(L("act.sync_now")) { checklist.syncNow() }
                        .disabled(!checklist.iCloudEnabled)
                }
            }
            .navigationTitle(L("tab.profile"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("act.complete")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: RecentlyDeletedView(checklist: checklist)) { Text(L("nav.deleted")) }
                        NavigationLink(destination: StatsView(store: checklist)) { Text(L("tab.stats")) }
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
                            Text(L("prof.ai_settings")).font(.body)
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
    @StateObject private var langMgr = LanguageManager.shared
    @State private var apiKeyInput: String = AIConfig.shared.apiKey ?? ""

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(.purple)
                Text(L("prof.model")).frame(width: 52, alignment: .leading)
                Spacer()
                Picker(L("prof.model"), selection: $cfg.model) {
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
            Toggle(L("prof.confirm_exec"), isOn: $cfg.requireConfirmBeforeExecute)
            HStack {
                Spacer()
                Button(L("act.save")) {
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

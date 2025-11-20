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
        NavigationStack {
            List {
                // MARK: - Header (Avatar & Name)
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Button {
                                showingImagePicker = true
                            } label: {
                                ZStack {
                                    if let data = store.profile.avatarImageData, let ui = UIImage(data: data) {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 100, height: 100)
                                            .foregroundStyle(.tertiary)
                                    }
                                    
                                    // Edit Badge
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Image(systemName: "camera.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .padding(6)
                                                .background(Circle().fill(.blue))
                                                .offset(x: -4, y: -4)
                                        }
                                    }
                                    .frame(width: 100, height: 100)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            VStack(spacing: 4) {
                                Text(store.profile.displayName.isEmpty ? L("prof.nickname") : store.profile.displayName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                if !store.profile.bio.isEmpty {
                                    Text(store.profile.bio)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.bottom, 10)
                }
                
                // MARK: - Basic Info
                Section(L("prof.basic_info")) {
                    HStack {
                        Text(L("prof.nickname"))
                        Spacer()
                        TextField(L("prof.nickname"), text: Binding(
                            get: { store.profile.displayName },
                            set: { store.setDisplayName($0) }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text(L("prof.bio"))
                        Spacer()
                        TextField(L("prof.bio"), text: Binding(
                            get: { store.profile.bio },
                            set: { store.setBio($0) }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                    
                    Picker(L("prof.language"), selection: $langMgr.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                }
                
                // MARK: - Appearance
                Section(L("prof.theme")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ThemeColor.allCases) { theme in
                                Button {
                                    store.setTheme(theme)
                                } label: {
                                    Circle()
                                        .fill(theme.primary)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: store.profile.theme == theme ? 3 : 0)
                                                .opacity(0.3)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                                .opacity(store.profile.theme == theme ? 1 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    
                    // Preview removed to keep it clean, user can see theme color change in button
                }
                
                // MARK: - Notifications
                Section(L("prof.daily_reminder")) {
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
                
                // MARK: - Data & AI
                Section {
                    NavigationLink(destination: AISettingsView()) {
                        Label {
                            Text(L("prof.ai_settings"))
                        } icon: {
                            Image(systemName: "wand.and.stars").foregroundStyle(.purple)
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { checklist.iCloudEnabled },
                        set: { checklist.setICloudSyncEnabled($0) }
                    )) {
                        Label {
                            Text(L("prof.icloud"))
                        } icon: {
                            Image(systemName: "icloud").foregroundStyle(.blue)
                        }
                    }
                    
                    if checklist.iCloudEnabled {
                        Button {
                            checklist.syncNow()
                        } label: {
                            Label(L("act.sync_now"), systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                } footer: {
                    if checklist.iCloudEnabled {
                        Text(L("prof.icloud_hint"))
                    }
                }
                
                // MARK: - More
                Section {
                    NavigationLink(destination: RecentlyDeletedView(checklist: checklist)) {
                        Label(L("nav.deleted"), systemImage: "trash")
                    }
                    NavigationLink(destination: StatsView(store: checklist)) {
                        Label(L("tab.stats"), systemImage: "chart.bar.xaxis")
                    }
                }
            }
            .navigationTitle(L("tab.profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("act.close")) { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
                .onDisappear {
                    if let img = inputImage, let data = img.jpegData(compressionQuality: 0.8) {
                        store.setAvatar(imageData: data)
                    }
                }
        }
    }
}

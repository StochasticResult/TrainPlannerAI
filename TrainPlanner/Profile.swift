import Foundation
import SwiftUI

enum ThemeColor: String, CaseIterable, Codable, Identifiable {
    case blue, green, orange, purple, pink, teal

    var id: String { rawValue }

    var primary: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        }
    }

    var secondary: Color {
        primary.opacity(0.7)
    }
}

struct UserProfile: Codable {
    var displayName: String
    var bio: String
    var theme: ThemeColor
    var avatarImageData: Data?
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    static let `default` = UserProfile(
        displayName: "未命名",
        bio: "",
        theme: .blue,
        avatarImageData: nil,
        reminderEnabled: false,
        reminderHour: 9,
        reminderMinute: 0
    )
}

final class ProfileStore: ObservableObject {
    @Published var profile: UserProfile { didSet { save() } }

    private let defaultsKey = "user.profile.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        } else {
            profile = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        syncReminders()
    }

    func setAvatar(imageData: Data?) {
        profile.avatarImageData = imageData
    }

    func setDisplayName(_ name: String) { profile.displayName = name }
    func setBio(_ value: String) { profile.bio = value }
    func setTheme(_ theme: ThemeColor) { profile.theme = theme }

    func setReminder(enabled: Bool) {
        profile.reminderEnabled = enabled
        syncReminders()
    }

    func setReminderTime(hour: Int, minute: Int) {
        profile.reminderHour = hour
        profile.reminderMinute = minute
        syncReminders()
    }

    private func syncReminders() {
        if profile.reminderEnabled {
            NotificationManager.shared.requestAuthorizationIfNeeded { granted in
                guard granted else { return }
                NotificationManager.shared.scheduleDailyReminder(hour: self.profile.reminderHour, minute: self.profile.reminderMinute)
            }
        } else {
            NotificationManager.shared.cancelDailyReminder()
        }
    }
}

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let reminderIdentifier = "daily.reminder.checklist"

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) {
        cancelDailyReminder()
        let content = UNMutableNotificationContent()
        content.title = "每日清单提醒"
        content.body = "来看看今天的计划吧 ✨"
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    // 单任务提醒：id 由 taskId+offset 组成，便于单独取消
    func scheduleTaskReminder(taskId: UUID, title: String, dueDate: Date, offsetMinutes: Int) {
        let id = taskTaskIdentifier(taskId: taskId, offset: offsetMinutes)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        let fireDate = Calendar.current.date(byAdding: .minute, value: -offsetMinutes, to: dueDate) ?? dueDate
        guard fireDate > Date().addingTimeInterval(-60) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = offsetMinutes > 0 ? "还有 \(offsetMinutes) 分钟到期" : "已到截止时间"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancelTaskReminders(taskId: UUID) {
        // 由于不知道 offsets，直接按前缀移除
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix("task.\(taskId.uuidString)") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func taskTaskIdentifier(taskId: UUID, offset: Int) -> String {
        "task.\(taskId.uuidString).offset.\(offset)"
    }
}

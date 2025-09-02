import Foundation

// MARK: - DTO: 任务（与需求描述对齐的可复用结构）
struct BackendTask: Codable, Equatable {
    var task_id: String
    var title: String
    var enable_start_time: Bool
    var start_date: String
    var start_time: String
    var enable_due_date: Bool
    var due_date: String
    var due_time: String
    var repeat_rule: String? // none, daily, every_2_days, every_3_days, every_7_days
    var priority: String // none, low, medium, high
    var tags: String
    var notes: String
    var estimated_duration: Int
    var is_reminder: Bool
    var reminder_time: String // YYYY-MM-DD HH:MM
    var reminder_advance: Int // minutes
}

// MARK: - 错误类型
enum TaskBackendError: Error, LocalizedError {
    case invalidOperation
    case invalidField(String)
    case taskNotFound(String)
    case invalidUUID(String)
    case invalidDate(String)
    case conflict(String)

    var errorDescription: String? {
        switch self {
        case .invalidOperation: return "无效的操作类型"
        case .invalidField(let f): return "无效字段: \(f)"
        case .taskNotFound(let id): return "任务不存在: \(id)"
        case .invalidUUID(let s): return "无效 UUID: \(s)"
        case .invalidDate(let s): return "无效日期/时间: \(s)"
        case .conflict(let m): return "规则冲突: \(m)"
        }
    }
}

// MARK: - 日期工具
enum DateUtils {
    static func date(fromYMD ymd: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)
    }

    static func date(fromYMDHM ymdhm: String) -> Date? {
        // 支持 "yyyy-MM-dd HH:mm"
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        if let d = f.date(from: ymdhm) { return d }
        // 兼容 ISO8601
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: ymdhm) { return d }
        return nil
    }

    static func combine(ymd: String, hm: String?) -> Date? {
        let t = (hm?.isEmpty == false) ? (ymd + " " + (hm ?? "00:00")) : ymd + " 00:00"
        return date(fromYMDHM: t)
    }

    static func ymd(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func hm(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func ymdhm(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

// MARK: - 映射：BackendTask <-> DailyTask
enum TaskMapper {
    static func toTask(from daily: DailyTask) -> BackendTask {
        let start = daily.startAt ?? daily.createdAt
        let enableStartTime = true
        let startDate = DateUtils.ymd(from: start)
        let startTime = DateUtils.hm(from: start)
        let enableDue = daily.dueDate != nil
        let dueDate = daily.dueDate.map(DateUtils.ymd) ?? ""
        let dueTime = daily.dueDate.map(DateUtils.hm) ?? ""
        let rule: String? = {
            switch daily.repeatRule {
            case .none: return "none"
            case .everyDay: return "daily"
            case .everyNDays(let n):
                switch n {
                case 2: return "every_2_days"
                case 3: return "every_3_days"
                case 7: return "every_7_days"
                default: return "every_\(n)_days"
                }
            }
        }()
        let tags = daily.labels.joined(separator: ",")
        let isReminder = enableDue && !daily.reminderOffsets.isEmpty
        let reminderTime = daily.dueDate.map(DateUtils.ymdhm) ?? ""
        let advance = daily.reminderOffsets.sorted().first ?? 0
        return BackendTask(
            task_id: daily.id.uuidString,
            title: daily.title,
            enable_start_time: enableStartTime,
            start_date: startDate,
            start_time: startTime,
            enable_due_date: enableDue,
            due_date: dueDate,
            due_time: dueTime,
            repeat_rule: rule,
            priority: daily.priority.rawValue,
            tags: tags,
            notes: daily.notes,
            estimated_duration: daily.durationMinutes ?? 0,
            is_reminder: isReminder,
            reminder_time: reminderTime,
            reminder_advance: advance
        )
    }

    static func toRepeatRule(_ s: String?) -> RepeatRule {
        guard let s = s?.lowercased() else { return .none }
        switch s {
        case "daily": return .everyDay
        case "every_2_days": return .everyNDays(2)
        case "every_3_days": return .everyNDays(3)
        case "every_7_days": return .everyNDays(7)
        case "none": return .none
        default:
            if s.hasPrefix("every_") && s.hasSuffix("_days") {
                let mid = s.dropFirst("every_".count).dropLast("_days".count)
                if let n = Int(mid), n >= 2 { return .everyNDays(n) }
            }
            return .none
        }
    }
}

// MARK: - 任务管理器（封装 ChecklistStore）
final class TaskManager {
    private let store: ChecklistStore

    init(store: ChecklistStore) { self.store = store }

    // ADD
    func add(payload: [String: String]) throws -> BackendTask {
        let title = (payload["title"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw TaskBackendError.invalidField("title") }

        let enableStartTime = parseBool(payload["enable_start_time"]) ?? true
        let startDateS = payload["start_date"] ?? DateUtils.ymd(from: Date())
        let startTimeS = payload["start_time"] ?? (enableStartTime ? DateUtils.hm(from: Date()) : "00:00")
        guard let start = DateUtils.combine(ymd: startDateS, hm: enableStartTime ? startTimeS : nil) else { throw TaskBackendError.invalidDate("start_date/start_time") }

        let enableDue = parseBool(payload["enable_due_date"]) ?? (payload["due_date"] != nil)
        let dueDateS = payload["due_date"] ?? ""
        let dueTimeS = payload["due_time"] ?? "00:00"
        let due = enableDue && !dueDateS.isEmpty ? DateUtils.combine(ymd: dueDateS, hm: dueTimeS) : nil

        let repeatRuleS = (payload["repeat_rule"] ?? "none").lowercased()
        if enableDue && repeatRuleS != "none" { throw TaskBackendError.conflict("启用 due_date 时，repeat_rule 必须为 none") }
        let rr = TaskMapper.toRepeatRule(repeatRuleS)

        let pr = TaskPriority(rawValue: (payload["priority"] ?? "none").lowercased()) ?? .none
        let tags = (payload["tags"] ?? "")
        let notes = payload["notes"] ?? ""
        let duration = Int(payload["estimated_duration"] ?? "0") ?? 0

        let isReminder = parseBool(payload["is_reminder"]) ?? false
        let reminderTimeS = payload["reminder_time"] ?? ""
        let reminderAdvance = Int(payload["reminder_advance"] ?? "0") ?? 0

        // 若是纯提醒：将 dueDate 设为提醒时刻，offset 为 advance
        let finalDue: Date? = try {
            if isReminder {
                guard let t = DateUtils.date(fromYMDHM: reminderTimeS) else { throw TaskBackendError.invalidDate("reminder_time") }
                return t
            }
            return due
        }()
        let reminderOffsets: [Int]? = isReminder ? [max(0, reminderAdvance)] : (finalDue != nil ? ((payload["reminder_advance"].flatMap { Int($0) }).map { [$0] } ?? []) : nil)

        store.addTask(title: title, for: start)
        guard let created = store.tasks(for: start).last else { throw TaskBackendError.invalidOperation }
        store.setDetails(
            taskId: created.id,
            title: title,
            dueDate: finalDue,
            startAt: start,
            repeatRule: rr,
            repeatEndDate: nil,
            priority: pr,
            notes: notes,
            labels: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            durationMinutes: duration == 0 ? nil : duration,
            reminderOffsets: reminderOffsets
        )
        guard let saved = store.tasksById[created.id] else { throw TaskBackendError.invalidOperation }
        return TaskMapper.toTask(from: saved)
    }

    // UPDATE
    func update(payload: [String: String]) throws -> BackendTask {
        guard let idS = payload["task_id"], let id = UUID(uuidString: idS) else { throw TaskBackendError.invalidUUID(payload["task_id"] ?? "") }
        guard let current = store.tasksById[id] else { throw TaskBackendError.taskNotFound(idS) }

        let newTitle = payload["title"].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let enableStartTime = parseBool(payload["enable_start_time"]) ?? true
        let startDateS = payload["start_date"]
        let startTimeS = payload["start_time"] ?? (enableStartTime ? DateUtils.hm(from: current.startAt ?? current.createdAt) : "00:00")
        let newStart: Date? = {
            if let sd = startDateS {
                return DateUtils.combine(ymd: sd, hm: enableStartTime ? startTimeS : nil)
            }
            return nil
        }()

        let enableDue = parseBool(payload["enable_due_date"]) ?? (payload["due_date"] != nil)
        let dueDateS = payload["due_date"]
        let dueTimeS = payload["due_time"] ?? "00:00"
        let newDue: Date? = {
            if let dd = dueDateS { return enableDue && !dd.isEmpty ? DateUtils.combine(ymd: dd, hm: dueTimeS) : nil }
            return nil
        }()

        let repeatRuleS = payload["repeat_rule"]?.lowercased()
        if (enableDue && (repeatRuleS ?? "none") != "none") || ((newDue != nil) && (repeatRuleS ?? "none") != "none") {
            throw TaskBackendError.conflict("启用 due_date 时，repeat_rule 必须为 none")
        }
        let rr = repeatRuleS.map(TaskMapper.toRepeatRule) ?? current.repeatRule

        let pr = payload["priority"].flatMap { TaskPriority(rawValue: $0.lowercased()) }
        let notes = payload["notes"]
        let tags = payload["tags"].map { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        let duration = payload["estimated_duration"].flatMap { Int($0) }

        let isReminder = parseBool(payload["is_reminder"]) ?? false
        let reminderTimeS = payload["reminder_time"]
        let reminderAdvance = payload["reminder_advance"].flatMap { Int($0) }
        let finalDue: Date? = {
            if isReminder, let ts = reminderTimeS { return DateUtils.date(fromYMDHM: ts) }
            return newDue
        }()
        if isReminder, reminderTimeS == nil { throw TaskBackendError.invalidField("reminder_time") }
        let reminderOffsets: [Int]? = isReminder ? [max(0, reminderAdvance ?? 0)] : (finalDue != nil ? (reminderAdvance.map { [$0] }) : nil)

        store.setDetails(
            taskId: id,
            title: newTitle ?? current.title,
            dueDate: finalDue,
            startAt: newStart,
            repeatRule: rr,
            repeatEndDate: nil,
            priority: pr ?? current.priority,
            notes: notes ?? current.notes,
            labels: tags ?? current.labels,
            durationMinutes: duration ?? current.durationMinutes,
            reminderOffsets: reminderOffsets
        )
        guard let saved = store.tasksById[id] else { throw TaskBackendError.invalidOperation }
        return TaskMapper.toTask(from: saved)
    }

    // DELETE
    func delete(payload: [String: String]) throws {
        guard let idS = payload["task_id"], let id = UUID(uuidString: idS) else { throw TaskBackendError.invalidUUID(payload["task_id"] ?? "") }
        guard store.tasksById[id] != nil else { throw TaskBackendError.taskNotFound(idS) }
        store.deleteTask(id: id)
    }

    // QUERY（供 UI/API 双向对齐使用）
    func backendTask(id: String) -> BackendTask? {
        guard let uuid = UUID(uuidString: id), let t = store.tasksById[uuid] else { return nil }
        return TaskMapper.toTask(from: t)
    }

    func backendTask(id: UUID) -> BackendTask? {
        guard let t = store.tasksById[id] else { return nil }
        return TaskMapper.toTask(from: t)
    }

    func backendTasks(for date: Date) -> [BackendTask] {
        store.tasks(for: date).map(TaskMapper.toTask(from:))
    }

    // MARK: - Helpers
    private func parseBool(_ s: String?) -> Bool? {
        guard let s = s else { return nil }
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch v {
        case "1", "true", "yes", "y", "on": return true
        case "0", "false", "no", "n", "off": return false
        default: return nil
        }
    }
}



import Foundation
import SwiftUI

enum RepeatRule: Equatable, Codable, Hashable {
    case none
    case everyDay
    case everyNDays(Int)

    private enum CodingKeys: String, CodingKey { case type, intervalDays }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "none"
        switch type {
        case "everyDay": self = .everyDay
        case "everyNDays":
            let interval = try container.decodeIfPresent(Int.self, forKey: .intervalDays) ?? 2
            self = .everyNDays(max(2, interval))
        default: self = .none
        }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try container.encode("none", forKey: .type)
        case .everyDay: try container.encode("everyDay", forKey: .type)
        case .everyNDays(let n):
            try container.encode("everyNDays", forKey: .type)
            try container.encode(n, forKey: .intervalDays)
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case none, low, medium, high
    var id: String { rawValue }
    var displayName: String { switch self { case .none: return L("prio.none"); case .low: return L("prio.low"); case .medium: return L("prio.medium"); case .high: return L("prio.high") } }
}

struct DailyTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
    var startAt: Date?
    var dueDate: Date?
    var repeatRule: RepeatRule
    var repeatEndDate: Date?
    var seriesId: UUID?
    var completedAt: Date?

    var priority: TaskPriority
    var notes: String
    var labels: [String]
    var durationMinutes: Int?
    var reminderOffsets: [Int]

    init(
        id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date = Date(),
        startAt: Date? = nil, dueDate: Date? = nil,
        repeatRule: RepeatRule = .none, repeatEndDate: Date? = nil, seriesId: UUID? = nil, completedAt: Date? = nil,
        priority: TaskPriority = .none, notes: String = "", labels: [String] = [], durationMinutes: Int? = nil, reminderOffsets: [Int] = []
    ) {
        self.id = id; self.title = title; self.isDone = isDone; self.createdAt = createdAt
        self.startAt = startAt; self.dueDate = dueDate
        self.repeatRule = repeatRule; self.repeatEndDate = repeatEndDate; self.seriesId = seriesId; self.completedAt = completedAt
        self.priority = priority; self.notes = notes; self.labels = labels; self.durationMinutes = durationMinutes; self.reminderOffsets = reminderOffsets
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isDone, createdAt, startAt, dueDate, repeatRule, repeatEndDate, seriesId, completedAt,
             priority, notes, labels, durationMinutes, reminderOffsets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        startAt = try c.decodeIfPresent(Date.self, forKey: .startAt)
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        repeatRule = try c.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        repeatEndDate = try c.decodeIfPresent(Date.self, forKey: .repeatEndDate)
        seriesId = try c.decodeIfPresent(UUID.self, forKey: .seriesId)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        priority = try c.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .none
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        reminderOffsets = try c.decodeIfPresent([Int].self, forKey: .reminderOffsets) ?? []
    }
}

struct DayChecklist: Identifiable, Equatable { let id: String; var date: Date; var tasks: [DailyTask] }

// 最近删除
struct RecentlyDeleted: Codable, Identifiable {
    var id: UUID { task.id }
    let task: DailyTask
    let deletedAt: Date
}

final class ChecklistStore: ObservableObject {
    @Published private(set) var tasksById: [UUID: DailyTask] = [:]
    @Published private(set) var dayOrder: [String: [UUID]] = [:]
    @Published private(set) var recentlyDeleted: [UUID: RecentlyDeleted] = [:]

    // iCloud KVS
    @Published private(set) var iCloudEnabled: Bool = UserDefaults.standard.bool(forKey: "checklist.icloud.enabled")
    private let kvStore = NSUbiquitousKeyValueStore.default
    private var kvObserver: NSObjectProtocol?
    private let kvTasksKey = "checklist.kvs.tasks.v1"
    private let kvOrderKey = "checklist.kvs.order.v1"
    private let kvTrashKey = "checklist.kvs.trash.v1"

    private let userDefaultsKey = "checklist.storage.v2"
    private let orderDefaultsKey = "checklist.order.v1"
    private let trashDefaultsKey = "checklist.trash.v1"

    init() {
        load()
        if iCloudEnabled { startICloudSync() }
    }

    func tasks(for date: Date) -> [DailyTask] {
        let day = Calendar.current.startOfDay(for: date)
        var list = tasksById.values.filter { task in
            let start = Calendar.current.startOfDay(for: task.startAt ?? task.createdAt)
            if let due = task.dueDate {
                let dueDay = Calendar.current.startOfDay(for: due)
                return start <= day && day <= dueDay
            } else {
                return start == day
            }
        }
        list.sort { $0.createdAt < $1.createdAt }
        let key = ChecklistStore.dayKey(from: day)
        if let order = dayOrder[key], !order.isEmpty {
            let index: [UUID: Int] = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
            list.sort { (index[$0.id] ?? Int.max) < (index[$1.id] ?? Int.max) }
        }
        return list
    }

    func reorderTasks(for date: Date, from offsets: IndexSet, to newOffset: Int) {
        let key = ChecklistStore.dayKey(from: date)
        var current = tasks(for: date).map { $0.id }
        current.move(fromOffsets: offsets, toOffset: newOffset)
        dayOrder[key] = current
        saveOrders()
    }

    func addTask(title: String, for date: Date) {
        // 默认开始时间：使用“当前时间”的时分秒，落在所选日期上
        let cal = Calendar.current
        let day = cal.dateComponents([.year, .month, .day], from: date)
        let nowHM = cal.dateComponents([.hour, .minute, .second], from: Date())
        var comps = DateComponents()
        comps.year = day.year; comps.month = day.month; comps.day = day.day
        comps.hour = nowHM.hour; comps.minute = nowHM.minute; comps.second = nowHM.second
        let start = cal.date(from: comps) ?? date
        let task = DailyTask(title: title, startAt: start, dueDate: nil)
        // 减少 SwiftUI 列表 diff 动画抖动：先维护排序再一次性写入存储
        let key = ChecklistStore.dayKey(from: cal.startOfDay(for: start))
        var order = dayOrder[key] ?? []
        order.append(task.id)
        dayOrder[key] = order
        tasksById[task.id] = task
        save(); saveOrders(); scheduleRemindersIfNeeded(for: task)
    }

    func toggle(taskId: UUID) { update(taskId: taskId) { $0.isDone.toggle() } }
    func toggle(taskId: UUID, completedOn displayedDate: Date) { toggle(taskId: taskId) }

    func deleteTask(id: UUID) {
        if let task = tasksById[id] {
            // 移入最近删除
            recentlyDeleted[id] = RecentlyDeleted(task: task, deletedAt: Date())
        }
        tasksById.removeValue(forKey: id)
        // 清理排序表
        for key in dayOrder.keys {
            if var arr = dayOrder[key], let idx = arr.firstIndex(of: id) {
                arr.remove(at: idx)
                dayOrder[key] = arr
            }
        }
        save(); saveOrders(); saveTrash(); NotificationManager.shared.cancelTaskReminders(taskId: id)
    }

    func deleteTasks(at offsets: IndexSet, for date: Date) {
        let list = tasks(for: date)
        for idx in offsets { if idx < list.count { deleteTask(id: list[idx].id) } }
    }

    func update(taskId: UUID, transform: (inout DailyTask) -> Void) {
        guard var task = tasksById[taskId] else { return }
        transform(&task)
        tasksById[taskId] = task
        save(); scheduleRemindersIfNeeded(for: task)
    }

    func setDetails(
        taskId: UUID,
        title: String? = nil,
        dueDate: Date?,
        startAt: Date?,
        repeatRule: RepeatRule,
        repeatEndDate: Date?,
        priority: TaskPriority? = nil,
        notes: String? = nil,
        labels: [String]? = nil,
        durationMinutes: Int? = nil,
        reminderOffsets: [Int]? = nil
    ) {
        update(taskId: taskId) { task in
            if let t = title { task.title = t }
            // 互斥规则：存在重复则清空截止；存在截止则清空重复
            var newDue = dueDate
            var newRepeat = repeatRule
            var newRepeatEnd = repeatEndDate
            if newRepeat != .none { newDue = nil }
            if newDue != nil { newRepeat = .none; newRepeatEnd = nil }

            task.dueDate = newDue
            task.startAt = startAt ?? task.startAt ?? Date()
            task.repeatRule = newRepeat
            task.repeatEndDate = newRepeatEnd
            if let p = priority { task.priority = p }
            if let n = notes { task.notes = n }
            if let l = labels { task.labels = l }
            task.durationMinutes = durationMinutes
            if let ro = reminderOffsets { task.reminderOffsets = ro }
            if newRepeat != .none && task.seriesId == nil { task.seriesId = task.id }
        }
        // 系列联动与清理
        guard let updated = tasksById[taskId] else { return }
        if let sid = updated.seriesId {
            let instanceDay = Calendar.current.startOfDay(for: updated.startAt ?? updated.createdAt)
            if updated.repeatRule == .none {
                // 在某一天把实例改为不重复：将整个系列的结束日截断到该天，删除其后的所有实例
                propagateSeries(seriesId: sid) { t in
                    // 仅设置结束日，不强制改其他实例的 repeatRule，保持系列在截止日前有效
                    t.repeatEndDate = instanceDay
                }
                if let origin = earliestInstance(of: sid) { cleanupBeyondEnd(originTask: origin) }
            } else {
                // 仍为重复：对系列做联动更新（标题/优先级/备注/标签/时长/提醒/重复规则/结束日）
                propagateSeries(seriesId: sid) { t in
                    t.title = updated.title
                    t.priority = updated.priority
                    t.notes = updated.notes
                    t.labels = updated.labels
                    t.durationMinutes = updated.durationMinutes
                    t.reminderOffsets = updated.reminderOffsets
                    t.repeatRule = updated.repeatRule
                    t.repeatEndDate = updated.repeatEndDate
                    // 重复下 dueDate 应为空，由互斥保证
                    if t.repeatRule != .none { t.dueDate = nil }
                }
                // 用系列最早实例作为基准再实例化未来的成员，确保间隔从起点计算
                if let origin = earliestInstance(of: sid) { materializeSeries(originTask: origin) }
                if let origin = earliestInstance(of: sid) { cleanupBeyondEnd(originTask: origin) }
            }
        } else {
            // 非系列：若此任务新设为重复，生成系列成员
            if updated.repeatRule != .none {
                var seed = updated
                seed.seriesId = updated.id
                tasksById[updated.id] = seed
                materializeSeries(originTask: seed)
                cleanupBeyondEnd(originTask: seed)
            }
        }
    }

    // 保留旧签名外壳（忽略 for: date 参数）
    func setDetails(
        taskId: UUID, for date: Date,
        title: String? = nil, dueDate: Date?, startAt: Date?, repeatRule: RepeatRule, repeatEndDate: Date?,
        priority: TaskPriority? = nil, notes: String? = nil, labels: [String]? = nil, durationMinutes: Int? = nil, reminderOffsets: [Int]? = nil
    ) {
        setDetails(taskId: taskId, title: title, dueDate: dueDate, startAt: startAt, repeatRule: repeatRule, repeatEndDate: repeatEndDate, priority: priority, notes: notes, labels: labels, durationMinutes: durationMinutes, reminderOffsets: reminderOffsets)
    }

    // 重复任务实例化：按 startAt 起步，向后生成到结束或预设地平线
    private func materializeSeries(originTask: DailyTask, horizonDays: Int = 365) {
        guard let seriesId = originTask.seriesId, let start = originTask.startAt else { return }
        let step: Int = { switch originTask.repeatRule { case .everyDay: return 1; case .everyNDays(let n): return max(2, n); case .none: return 0 } }()
        guard step > 0 else { return }
        let startDay = Calendar.current.startOfDay(for: start)
        let endLimit = Calendar.current.startOfDay(for: originTask.repeatEndDate ?? startDay.adding(days: horizonDays))
        var day = startDay
        while day <= endLimit {
            if day == startDay { day = day.adding(days: step); continue }
            let exists = tasksById.values.contains { $0.seriesId == seriesId && Calendar.current.startOfDay(for: $0.startAt ?? $0.createdAt) == day }
            if !exists {
                let clone = DailyTask(
                    id: UUID(), title: originTask.title, isDone: false, createdAt: Date(),
                    startAt: day, dueDate: originTask.dueDate,
                    repeatRule: originTask.repeatRule, repeatEndDate: originTask.repeatEndDate, seriesId: seriesId,
                    completedAt: nil, priority: originTask.priority, notes: originTask.notes, labels: originTask.labels,
                    durationMinutes: originTask.durationMinutes, reminderOffsets: originTask.reminderOffsets
                )
                tasksById[clone.id] = clone
                scheduleRemindersIfNeeded(for: clone)
            }
            day = day.adding(days: step)
        }
        save()
    }

    private func cleanupBeyondEnd(originTask: DailyTask) {
        guard let seriesId = originTask.seriesId, let end = originTask.repeatEndDate else { return }
        let endDay = Calendar.current.startOfDay(for: end)
        let toRemove = tasksById.values.filter { $0.seriesId == seriesId && Calendar.current.startOfDay(for: $0.startAt ?? $0.createdAt) > endDay }
        for t in toRemove {
            tasksById.removeValue(forKey: t.id)
            // 同步清理排序表
            for key in dayOrder.keys {
                if var arr = dayOrder[key], let idx = arr.firstIndex(of: t.id) { arr.remove(at: idx); dayOrder[key] = arr }
            }
            NotificationManager.shared.cancelTaskReminders(taskId: t.id)
        }
        save(); saveOrders()
    }

    // 寻找系列最早实例（按 startAt/createdAt 的起始日）
    private func earliestInstance(of seriesId: UUID) -> DailyTask? {
        tasksById.values
            .filter { $0.seriesId == seriesId }
            .min(by: { (lhs, rhs) in
                let l = Calendar.current.startOfDay(for: lhs.startAt ?? lhs.createdAt)
                let r = Calendar.current.startOfDay(for: rhs.startAt ?? rhs.createdAt)
                return l < r
            })
    }

    // 对系列内所有任务做联动更新（不改变各自 startAt/isDone）
    private func propagateSeries(seriesId: UUID, mutate: (inout DailyTask) -> Void) {
        let ids = tasksById.values.filter { $0.seriesId == seriesId }.map { $0.id }
        for id in ids { update(taskId: id) { mutate(&$0) } }
    }

    private func scheduleRemindersIfNeeded(for task: DailyTask) {
        NotificationManager.shared.cancelTaskReminders(taskId: task.id)
        guard let due = task.dueDate, !task.reminderOffsets.isEmpty else { return }
        for offset in task.reminderOffsets { NotificationManager.shared.scheduleTaskReminder(taskId: task.id, title: task.title, dueDate: due, offsetMinutes: offset) }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey), let decoded = try? JSONDecoder().decode([UUID: DailyTask].self, from: data) {
            tasksById = decoded
        } else if let oldData = UserDefaults.standard.data(forKey: "checklist.storage.v1"), let old = try? JSONDecoder().decode([String: [DailyTask]].self, from: oldData) {
            var migrated: [UUID: DailyTask] = [:]
            for (_, arr) in old { for t in arr { migrated[t.id] = t } }
            tasksById = migrated; save()
        }
        if let odata = UserDefaults.standard.data(forKey: orderDefaultsKey), let o = try? JSONDecoder().decode([String: [UUID]].self, from: odata) { dayOrder = o }
        if let tdata = UserDefaults.standard.data(forKey: trashDefaultsKey), let t = try? JSONDecoder().decode([UUID: RecentlyDeleted].self, from: tdata) { recentlyDeleted = t }
    }

    private func save() { if let data = try? JSONEncoder().encode(tasksById) { UserDefaults.standard.set(data, forKey: userDefaultsKey) } }
    private func saveOrders() { if let data = try? JSONEncoder().encode(dayOrder) { UserDefaults.standard.set(data, forKey: orderDefaultsKey) } }
    private func saveTrash() { if let data = try? JSONEncoder().encode(recentlyDeleted) { UserDefaults.standard.set(data, forKey: trashDefaultsKey) } }

    // MARK: - iCloud Sync
    func setICloudSyncEnabled(_ enabled: Bool) {
        guard enabled != iCloudEnabled else { return }
        iCloudEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "checklist.icloud.enabled")
        if enabled { startICloudSync(); pushToCloud() } else { stopICloudSync() }
    }

    func syncNow() {
        guard iCloudEnabled else { return }
        pushToCloud()
        kvStore.synchronize()
    }

    private func startICloudSync() {
        kvObserver = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kvStore, queue: .main) { [weak self] _ in
            self?.pullFromCloud()
        }
        kvStore.synchronize()
        pullFromCloud()
    }

    private func stopICloudSync() {
        if let obs = kvObserver { NotificationCenter.default.removeObserver(obs) }
        kvObserver = nil
    }

    private func pushToCloud() {
        let enc = JSONEncoder()
        if let d = try? enc.encode(tasksById) { kvStore.set(d, forKey: kvTasksKey) }
        if let d = try? enc.encode(dayOrder) { kvStore.set(d, forKey: kvOrderKey) }
        if let d = try? enc.encode(recentlyDeleted) { kvStore.set(d, forKey: kvTrashKey) }
        kvStore.synchronize()
    }

    private func pullFromCloud() {
        let dec = JSONDecoder()
        var remoteTasks: [UUID: DailyTask] = [:]
        var remoteOrder: [String: [UUID]] = [:]
        var remoteTrash: [UUID: RecentlyDeleted] = [:]

        if let data = kvStore.object(forKey: kvTasksKey) as? Data, let decoded = try? dec.decode([UUID: DailyTask].self, from: data) { remoteTasks = decoded }
        if let data = kvStore.object(forKey: kvOrderKey) as? Data, let decoded = try? dec.decode([String: [UUID]].self, from: data) { remoteOrder = decoded }
        if let data = kvStore.object(forKey: kvTrashKey) as? Data, let decoded = try? dec.decode([UUID: RecentlyDeleted].self, from: data) { remoteTrash = decoded }

        if remoteTasks.isEmpty && remoteOrder.isEmpty && remoteTrash.isEmpty { return }

        // 合并策略：
        // - 任务：合并键集合；若同 id 存在且完成状态不同，则优先已完成；否则以 iCloud 为准
        var mergedTasks = tasksById
        for (id, rtask) in remoteTasks {
            if var ltask = mergedTasks[id] {
                if (ltask.isDone != rtask.isDone) {
                    // 优先选择已完成的那个
                    let preferRemote = rtask.isDone
                    mergedTasks[id] = preferRemote ? rtask : ltask
                } else {
                    // 其它字段以远端为准（简单策略）
                    mergedTasks[id] = rtask
                }
            } else {
                mergedTasks[id] = rtask
            }
        }

        // 排序表：本地优先，补充远端缺失的 key
        var mergedOrder = dayOrder
        for (k, rarr) in remoteOrder { if mergedOrder[k] == nil { mergedOrder[k] = rarr } }

        // 回收站：并集
        var mergedTrash = recentlyDeleted
        for (id, r) in remoteTrash { if mergedTrash[id] == nil { mergedTrash[id] = r } }

        tasksById = mergedTasks
        dayOrder = mergedOrder
        recentlyDeleted = mergedTrash
        save(); saveOrders(); saveTrash()
    }

    static func dayKey(from date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    static func date(from key: String) -> Date? { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; return f.date(from: key) }
}

// MARK: - 最近删除操作
extension ChecklistStore {
    func restoreFromTrash(id: UUID) {
        guard let item = recentlyDeleted[id] else { return }
        let task = item.task
        tasksById[task.id] = task
        // 追加到对应日期顺序末尾
        let day = Calendar.current.startOfDay(for: task.startAt ?? task.createdAt)
        let key = ChecklistStore.dayKey(from: day)
        var arr = dayOrder[key] ?? []
        if !arr.contains(task.id) { arr.append(task.id) }
        dayOrder[key] = arr
        recentlyDeleted.removeValue(forKey: id)
        save(); saveOrders(); saveTrash(); scheduleRemindersIfNeeded(for: task)
    }

    func purgeTrash(id: UUID) {
        // 从最近删除移除
        recentlyDeleted.removeValue(forKey: id)
        // 确保从主数据源与排序中彻底移除（幂等）
        tasksById.removeValue(forKey: id)
        for key in dayOrder.keys {
            if var arr = dayOrder[key], let idx = arr.firstIndex(of: id) {
                arr.remove(at: idx)
                dayOrder[key] = arr
            }
        }
        save(); saveOrders(); saveTrash(); NotificationManager.shared.cancelTaskReminders(taskId: id)
    }

    func purgeAllTrash() {
        let ids = Array(recentlyDeleted.keys)
        for id in ids { purgeTrash(id: id) }
    }
}

// MARK: - 批量操作
extension ChecklistStore {
    /// 将某天未完成、非重复、无截止的任务整体顺延到明天（仅移动开始日期）
    /// - 注意：带截止或重复规则的任务将被跳过，避免破坏语义
    func deferIncompleteTasks(on date: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.startOfDay(for: day.adding(days: 1))

        let candidates = tasks(for: day).filter { task in
            guard !task.isDone else { return false }
            guard task.repeatRule == .none else { return false }
            guard task.dueDate == nil else { return false }
            let taskDay = calendar.startOfDay(for: task.startAt ?? task.createdAt)
            return taskDay == day
        }

        let oldKey = ChecklistStore.dayKey(from: day)
        let newKey = ChecklistStore.dayKey(from: nextDay)
        var newOrder = dayOrder[newKey] ?? []

        for t in candidates {
            let newStart = (t.startAt ?? day).adding(days: 1)
            // 仅修改开始时间，其它字段保持不变
            setDetails(
                taskId: t.id,
                title: t.title,
                dueDate: t.dueDate,
                startAt: newStart,
                repeatRule: t.repeatRule,
                repeatEndDate: t.repeatEndDate,
                priority: t.priority,
                notes: t.notes,
                labels: t.labels,
                durationMinutes: t.durationMinutes,
                reminderOffsets: t.reminderOffsets
            )

            // 维护排序表：从旧日移除，加入新日末尾（若尚未存在）
            if var arr = dayOrder[oldKey], let idx = arr.firstIndex(of: t.id) {
                arr.remove(at: idx)
                dayOrder[oldKey] = arr
            }
            if !newOrder.contains(t.id) { newOrder.append(t.id) }
        }

        dayOrder[newKey] = newOrder
        saveOrders()
    }
}

extension Date {
    func adding(days: Int) -> Date { Calendar.current.date(byAdding: .day, value: days, to: self) ?? self }
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var readableTitle: String { let f = DateFormatter(); f.dateFormat = "MMM d, EEEE"; return f.string(from: self) }
}

// MARK: - 通知名称
extension Notification.Name {
    static let deferTasksRequested = Notification.Name("deferTasksRequested")
}

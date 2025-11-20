import Foundation
import SwiftUI // For localization L()

// MARK: - Keychain (简单封装)
enum Keychain {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var newQuery = query
        newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: kCFBooleanTrue as Any,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data { return String(data: data, encoding: .utf8) }
        return nil
    }
}

// MARK: - AI 配置
final class AIConfig: ObservableObject {
    static let shared = AIConfig()
    @Published var model: String { didSet { UserDefaults.standard.set(model, forKey: Self.modelKey) } }
    @Published var requireConfirmBeforeExecute: Bool { didSet { UserDefaults.standard.set(requireConfirmBeforeExecute, forKey: Self.confirmKey) } }

    private static let keychainKey = "openai.api.key"
    private static let modelKey = "openai.model"
    private static let confirmKey = "openai.require.confirm"

    init() {
        model = UserDefaults.standard.string(forKey: Self.modelKey) ?? "gpt-5-nano"
        requireConfirmBeforeExecute = UserDefaults.standard.object(forKey: Self.confirmKey) as? Bool ?? false
    }

    var apiKey: String? { Keychain.load(key: Self.keychainKey) }
    func setAPIKey(_ key: String) { Keychain.save(key: Self.keychainKey, value: key) }
}

// MARK: - OpenAI Types
struct ChatMessage: Codable { let role: String; let content: String }

struct Tool: Codable {
    struct Function: Codable { let name: String; let description: String; let parameters: [String: AnyCodable] }
    var type: String = "function"
    let function: Function
}

struct ToolCall: Codable { let id: String; let type: String; let function: ToolFunctionCall }
struct ToolFunctionCall: Codable { let name: String; let arguments: String }

struct ChoiceDeltaToolCall: Codable { let id: String?; let type: String?; let function: ToolFunctionCall? }

struct ChatResponse: Codable {
    struct Choice: Codable {
        struct MessageObj: Codable { let role: String; let content: String?; let tool_calls: [ToolCall]? }
        let index: Int; let message: MessageObj
    }
    let choices: [Choice]
}

// MARK: - AnyCodable 简易实现
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws { self.value = 0 }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        default:
            // 尽量 JSON 化
            if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
               let str = String(data: data, encoding: .utf8) {
                try container.encode(str)
            } else {
                try container.encodeNil()
            }
        }
    }
}

// MARK: - AI 服务
final class AIService: ObservableObject {
    static let shared = AIService()
    static let noActionToken = "__NO_ACTION__"

    // 轻量意图判定：避免对明显“非请求”文本调用 LLM 浪费 token
    // 命中任一关键词/时间模式/命令词则认为是任务相关
    static func isLikelyTaskCommand(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return false }
        // 快速命令词（中英混合）
        let keywords = [
            "添加","新增","新建","创建","安排","记录","提醒","设置","修改","更新","更改","删除","移除","完成","归档",
            "截止","到期","优先级","标签","备注","重复","每天","每","次","提前",
            "add","create","new","update","set","change","edit","delete","remove","complete","finish","remind","due","priority","tag","note","repeat"
        ]
        if keywords.contains(where: { s.localizedCaseInsensitiveContains($0) }) { return true }
        // 时间/日期样式
        let patterns = [
            #"\b\d{1,2}:\d{2}\b"#,          // 09:30
            #"\b\d{4}-\d{1,2}-\d{1,2}\b"#, // 2025-08-25
            "今天","明天","后天","昨天","今晚","明早","本周","下周","周一","周二","周三","周四","周五","周六","周日",
            "today","tomorrow","yesterday","tonight","this week","next week","monday","tuesday","wednesday","thursday","friday","saturday","sunday"
        ]
        for p in patterns {
            if p.hasPrefix("\\b") || p.contains("\\d") { // regex
                if s.range(of: p, options: .regularExpression) != nil { return true }
            } else {
                if s.localizedCaseInsensitiveContains(p) { return true }
            }
        }
        // 太短的纯情绪/感叹句（例如“很开心啊”）直接判定为非请求
        if s.count <= 8 && !s.contains(" ") { return false }
        return false
    }

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private var currentTask: URLSessionDataTask?

    // 系统提示：约束工具使用与业务规则（多语种友好）
    private var systemPrompt: String {
        """
        你是任务管理助手。只能通过工具（function calling）修改数据，禁止直接输出 JSON 以外的自然语言操作指令。
        语言政策：必须支持任意语言（中文/英文/其它）。不要翻译用户内容；title 与 notes 保持用户原语言；枚举/布尔/键名按英文规范。
        规则：
        - 你拥有对任务的完全编辑权限：可创建、更新（标题/开始/截止/重复/结束/优先级/备注/标签/时长/提醒）、完成、删除、恢复。
        - 日期策略：当用户说“明天/某日做X/本周五/下周一/今晚9点/明早7点”等相对时间时，将 start_date 设置为该目标日期（必要时含时间）；仅当用户明确说明“有截止/到某日为止”时再设置 due_date。若两者皆给出且未说明差异，可将二者都设为目标日期。
        - 仅“提醒/提醒我/通知我/at HH:mm/今晚HH点/XX点提醒”且未明确“截止”的场景：将 due_date 设为提醒触发时刻，并设置 reminder_offsets（若未说明，默认 [10] 分钟提前）；repeat_rule 设为 none。
        - dueDate 与 repeatRule 互斥：有重复则清空截止；有截止则 repeatRule 必须为 none。
        - 将某天的实例改为不重复，应调用 set_non_repeating_and_truncate(id,on_date) 截断系列至该天。
        - 任何模糊任务名都先调用 list_tasks(date?) 获取 id 再操作；禁止根据标题模糊匹配直接修改。
        - 日期与时间统一使用 ISO 8601（yyyy-MM-dd 或 yyyy-MM-dd'T'HH:mm:ssZ）。可用任意语言理解并解析，但输出必须使用上述格式与英文枚举。
        - 若需要删除，请优先调用 delete_task(id)（移动到最近删除）。
        - 尽量用最少次数的工具调用完成任务；避免多余的自然语言输出。
        - 非任务意图/不可执行：不要调用任何工具，也不要输出任何长说明或 emoji。请“只输出”以下保留字（没有其它字符/换行）：__NO_ACTION__
        输出：必须以工具调用完成操作；只有在所有工具调用结束后，返回最后一个自然语言总结。
        """
    }

    // 工具定义（与 ChecklistStore 能力对齐）
    private var tools: [Tool] {
        func schema(_ props: [String: AnyCodable], required: [String]) -> [String: AnyCodable] {
            [
                "type": AnyCodable("object"),
                "properties": AnyCodable(props),
                "required": AnyCodable(required)
            ]
        }
        return [
            Tool(function: .init(name: "create_task", description: "创建任务。互斥规则生效。", parameters: schema([
                "title": AnyCodable(["type": "string"]),
                "start_date": AnyCodable(["type": "string"]),
                "due_date": AnyCodable(["type": "string", "nullable": true]),
                "repeat_rule": AnyCodable(["type": "string", "enum": ["none","everyDay","everyNDays"]]),
                "repeat_interval": AnyCodable(["type": "integer", "nullable": true]),
                "repeat_end_date": AnyCodable(["type": "string", "nullable": true]),
                "priority": AnyCodable(["type": "string", "enum": ["none","low","medium","high"], "nullable": true]),
                "notes": AnyCodable(["type": "string", "nullable": true]),
                "labels": AnyCodable(["type": "array", "items": ["type": "string"], "nullable": true]),
                "duration_minutes": AnyCodable(["type": "integer", "nullable": true]),
                "reminder_offsets": AnyCodable(["type": "array", "items": ["type": "integer"], "nullable": true])
            ], required: ["title","start_date","repeat_rule"]))),
            Tool(function: .init(name: "update_task", description: "根据 id 更新任务字段。互斥规则生效。", parameters: schema([
                "id": AnyCodable(["type": "string"]),
                "title": AnyCodable(["type": "string", "nullable": true]),
                "start_date": AnyCodable(["type": "string", "nullable": true]),
                "due_date": AnyCodable(["type": "string", "nullable": true]),
                "repeat_rule": AnyCodable(["type": "string", "enum": ["none","everyDay","everyNDays"], "nullable": true]),
                "repeat_interval": AnyCodable(["type": "integer", "nullable": true]),
                "repeat_end_date": AnyCodable(["type": "string", "nullable": true]),
                "priority": AnyCodable(["type": "string", "enum": ["none","low","medium","high"], "nullable": true]),
                "notes": AnyCodable(["type": "string", "nullable": true]),
                "labels": AnyCodable(["type": "array", "items": ["type": "string"], "nullable": true]),
                "duration_minutes": AnyCodable(["type": "integer", "nullable": true]),
                "reminder_offsets": AnyCodable(["type": "array", "items": ["type": "integer"], "nullable": true])
            ], required: ["id"]))),
            Tool(function: .init(name: "complete_task", description: "完成任务。", parameters: schema([
                "id": AnyCodable(["type": "string"]),
                "completed_on": AnyCodable(["type": "string", "nullable": true])
            ], required: ["id"]))),
            Tool(function: .init(name: "delete_task", description: "删除到最近删除。", parameters: schema([
                "id": AnyCodable(["type": "string"])
            ], required: ["id"]))),
            Tool(function: .init(name: "restore_task", description: "从最近删除恢复。", parameters: schema([
                "id": AnyCodable(["type": "string"])
            ], required: ["id"]))),
            Tool(function: .init(name: "set_non_repeating_and_truncate", description: "将重复实例设为不重复，并把系列结束日截断到给定日期。", parameters: schema([
                "id": AnyCodable(["type": "string"]),
                "on_date": AnyCodable(["type": "string"]) 
            ], required: ["id","on_date"]))),
            Tool(function: .init(name: "list_tasks", description: "列出某天的任务用于消歧。", parameters: schema([
                "date": AnyCodable(["type": "string", "nullable": true])
            ], required: [])))
        ]
    }

    // 入口：处理自然语言意图
    func handlePrompt(_ prompt: String, date: Date, store: ChecklistStore, completion: @escaping (String) -> Void) {
        guard let apiKey = AIConfig.shared.apiKey else { completion(L("ai.no_key")); return }
        let model = AIConfig.shared.model

        let messages: [ChatMessage] = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(
                role: "user",
                content: (
                    "Today is " + isoDate(date) + ", timezone: " + TimeZone.current.identifier + " (" + gmtOffsetString(date) + ")\n" +
                    "Use ISO dates. You must accept ANY language input. Keep title/notes in user's original language; use English enums for fields.\n" +
                    "Relative words examples (multi-lingual): today/明天(tomorrow)/昨天(yesterday)/本周五(this Friday)/下周一(next Monday)/今晚9点(tonight 21:00)/明早7点(tomorrow 07:00).\n" +
                    prompt
                )
            )
        ]

        // 执行循环：工具调用 -> 本地执行 -> 返回结果 -> 直到无工具
        func loop(_ messagesSoFar: [ChatMessage]) {
            request(messages: messagesSoFar, tools: tools, model: model, apiKey: apiKey) { resp in
                guard let resp = resp else { completion(L("ai.fail_req")); return }
                if let toolCalls = resp.choices.first?.message.tool_calls, !toolCalls.isEmpty {
                    // 在本地顺序执行工具，并立即结束（减少二次请求与消息编排复杂度）
                    for call in toolCalls {
                        let (toolName, argsJSON) = (call.function.name, call.function.arguments)
                        _ = self.executeTool(name: toolName, argsJSON: argsJSON, dateContext: date, store: store)
                    }
                    completion("__TOOLS_EXECUTED__")
                } else {
                    // 最终回答
                    let text = resp.choices.first?.message.content ?? ""
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(trimmed.isEmpty ? AIService.noActionToken : trimmed)
                }
            }
        }
        loop(messages)
    }

    // MARK: - 执行前规划：返回操作列表，供 UI 确认
    enum OperationKind { case create, update, complete, delete, restore, truncate }
    struct Operation: Identifiable { let id = UUID(); let kind: OperationKind; let summary: String; let detail: String; let payload: [String: String] }

    func plan(prompt: String, date: Date, store: ChecklistStore, completion: @escaping ([Operation], String) -> Void) {
        guard let apiKey = AIConfig.shared.apiKey else { completion([], L("ai.no_key")); return }
        let model = AIConfig.shared.model
        let messages: [ChatMessage] = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(
                role: "user",
                content: (
                    "Today is " + isoDate(date) + ", timezone: " + TimeZone.current.identifier + " (" + gmtOffsetString(date) + ")\n" +
                    "Use ISO dates. Interpret relative words like 'tomorrow' based on Today.\n" +
                    prompt
                )
            )
        ]
        request(messages: messages, tools: tools, model: model, apiKey: apiKey) { [self] resp in
            guard let resp = resp else { completion([], L("ai.fail_req")); return }
            var ops: [Operation] = []
            if let calls = resp.choices.first?.message.tool_calls, !calls.isEmpty {
                for c in calls {
                    let name = c.function.name
                    let args = c.function.arguments
                    // DEBUG 跟踪每条 tool_call
                    #if DEBUG
                    print("[AIService] tool_call: \(name) args=\(args)")
                    #endif
                    func add(kind: OperationKind, summary: String, detail: String, payload: [String: String]) { ops.append(Operation(kind: kind, summary: summary, detail: detail, payload: payload)) }
                    switch name {
                    case "create_task":
                        struct A: Decodable { let title: String; let start_date: String; let due_date: String?; let repeat_rule: String; let repeat_interval: Int?; let repeat_end_date: String?; let priority: String?; let notes: String?; let labels: [String]?; let duration_minutes: Int?; let reminder_offsets: [Int]? }
                        if let a = try? JSONDecoder().decode(A.self, from: Data(args.utf8)) {
                            let s = L("ai.summary.create") + " · \(a.title)"
                            let d = [
                                L("ai.field.start"): a.start_date,
                                L("ai.field.due"): a.due_date ?? L("ai.val.none"),
                                L("ai.field.repeat"): a.repeat_rule + (a.repeat_interval != nil ? "(\(a.repeat_interval!))" : ""),
                                L("ai.field.end"): a.repeat_end_date ?? L("ai.val.none"),
                                L("ai.field.priority"): a.priority ?? "none"
                            ].map { "\($0.key)：\($0.value)" }.joined(separator: "\n")
                            add(kind: .create, summary: s, detail: d, payload: [
                                "title": a.title,
                                "start_date": a.start_date,
                                "due_date": a.due_date ?? "",
                                "repeat_rule": a.repeat_rule,
                                "repeat_interval": String(a.repeat_interval ?? 0),
                                "repeat_end_date": a.repeat_end_date ?? "",
                                "priority": a.priority ?? "",
                                "notes": a.notes ?? "",
                                "labels": (a.labels ?? []).joined(separator: ","),
                                "duration_minutes": a.duration_minutes.map { String($0) } ?? "",
                                "reminder_offsets": (a.reminder_offsets ?? []).map(String.init).joined(separator: ",")
                            ])
                        }
                    case "update_task":
                        struct A: Decodable { let id: String; let title: String?; let start_date: String?; let due_date: String?; let repeat_rule: String?; let repeat_interval: Int?; let repeat_end_date: String?; let priority: String?; let notes: String?; let labels: [String]?; let duration_minutes: Int?; let reminder_offsets: [Int]? }
                        if let a = try? JSONDecoder().decode(A.self, from: Data(args.utf8)) {
                            let currentTitle = UUID(uuidString: a.id).flatMap { store.tasksById[$0]?.title } ?? "(未知)"
                            let s = L("ai.summary.update") + " · \(currentTitle)"
                            let d = [
                                a.title.map { L("field.title") + " → \($0)" },
                                a.start_date.map { L("ai.field.start") + " → \($0)" },
                                a.due_date.map { L("ai.field.due") + " → \($0)" },
                                a.repeat_rule.map { r in L("ai.field.repeat") + " → \(r)\(a.repeat_interval != nil ? "(\(a.repeat_interval!))" : "")" },
                                a.repeat_end_date.map { L("ai.field.end") + " → \($0)" },
                                a.priority.map { L("ai.field.priority") + " → \($0)" },
                                a.notes.map { _ in L("ai.msg.notes_update") }
                            ].compactMap { $0 }.joined(separator: "\n")
                            add(kind: .update, summary: s, detail: d, payload: [
                                "id": a.id,
                                "title": a.title ?? "",
                                "start_date": a.start_date ?? "",
                                "due_date": a.due_date ?? "",
                                "repeat_rule": a.repeat_rule ?? "",
                                "repeat_interval": String(a.repeat_interval ?? 0),
                                "repeat_end_date": a.repeat_end_date ?? "",
                                "priority": a.priority ?? "",
                                "notes": a.notes ?? "",
                                "labels": (a.labels ?? []).joined(separator: ","),
                                "duration_minutes": a.duration_minutes.map { String($0) } ?? "",
                                "reminder_offsets": (a.reminder_offsets ?? []).map(String.init).joined(separator: ",")
                            ])
                        }
                    case "complete_task":
                        struct A: Decodable { let id: String; let completed_on: String? }
                        if let a = try? JSONDecoder().decode(A.self, from: Data(args.utf8)) {
                            let t = UUID(uuidString: a.id).flatMap { store.tasksById[$0]?.title } ?? a.id
                            add(kind: .complete, summary: L("ai.summary.complete") + " · \(t)", detail: L("ai.msg.completed_on") + " \(a.completed_on ?? self.isoDate(date))", payload: ["id": a.id])
                        }
                    case "delete_task":
                        struct A: Decodable { let id: String }
                        if let a = try? JSONDecoder().decode(A.self, from: Data(args.utf8)) {
                            let t = UUID(uuidString: a.id).flatMap { store.tasksById[$0]?.title } ?? a.id
                            add(kind: .delete, summary: L("ai.summary.delete") + " · \(t)", detail: L("ai.msg.moved_trash"), payload: ["id": a.id])
                        }
                    case "restore_task":
                        struct A: Decodable { let id: String }
                        if let a = try? JSONDecoder().decode(A.self, from: Data(args.utf8)) {
                            add(kind: .restore, summary: L("ai.summary.restore"), detail: a.id, payload: ["id": a.id])
                        }
                    case "set_non_repeating_and_truncate":
                        struct A: Decodable { let id: String; let on_date: String }
                        if let a = try? JSONDecoder().decode(A.self, from: Data(args.utf8)) {
                            let t = UUID(uuidString: a.id).flatMap { store.tasksById[$0]?.title } ?? a.id
                            add(kind: .truncate, summary: L("ai.summary.truncate") + " · \(t)", detail: L("field.end_date") + " → \(a.on_date)", payload: ["id": a.id, "on_date": a.on_date])
                        }
                    default:
                        break
                    }
                }
            } else {
                // 无 tool_calls：返回模型文本以便 UI 告知用户
                let text = resp.choices.first?.message.content ?? ""
                completion([], text)
                return
            }
            let finalText = resp.choices.first?.message.content ?? ""
            completion(ops, finalText)
        }
    }

    // 执行规划的操作列表
    func execute(operations: [Operation], dateContext: Date, store: ChecklistStore) {
        for op in operations {
            switch op.kind {
            case .create:
                if let title = op.payload["title"], let startS = op.payload["start_date"] {
                    let start = parseDateString(startS, context: dateContext) ?? dateContext
                    store.addTask(title: title, for: start)
                    if let created = store.tasks(for: start).last {
                        let rrS = op.payload["repeat_rule"] ?? "none"
                        let rr: RepeatRule = (rrS == "everyDay") ? .everyDay : (rrS == "everyNDays" ? .everyNDays(max(2, Int(op.payload["repeat_interval"] ?? "0") ?? 2)) : .none)
                        let pr: TaskPriority? = (op.payload["priority"].flatMap { $0.isEmpty ? nil : $0 }).flatMap { TaskPriority(rawValue: $0) }
                        let due = (op.payload["due_date"].flatMap { $0.isEmpty ? nil : $0 }).flatMap { parseDatePreservingTime($0, context: start) }
                        let rend = (op.payload["repeat_end_date"].flatMap { $0.isEmpty ? nil : $0 }).flatMap { parseDatePreservingTime($0, context: start) }
                        let notes = (op.payload["notes"].flatMap { $0.isEmpty ? nil : $0 })
                        // 默认提醒：若 due 存在且没有提醒偏移，则给一个 10 分钟提醒
                        let defaultReminder = due == nil ? nil : [10]
                        store.setDetails(taskId: created.id, title: created.title, dueDate: due, startAt: start, repeatRule: rr, repeatEndDate: rend, priority: pr, notes: notes, labels: nil, durationMinutes: nil, reminderOffsets: defaultReminder)
                    }
                }
            case .update:
                if let idS = op.payload["id"], let id = UUID(uuidString: idS) {
                    let rrS = op.payload["repeat_rule"]
                    let interval = Int(op.payload["repeat_interval"] ?? "0") ?? 0
                    let rr: RepeatRule = (rrS == "everyDay") ? .everyDay : (rrS == "everyNDays" ? .everyNDays(max(2, interval)) : (rrS == "none" ? .none : (store.tasksById[id]?.repeatRule ?? .none)))
                    let start = (op.payload["start_date"].flatMap { $0.isEmpty ? nil : $0 }).flatMap { parseDateString($0, context: dateContext) }
                    let due = (op.payload["due_date"].flatMap { $0.isEmpty ? nil : $0 }).flatMap { parseDatePreservingTime($0, context: dateContext) }
                    let rend = (op.payload["repeat_end_date"].flatMap { $0.isEmpty ? nil : $0 }).flatMap { parseDateString($0, context: dateContext) }
                    let pr = (op.payload["priority"].flatMap { $0.isEmpty ? nil : $0 }).flatMap { TaskPriority(rawValue: $0) }
                    let title = op.payload["title"].flatMap { $0.isEmpty ? nil : $0 }
                    let notes = op.payload["notes"].flatMap { $0.isEmpty ? nil : $0 }
                    store.setDetails(taskId: id, title: title, dueDate: due, startAt: start, repeatRule: rr, repeatEndDate: rend, priority: pr, notes: notes, labels: nil, durationMinutes: nil, reminderOffsets: nil)
                }
            case .complete:
                if let idS = op.payload["id"], let id = UUID(uuidString: idS) { store.toggle(taskId: id, completedOn: dateContext) }
            case .delete:
                if let idS = op.payload["id"], let id = UUID(uuidString: idS) { store.deleteTask(id: id) }
            case .restore:
                if let idS = op.payload["id"], let id = UUID(uuidString: idS) { store.restoreFromTrash(id: id) }
            case .truncate:
                if let idS = op.payload["id"], let id = UUID(uuidString: idS) {
                    let d = (op.payload["on_date"].flatMap { ISO8601DateFormatter().date(from: $0) }) ?? dateContext
                    store.setDetails(taskId: id, title: nil, dueDate: nil, startAt: nil, repeatRule: .none, repeatEndDate: d, priority: nil, notes: nil, labels: nil, durationMinutes: nil, reminderOffsets: nil)
                }
            }
        }
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone.current; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    private func gmtOffsetString(_ date: Date) -> String {
        let seconds = TimeZone.current.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let absSec = abs(seconds)
        let hours = absSec / 3600
        let minutes = (absSec % 3600) / 60
        return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
    }

    private func request(messages: [ChatMessage], tools: [Tool], model: String, apiKey: String, completion: @escaping (ChatResponse?) -> Void) {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20

        // 构建 tools JSON（纯 Foundation 类型）
        func toolsPayload() -> [[String: Any]] {
            func schema(_ props: [String: Any], required: [String]) -> [String: Any] {
                [
                    "type": "object",
                    "properties": props,
                    "required": required
                ]
            }
            return [
                [
                    "type": "function",
                    "function": [
                        "name": "create_task",
                        "description": "创建任务。互斥规则生效。",
                        "parameters": schema([
                            "title": ["type": "string"],
                            "start_date": ["type": "string"],
                            "due_date": ["type": "string", "nullable": true],
                            "repeat_rule": ["type": "string", "enum": ["none","everyDay","everyNDays"]],
                            "repeat_interval": ["type": "integer", "nullable": true],
                            "repeat_end_date": ["type": "string", "nullable": true],
                            "priority": ["type": "string", "enum": ["none","low","medium","high"], "nullable": true],
                            "notes": ["type": "string", "nullable": true]
                        ], required: ["title","start_date","repeat_rule"])
                    ]
                ],
                [
                    "type": "function",
                    "function": [
                        "name": "update_task",
                        "description": "根据 id 更新任务字段。互斥规则生效。",
                        "parameters": schema([
                            "id": ["type": "string"],
                            "title": ["type": "string", "nullable": true],
                            "start_date": ["type": "string", "nullable": true],
                            "due_date": ["type": "string", "nullable": true],
                            "repeat_rule": ["type": "string", "enum": ["none","everyDay","everyNDays"], "nullable": true],
                            "repeat_interval": ["type": "integer", "nullable": true],
                            "repeat_end_date": ["type": "string", "nullable": true],
                            "priority": ["type": "string", "enum": ["none","low","medium","high"], "nullable": true],
                            "notes": ["type": "string", "nullable": true]
                        ], required: ["id"])
                    ]
                ],
                [
                    "type": "function",
                    "function": [
                        "name": "complete_task",
                        "description": "完成任务。",
                        "parameters": schema([
                            "id": ["type": "string"],
                            "completed_on": ["type": "string", "nullable": true]
                        ], required: ["id"])
                    ]
                ],
                [
                    "type": "function",
                    "function": [
                        "name": "delete_task",
                        "description": "删除到最近删除。",
                        "parameters": schema([
                            "id": ["type": "string"]
                        ], required: ["id"])
                    ]
                ],
                [
                    "type": "function",
                    "function": [
                        "name": "restore_task",
                        "description": "从最近删除恢复。",
                        "parameters": schema([
                            "id": ["type": "string"]
                        ], required: ["id"])
                    ]
                ],
                [
                    "type": "function",
                    "function": [
                        "name": "set_non_repeating_and_truncate",
                        "description": "将重复实例设为不重复，并把系列结束日截断到给定日期。",
                        "parameters": schema([
                            "id": ["type": "string"],
                            "on_date": ["type": "string"]
                        ], required: ["id","on_date"])
                    ]
                ],
                [
                    "type": "function",
                    "function": [
                        "name": "list_tasks",
                        "description": "列出某天的任务用于消歧。",
                        "parameters": schema([
                            "date": ["type": "string", "nullable": true]
                        ], required: [])
                    ]
                ]
            ]
        }

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "tools": toolsPayload(),
            "tool_choice": "auto"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: req) { data, response, error in
            if let e = error { print("[AIService] request error: \(e.localizedDescription)") }
            if let http = response as? HTTPURLResponse { print("[AIService] HTTP status: \(http.statusCode)") }
            guard let data = data, error == nil else { DispatchQueue.main.async { completion(nil) }; return }
            #if DEBUG
            if let s = String(data: data, encoding: .utf8) { print("[AIService] raw response: \n\(s)") }
            #endif
            let resp = try? JSONDecoder().decode(ChatResponse.self, from: data)
            DispatchQueue.main.async { completion(resp) }
        }
        currentTask?.cancel()
        currentTask = task
        task.resume()
    }

    func cancelActive() { currentTask?.cancel(); currentTask = nil }

    // MARK: - Utilities: robust date parsing & title cleanup
    private func parseDateString(_ s: String?, context: Date) -> Date? {
        guard let s = s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Exact ISO yyyy-MM-dd（按本地时区解释为一天的起点）
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone.current; df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: trimmed) { return d }

        // 2) Full ISO8601 (with time)
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTime]
        if let d = iso.date(from: trimmed) { return Calendar.current.startOfDay(for: d) }

        // 3) Common patterns: MM/dd, MMM d, MMM dd, MMM d yyyy
        let patterns = ["MM/dd","MMM d","MMM dd","MMM d yyyy","MMMM d","MMMM d yyyy","yyyy/MM/dd"]
        for p in patterns {
            let f = DateFormatter(); f.locale = Locale.current; f.timeZone = TimeZone.current; f.dateFormat = p
            if let d = f.date(from: trimmed) { return Calendar.current.startOfDay(for: d) }
        }

        // 4) Relative keywords
        let lower = trimmed.lowercased()
        let cal = Calendar.current
        let sod = cal.startOfDay(for: context)
        if ["today","今天"].contains(lower) { return sod }
        if ["tomorrow","tmr","明天"].contains(lower) { return cal.date(byAdding: .day, value: 1, to: sod) }
        if ["yesterday","昨天"].contains(lower) { return cal.date(byAdding: .day, value: -1, to: sod) }

        // 5) NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length))
            if let m = matches.first, let d = m.date { return Calendar.current.startOfDay(for: d) }
        }
        return nil
    }

    // 与 parseDateString 不同：尽量保留“时间”
    private func parseDatePreservingTime(_ s: String?, context: Date) -> Date? {
        guard let s = s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Full ISO8601 with time → 保留原时间（尝试多种组合，兼容时区冒号）
        let iso = ISO8601DateFormatter()
        let optionSets: [[ISO8601DateFormatter.Options]] = [
            [.withInternetDateTime],
            [.withInternetDateTime, .withColonSeparatorInTimeZone],
            [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withColonSeparatorInTimeZone],
            [.withFullDate, .withTime, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
        ]
        for opts in optionSets { iso.formatOptions = ISO8601DateFormatter.Options(opts); if let d = iso.date(from: trimmed) { return d } }

        // 2) yyyy-MM-dd → 解释为当天 00:00（本地时区）
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone.current; df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: trimmed) { return d }

        // 2.1) 明确格式兜底（包含可选时区）
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mmXXXXX",
            "yyyy/MM/dd HH:mm",
            "MM/dd/yyyy HH:mm"
        ]
        for p in patterns { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone.current; f.dateFormat = p; if let d = f.date(from: trimmed) { return d } }

        // 3) NSDataDetector → 返回探测到的具体时间
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length))
            if let m = matches.first, let d = m.date { return d }
        }

        // 4) 相对词：today/tomorrow → 返回当天 00:00
        let lower = trimmed.lowercased()
        let cal = Calendar.current
        let sod = cal.startOfDay(for: context)
        if ["today","今天"].contains(lower) { return sod }
        if ["tomorrow","tmr","明天"].contains(lower) { return cal.date(byAdding: .day, value: 1, to: sod) }
        if ["yesterday","昨天"].contains(lower) { return cal.date(byAdding: .day, value: -1, to: sod) }
        return nil
    }

    private func cleanedTitle(_ title: String) -> String {
        var t = title
        let tokens = ["today","tomorrow","yesterday","on", "at", "明天", "今天", "昨天"]
        for tok in tokens {
            t = t.replacingOccurrences(of: " \(tok) ", with: " ", options: .caseInsensitive)
            t = t.replacingOccurrences(of: " \(tok)$", with: "", options: [.regularExpression, .caseInsensitive])
        }
        // Remove any explicit date phrases detected by NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let ns = t as NSString
            let matches = detector.matches(in: t, options: [], range: NSRange(location: 0, length: ns.length))
            var result = t
            for m in matches.reversed() { result = (result as NSString).replacingCharacters(in: m.range, with: "") }
            t = result
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 执行工具
    private func executeTool(name: String, argsJSON: String, dateContext: Date, store: ChecklistStore) -> String {
        func parse<T: Decodable>(_ type: T.Type) -> T? { try? JSONDecoder().decode(T.self, from: Data(argsJSON.utf8)) }

        switch name {
        case "list_tasks":
            struct Args: Decodable { let date: String? }
            let args = parse(Args.self)
            let day: Date = {
                if let s = args?.date, let d = ISO8601DateFormatter().date(from: s) { return d }
                return dateContext
            }()
            let items = store.tasks(for: day).map { t in
                [
                    "id": t.id.uuidString,
                    "title": t.title,
                    "date": ISO8601DateFormatter().string(from: (t.startAt ?? t.createdAt)),
                    "seriesId": t.seriesId?.uuidString ?? "",
                    "isDone": t.isDone
                ] as [String: Any]
            }
            if let data = try? JSONSerialization.data(withJSONObject: items, options: []), let s = String(data: data, encoding: .utf8) { return s }
            return "[]"

        case "create_task":
            struct Args: Decodable { let title: String; let start_date: String; let due_date: String?; let repeat_rule: String; let repeat_interval: Int?; let repeat_end_date: String?; let priority: String?; let notes: String?; let labels: [String]?; let duration_minutes: Int?; let reminder_offsets: [Int]? }
            guard let a = parse(Args.self) else { return "{}" }
            // 默认开始时间：若未提供 start_date，则使用当前具体时间
            let parsedStart = parseDateString(a.start_date, context: dateContext) ?? Date()
            let dueParsed = a.due_date.flatMap { parseDatePreservingTime($0, context: parsedStart) }
            // 创建落地应以 start_date 为准；若无则用上下文当天。due 仅决定覆盖范围。
            let chosenStart = parsedStart
            let finalTitle = cleanedTitle(a.title)
            store.addTask(title: finalTitle, for: chosenStart)
            if let created = store.tasks(for: chosenStart).last {
                let rr: RepeatRule = (a.repeat_rule == "everyDay") ? .everyDay : (a.repeat_rule == "everyNDays" ? .everyNDays(max(2, a.repeat_interval ?? 2)) : .none)
                let pr: TaskPriority? = a.priority.flatMap { TaskPriority(rawValue: $0) }
                let due = dueParsed
                let rend = a.repeat_end_date.flatMap { parseDateString($0, context: chosenStart) }
                let labels = a.labels
                let duration = a.duration_minutes
                let reminders = a.reminder_offsets
                store.setDetails(taskId: created.id, title: finalTitle, dueDate: due, startAt: chosenStart, repeatRule: rr, repeatEndDate: rend, priority: pr, notes: a.notes, labels: labels, durationMinutes: duration, reminderOffsets: reminders)
                return "{\"status\":\"created\",\"id\":\"\(created.id.uuidString)\"}"
            }
            return "{}"

        case "update_task":
            struct Args: Decodable { let id: String; let title: String?; let start_date: String?; let due_date: String?; let repeat_rule: String?; let repeat_interval: Int?; let repeat_end_date: String?; let priority: String?; let notes: String?; let labels: [String]?; let duration_minutes: Int?; let reminder_offsets: [Int]? }
            guard let a = parse(Args.self), let id = UUID(uuidString: a.id) else { return "{}" }
            let rr: RepeatRule = {
                switch a.repeat_rule {
                case .some("everyDay"): return .everyDay
                case .some("everyNDays"): return .everyNDays(max(2, a.repeat_interval ?? 2))
                case .some("none"): return .none
                default: return store.tasksById[id]?.repeatRule ?? .none
                }
            }()
            let start = a.start_date.flatMap { parseDateString($0, context: dateContext) }
            let due = a.due_date.flatMap { parseDatePreservingTime($0, context: dateContext) }
            let rend = a.repeat_end_date.flatMap { parseDateString($0, context: dateContext) }
            let pr = a.priority.flatMap { TaskPriority(rawValue: $0) }
            let newTitle = a.title.map { cleanedTitle($0) }
            store.setDetails(taskId: id, title: newTitle, dueDate: due, startAt: start, repeatRule: rr, repeatEndDate: rend, priority: pr, notes: a.notes, labels: a.labels, durationMinutes: a.duration_minutes, reminderOffsets: a.reminder_offsets)
            return "{\"status\":\"updated\"}"

        case "complete_task":
            struct Args: Decodable { let id: String; let completed_on: String? }
            guard let a = parse(Args.self), let id = UUID(uuidString: a.id) else { return "{}" }
            store.toggle(taskId: id, completedOn: dateContext)
            return "{\"status\":\"completed\"}"

        case "delete_task":
            struct Args: Decodable { let id: String }
            guard let a = parse(Args.self), let id = UUID(uuidString: a.id) else { return "{}" }
            store.deleteTask(id: id)
            return "{\"status\":\"deleted\"}"

        case "restore_task":
            struct Args: Decodable { let id: String }
            guard let a = parse(Args.self), let id = UUID(uuidString: a.id) else { return "{}" }
            store.restoreFromTrash(id: id)
            return "{\"status\":\"restored\"}"

        case "set_non_repeating_and_truncate":
            struct Args: Decodable { let id: String; let on_date: String }
            guard let a = parse(Args.self), let id = UUID(uuidString: a.id) else { return "{}" }
            let d = ISO8601DateFormatter().date(from: a.on_date) ?? dateContext
            // 将该任务改为不重复；模型层会截断系列并清理
            store.setDetails(taskId: id, title: nil, dueDate: nil, startAt: nil, repeatRule: .none, repeatEndDate: d, priority: nil, notes: nil, labels: nil, durationMinutes: nil, reminderOffsets: nil)
            return "{\"status\":\"truncated\"}"

        default:
            return "{}"
        }
    }
}

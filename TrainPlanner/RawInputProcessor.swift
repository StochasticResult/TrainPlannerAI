import Foundation

// MARK: - 对外响应模型
struct RawProcessorResponse: Codable, Equatable {
    let operation: String
    let result: String
    let task: BackendTask?
    let error: String?
}

// MARK: - 原始输入解析 & 执行
final class RawInputProcessor {
    private let manager: TaskManager

    init(manager: TaskManager) { self.manager = manager }

    // 输入格式举例：
    // "ADD: title=Buy milk; due_date=2025-08-25; priority=high"
    // "UPDATE: task_id=abc123; title=Buy bread"
    // "DELETE: task_id=abc123"
    func process(_ raw: String) -> String {
        do {
            let (op, fields) = try parse(raw)
            switch op {
            case "ADD":
                let t = try manager.add(payload: fields)
                return json(RawProcessorResponse(operation: op, result: "success", task: t, error: nil))
            case "UPDATE":
                let t = try manager.update(payload: fields)
                return json(RawProcessorResponse(operation: op, result: "success", task: t, error: nil))
            case "DELETE":
                try manager.delete(payload: fields)
                return json(RawProcessorResponse(operation: op, result: "success", task: nil, error: nil))
            default:
                throw TaskBackendError.invalidOperation
            }
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return json(RawProcessorResponse(operation: "UNKNOWN", result: "fail", task: nil, error: msg))
        }
    }

    // MARK: - 解析器
    func parse(_ raw: String) throws -> (String, [String: String]) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.firstIndex(of: ":") else { throw TaskBackendError.invalidOperation }
        let head = String(trimmed[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let body = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard ["ADD","UPDATE","DELETE"].contains(head) else { throw TaskBackendError.invalidOperation }

        var dict: [String: String] = [:]
        if !body.isEmpty {
            let parts = body.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            for part in parts where !part.isEmpty {
                let kv = part.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if kv.count == 2 {
                    dict[kv[0].lowercased()] = kv[1]
                } else {
                    throw TaskBackendError.invalidField(part)
                }
            }
        }
        // 基础字段校验
        if head == "UPDATE" || head == "DELETE" { guard dict["task_id"] != nil else { throw TaskBackendError.invalidField("task_id") } }
        if head == "ADD" { guard dict["title"] != nil else { throw TaskBackendError.invalidField("title") } }
        return (head, dict)
    }

    // MARK: - JSON 编码
    private func json<T: Encodable>(_ obj: T) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? enc.encode(obj), let s = String(data: data, encoding: .utf8) { return s }
        return "{}"
    }
}



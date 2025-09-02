import Foundation

final class NutritionService {
    static let shared = NutritionService()

    struct Operation: Identifiable { let id = UUID(); let kind: Kind; let payload: [String: String]; let summary: String }
    enum Kind { case create, update, delete, list }

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private var systemPrompt: String {
        """
        You are a nutrition tracker assistant. Use function calling only.
        Tasks:
        - create_meal(title, date, type?, calories?, protein_g?, fat_g?, carbs_g?, vitamins?)
        - update_meal(id, title?, type?, calories?, protein_g?, fat_g?, carbs_g?, vitamins?)
        - delete_meal(id)
        - list_meals(date)
        Rules:
        - Parse food from free text or photo caption, estimate macronutrients; vitamins map can be partial.
        - Dates must be ISO yyyy-MM-dd.
        - Keep user's original language for title.
        - If not nutrition intent, return __NO_ACTION__.
        Output via tool calls only.
        """
    }

    func handle(prompt: String, date: Date, store: NutritionStore, completion: @escaping (String) -> Void) {
        guard let apiKey = AIConfig.shared.apiKey else { completion("未配置 API Key"); return }
        let model = AIConfig.shared.model
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "Today is \(iso(date)). \n\(prompt)"]
        ]
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let tools: [[String: Any]] = [
            ["type": "function", "function": [
                "name": "create_meal",
                "parameters": ["type": "object", "properties": [
                    "title": ["type": "string"],
                    "date": ["type": "string"],
                    "type": ["type": "string", "enum": ["breakfast","lunch","dinner","snack","other"], "nullable": true],
                    "calories": ["type": "integer", "nullable": true],
                    "protein_g": ["type": "integer", "nullable": true],
                    "fat_g": ["type": "integer", "nullable": true],
                    "carbs_g": ["type": "integer", "nullable": true],
                    "vitamins": ["type": "object", "additionalProperties": ["type": "number"], "nullable": true]
                ], "required": ["title","date"]]
            ]],
            ["type": "function", "function": [
                "name": "update_meal",
                "parameters": ["type": "object", "properties": [
                    "id": ["type": "string"],
                    "title": ["type": "string", "nullable": true],
                    "type": ["type": "string", "enum": ["breakfast","lunch","dinner","snack","other"], "nullable": true],
                    "calories": ["type": "integer", "nullable": true],
                    "protein_g": ["type": "integer", "nullable": true],
                    "fat_g": ["type": "integer", "nullable": true],
                    "carbs_g": ["type": "integer", "nullable": true],
                    "vitamins": ["type": "object", "additionalProperties": ["type": "number"], "nullable": true]
                ], "required": ["id"]]
            ]],
            ["type": "function", "function": [
                "name": "delete_meal",
                "parameters": ["type": "object", "properties": ["id": ["type": "string"]], "required": ["id"]]
            ]],
            ["type": "function", "function": [
                "name": "list_meals",
                "parameters": ["type": "object", "properties": ["date": ["type": "string"]], "required": []]
            ]]
        ]
        let body: [String: Any] = ["model": model, "messages": messages, "tools": tools, "tool_choice": "auto"]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data, let resp = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = resp["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any] else { DispatchQueue.main.async { completion("AI 请求失败") }; return }
            if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
                for call in toolCalls { self.executeTool(call, date: date, store: store) }
                DispatchQueue.main.async { completion("__TOOLS_EXECUTED__") }
            } else {
                let text = (message["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async { completion(text.isEmpty ? AIService.noActionToken : text) }
            }
        }.resume()
    }

    private func executeTool(_ call: [String: Any], date: Date, store: NutritionStore) {
        guard let fn = (call["function"] as? [String: Any]) else { return }
        let name = fn["name"] as? String ?? ""
        let argsStr = fn["arguments"] as? String ?? "{}"
        let data = argsStr.data(using: .utf8) ?? Data()
        switch name {
        case "create_meal":
            struct A: Decodable { let title: String; let date: String; let type: String?; let calories: Int?; let protein_g: Int?; let fat_g: Int?; let carbs_g: Int?; let vitamins: [String: Double]? }
            if let a = try? JSONDecoder().decode(A.self, from: data) {
                let day = ISO8601DateFormatter().date(from: a.date) ?? date
                let t: MealType = MealType(rawValue: a.type ?? "other") ?? .other
                let e = MealEntry(title: a.title, createdAt: Date(), type: t, calories: a.calories, proteinGrams: a.protein_g, fatGrams: a.fat_g, carbsGrams: a.carbs_g, vitamins: a.vitamins)
                store.addEntry(e, for: day)
            }
        case "update_meal":
            struct A: Decodable { let id: String; let title: String?; let type: String?; let calories: Int?; let protein_g: Int?; let fat_g: Int?; let carbs_g: Int?; let vitamins: [String: Double]? }
            if let a = try? JSONDecoder().decode(A.self, from: data), let id = UUID(uuidString: a.id) {
                let t = a.type.flatMap { MealType(rawValue: $0) }
                store.setDetails(id: id, for: date, title: a.title, type: t, calories: a.calories, proteinGrams: a.protein_g, fatGrams: a.fat_g, carbsGrams: a.carbs_g, vitamins: a.vitamins)
            }
        case "delete_meal":
            struct A: Decodable { let id: String }
            if let a = try? JSONDecoder().decode(A.self, from: data), let id = UUID(uuidString: a.id) {
                store.deleteEntry(id: id, for: date)
            }
        case "list_meals":
            break
        default:
            break
        }
    }

    private func iso(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
}



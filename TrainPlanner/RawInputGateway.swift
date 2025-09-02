import Foundation

// 隐藏后台网关：统一承载 RawInput 能力，并与 UI 共用同一 ChecklistStore
final class RawInputGateway {
    static let shared = RawInputGateway()
    private init() {}

    private var store: ChecklistStore?
    private var manager: TaskManager?
    private var processor: RawInputProcessor?

    func configure(store: ChecklistStore) {
        self.store = store
        self.manager = TaskManager(store: store)
        if let manager = self.manager { self.processor = RawInputProcessor(manager: manager) }
    }

    // 对外：处理原始输入，返回 JSON 字符串
    func process(_ raw: String) -> String {
        guard let processor = processor else { return "{\"operation\":\"UNKNOWN\",\"result\":\"fail\",\"error\":\"gateway_not_configured\"}" }
        return processor.process(raw)
    }
}



import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "中文"
    case en = "English"
    var id: String { rawValue }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("app_language_v2") var currentLanguage: AppLanguage = .zh
    
    func localized(_ key: String) -> String {
        let lang = currentLanguage
        if let dict = translations[key] {
            return (lang == .zh ? dict.zh : dict.en)
        }
        return key // Fallback to key if not found
    }
}

// Global shortcut
func L(_ key: String) -> String {
    LanguageManager.shared.localized(key)
}

struct Translation {
    let zh: String
    let en: String
}

private let translations: [String: Translation] = [
    // Tabs & Titles
    "tab.plan": .init(zh: "计划", en: "Plan"),
    "tab.diet": .init(zh: "饮食", en: "Diet"),
    "tab.stats": .init(zh: "统计", en: "Stats"),
    "tab.profile": .init(zh: "我的档案", en: "Profile"),
    "nav.deleted": .init(zh: "最近删除", en: "Recently Deleted"),
    "nav.edit_task": .init(zh: "编辑任务", en: "Edit Task"),
    
    // Actions
    "act.save": .init(zh: "保存", en: "Save"),
    "act.cancel": .init(zh: "取消", en: "Cancel"),
    "act.delete": .init(zh: "删除", en: "Delete"),
    "act.complete": .init(zh: "完成", en: "Done"),
    "act.restore": .init(zh: "恢复", en: "Restore"),
    "act.clear": .init(zh: "清空", en: "Clear"),
    "act.close": .init(zh: "关闭", en: "Close"),
    "act.confirm": .init(zh: "确认", en: "Confirm"),
    "act.create": .init(zh: "创建", en: "Create"),
    "act.preview": .init(zh: "预览", en: "Preview"),
    "act.sync_now": .init(zh: "立即同步", en: "Sync Now"),
    "act.view_micro": .init(zh: "查看微量营养素", en: "View Micronutrients"),
    "act.take_photo": .init(zh: "拍照", en: "Camera"),
    "act.album": .init(zh: "相册", en: "Album"),
    
    // UI Labels
    "ui.today": .init(zh: "今天", en: "Today"),
    "ui.prev_day": .init(zh: "上一天", en: "Prev Day"),
    "ui.next_day": .init(zh: "下一天", en: "Next Day"),
    "ui.empty_tasks": .init(zh: "这里还没有任务", en: "No tasks yet"),
    "ui.empty_deleted": .init(zh: "暂无最近删除", en: "Trash is empty"),
    "ui.loading": .init(zh: "正在执行…", en: "Executing…"),
    "ui.ai_thinking": .init(zh: "正在理解你的请求…", en: "Thinking…"),
    
    // Task Fields
    "field.title": .init(zh: "标题", en: "Title"),
    "field.content": .init(zh: "内容", en: "Content"),
    "field.start_due": .init(zh: "开始/截止", en: "Start / Due"),
    "field.enable_start": .init(zh: "启用开始时间", en: "Enable Start Time"),
    "field.start_time": .init(zh: "开始时间", en: "Start Time"),
    "field.enable_due": .init(zh: "启用截止日期", en: "Enable Due Date"),
    "field.due_time": .init(zh: "截止时间", en: "Due Time"),
    "field.repeat": .init(zh: "重复", en: "Repeat"),
    "field.repeat_rule": .init(zh: "规则", en: "Rule"),
    "field.repeat_end": .init(zh: "设置重复结束日", en: "Set End Date"),
    "field.end_date": .init(zh: "结束日", en: "End Date"),
    "field.prio_tags": .init(zh: "优先级与标签", en: "Priority & Tags"),
    "field.priority": .init(zh: "优先级", en: "Priority"),
    "field.tags_hint": .init(zh: "标签（逗号分隔）", en: "Tags (comma separated)"),
    "field.notes": .init(zh: "备注", en: "Notes"),
    "field.duration_remind": .init(zh: "时长与提醒", en: "Duration & Reminder"),
    "field.duration_hint": .init(zh: "预计时长（分钟）", en: "Est. Duration (min)"),
    "field.reminder_hint": .init(zh: "提醒（分钟，逗号分隔，表示提前）", en: "Remind before (min, comma sep)"),
    
    // Task Logic/Status
    "status.conflict_due": .init(zh: "已设置重复：截止不可用", en: "Repeat set: Due date unavailable"),
    "status.conflict_repeat": .init(zh: "已设置截止：重复不可用", en: "Due set: Repeat unavailable"),
    
    // Task Priority Enums
    "prio.none": .init(zh: "无", en: "None"),
    "prio.low": .init(zh: "低", en: "Low"),
    "prio.medium": .init(zh: "中", en: "Med"),
    "prio.high": .init(zh: "高", en: "High"),
    
    // Repeat Enums
    "rep.none": .init(zh: "不重复", en: "None"),
    "rep.every_day": .init(zh: "每天", en: "Every Day"),
    "rep.every_2_days": .init(zh: "每2天", en: "Every 2 Days"),
    "rep.every_3_days": .init(zh: "每3天", en: "Every 3 Days"),
    "rep.every_7_days": .init(zh: "每7天", en: "Every 7 Days"),
    
    // Profile
    "prof.avatar": .init(zh: "头像", en: "Avatar"),
    "prof.basic_info": .init(zh: "基本信息", en: "Basic Info"),
    "prof.nickname": .init(zh: "昵称", en: "Nickname"),
    "prof.bio": .init(zh: "签名", en: "Bio"),
    "prof.theme": .init(zh: "主题", en: "Theme"),
    "prof.color": .init(zh: "颜色", en: "Color"),
    "prof.preview": .init(zh: "预览", en: "Preview"),
    "prof.theme_presets": .init(zh: "主题预设", en: "Presets"),
    "prof.daily_reminder": .init(zh: "每日提醒", en: "Daily Reminder"),
    "prof.enable_reminder": .init(zh: "开启提醒", en: "Enable Reminder"),
    "prof.time": .init(zh: "时间", en: "Time"),
    "prof.icloud": .init(zh: "iCloud", en: "iCloud"),
    "prof.icloud_hint": .init(zh: "开启后会通过 iCloud Key-Value Store 同步任务与排序。", en: "Sync tasks and order via iCloud KVS."),
    "prof.ai_settings": .init(zh: "AI 助手设置", en: "AI Assistant Settings"),
    "prof.model": .init(zh: "模型", en: "Model"),
    "prof.confirm_exec": .init(zh: "执行前需要确认", en: "Confirm before execution"),
    "prof.language": .init(zh: "语言", en: "Language"),
    
    // Stats
    "stat.range": .init(zh: "范围", en: "Range"),
    "stat.overall": .init(zh: "整体", en: "Overall"),
    "stat.total_tasks": .init(zh: "总任务", en: "Total"),
    "stat.completed": .init(zh: "已完成", en: "Done"),
    "stat.incomplete": .init(zh: "未完成", en: "Todo"),
    "stat.completion_rate": .init(zh: "完成率", en: "Rate"),
    "stat.priority_dist": .init(zh: "优先级分布", en: "By Priority"),
    "stat.tags_top10": .init(zh: "标签 Top 10", en: "Top 10 Tags"),
    "stat.no_tags": .init(zh: "暂无标签数据", en: "No tag data"),
    "stat.range_last7": .init(zh: "近7天", en: "Last 7 Days"),
    "stat.range_last30": .init(zh: "近30天", en: "Last 30 Days"),
    "stat.range_all": .init(zh: "全部", en: "All Time"),
    
    // Alerts
    "alert.clear_trash": .init(zh: "清空最近删除？", en: "Empty Trash?"),
    "alert.irreversible": .init(zh: "此操作不可撤销", en: "This cannot be undone."),
    "alert.delete_item": .init(zh: "彻底删除此项目？", en: "Delete permanently?"),
    
    // Nutrition
    "nut.calories": .init(zh: "热量", en: "Calories"),
    "nut.left": .init(zh: "剩余", en: "Left"),
    "nut.protein": .init(zh: "蛋白", en: "Protein"),
    "nut.fat": .init(zh: "脂肪", en: "Fat"),
    "nut.carbs": .init(zh: "碳水", en: "Carbs"),
    "nut.meal": .init(zh: "餐次", en: "Meal"),
    "nut.all": .init(zh: "全部", en: "All"),
    "nut.subtotal": .init(zh: "小计", en: "Subtotal"),
    "nut.set_goal_2000": .init(zh: "设热量目标 2000", en: "Goal: 2000 kcal"),
    "nut.set_goal_prot": .init(zh: "设蛋白目标 120g", en: "Goal: 120g Prot"),
    "nut.set_goal_fat": .init(zh: "设脂肪目标 70g", en: "Goal: 70g Fat"),
    "nut.set_goal_carb": .init(zh: "设碳水目标 250g", en: "Goal: 250g Carb"),
    "nut.clear_goals": .init(zh: "清除目标", en: "Clear Goals"),
    "nut.input_placeholder": .init(zh: "我吃了…（文字或用 AI）", en: "I ate... (text or AI)"),
    
    // AI Tips
    "ai.tip_fail": .init(zh: "我好像没听懂～\n可以补充要做的事和时间，比如：‘明天 9 点提醒我交水费，优先级高’。", en: "I didn't catch that.\nTry adding task and time, e.g., 'Remind me to pay bills tomorrow at 9am, high priority'."),
    "ai.tip_busy": .init(zh: "网络有点忙，或我没理解你的意思。\n可以换个说法再试试：例如 ‘明天 9 点提醒我交水费，高优先级，标签账单’。", en: "Network busy or input unclear.\nTry again: 'Pay bills tomorrow at 9am, high priority, tag bills'."),
    "ai.fail_req": .init(zh: "AI 请求失败", en: "AI Request Failed"),
    "ai.no_key": .init(zh: "未配置 API Key", en: "API Key missing"),
    "ai.review_title": .init(zh: "AI 建议操作", en: "AI Suggestions"),
    
    // Extra
    "nav.details": .init(zh: "详情", en: "Details"),
    "ui.today_progress": .init(zh: "今日进度", en: "Progress"),
    "ui.defer_tmr": .init(zh: "未完推明天", en: "Defer to Tmr"),
    "ui.select_date": .init(zh: "选择日期", en: "Select Date"),
    "ai.no_changes": .init(zh: "没有可执行的更改", en: "No changes detected"),
    "ai.no_changes_hint": .init(zh: "如果这是错误，请重试或修改指令。若问题持续，请在设置中关闭‘执行前确认’直接执行。", en: "If this is an error, try rephrasing. Disable confirmation in settings to bypass."),
    
    // Meal Types
    "meal.breakfast": .init(zh: "早餐", en: "Breakfast"),
    "meal.lunch": .init(zh: "午餐", en: "Lunch"),
    "meal.dinner": .init(zh: "晚餐", en: "Dinner"),
    "meal.snack": .init(zh: "加餐", en: "Snack"),
    "meal.other": .init(zh: "其它", en: "Other"),

    // AI Summary
    "ai.summary.create": .init(zh: "创建任务", en: "Create Task"),
    "ai.summary.update": .init(zh: "更新任务", en: "Update Task"),
    "ai.summary.complete": .init(zh: "完成任务", en: "Complete Task"),
    "ai.summary.delete": .init(zh: "删除任务", en: "Delete Task"),
    "ai.summary.restore": .init(zh: "恢复任务", en: "Restore Task"),
    "ai.summary.truncate": .init(zh: "设为不重复并截断", en: "Truncate Series"),
    "ai.field.start": .init(zh: "开始日", en: "Start"),
    "ai.field.due": .init(zh: "截止", en: "Due"),
    "ai.field.repeat": .init(zh: "重复", en: "Repeat"),
    "ai.field.end": .init(zh: "结束", en: "End"),
    "ai.field.priority": .init(zh: "优先级", en: "Priority"),
    "ai.val.none": .init(zh: "无", en: "None"),
    "ai.msg.notes_update": .init(zh: "备注将更新", en: "Notes updated"),
    "ai.msg.completed_on": .init(zh: "完成于", en: "Completed on"),
    "ai.msg.moved_trash": .init(zh: "将移动到最近删除", en: "Moved to Trash"),
]


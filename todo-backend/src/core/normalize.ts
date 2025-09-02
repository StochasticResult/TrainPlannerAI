import { v4 as uuidv4 } from "uuid";
import { ensureTimeOrDefault } from "./time";
import type { Task, RepeatRule, Priority } from "./types";
import type { CreatePayload, UpdatePayload } from "./validation";

const repeatMap: Record<string, RepeatRule> = {
  "none": "none",
  "daily": "daily",
  "every_2_days": "every_2_days",
  "every_3_days": "every_3_days",
  "every_7_days": "every_7_days",
  "每天": "daily"
};

const priorityMap: Record<string, Priority> = {
  "none": "none",
  "low": "low",
  "medium": "medium",
  "high": "high",
  "低": "low",
  "中": "medium",
  "高": "high"
};

export function normalizeCreate(input: CreatePayload, now = new Date()): Task {
  const id = input.task_id ?? uuidv4();
  const enable_start_time = input.enable_start_time ?? true;
  const enable_due_date = input.enable_due_date ?? Boolean(input.due_date || input.due_time);
  const repeat_rule0 = (input.repeat_rule ?? "none").toString().toLowerCase();
  const repeat_rule = (enable_due_date ? "none" : (repeatMap[repeat_rule0] ?? "none")) as RepeatRule;
  const priority = (priorityMap[(input.priority ?? "none").toString().toLowerCase()] ?? "none") as Priority;
  const is_reminder = input.is_reminder ?? false;
  const estimated_duration = input.estimated_duration ?? 0;

  const start_date = input.start_date ?? null;
  const start_time = enable_start_time ? ensureTimeOrDefault(input.start_time) : null;

  const due_date = enable_due_date ? (input.due_date ?? null) : null;
  const due_time = enable_due_date ? ensureTimeOrDefault(input.due_time) : null;

  // tags 清洗：去空格、去重
  const tags = (() => {
    const raw = (input.tags ?? "").split(",").map(s => s.trim()).filter(Boolean);
    const set = new Set(raw);
    return Array.from(set).join(",");
  })();

  // reminder_time 与补全
  const reminder_time = (() => {
    const rt = input.reminder_time ?? null;
    if (!is_reminder) return null;
    if (rt && /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(rt)) return rt;
    // 无日期：优先 start_date，其次 due_date
    const hm = ensureTimeOrDefault(input.start_time ?? input.due_time);
    const base = start_date ?? due_date;
    if (!base) throw new Error("reminder_time requires start_date or due_date when missing date part");
    return `${base} ${hm}`;
  })();

  const reminder_advance = input.reminder_advance ?? (is_reminder ? 10 : null);
  const nowISO = now.toISOString();

  return {
    task_id: id,
    title: input.title!,
    enable_start_time,
    start_date,
    start_time,
    enable_due_date,
    due_date,
    due_time,
    repeat_rule,
    priority,
    tags,
    notes: input.notes ?? "",
    estimated_duration,
    is_reminder,
    reminder_time,
    reminder_advance,
    created_at: nowISO,
    updated_at: nowISO
  };
}

export function normalizeUpdate(base: Task, patch: UpdatePayload, now = new Date()): Task {
  const enable_start_time = patch.enable_start_time ?? base.enable_start_time;
  const enable_due_date = patch.enable_due_date ?? base.enable_due_date || Boolean(patch.due_date || patch.due_time);

  const repeat_ruleCandidate = patch.repeat_rule ?? base.repeat_rule;
  const rrNorm = repeatMap[repeat_ruleCandidate as string] ?? repeat_ruleCandidate;
  const repeat_rule = (enable_due_date ? "none" : rrNorm) as RepeatRule;

  const priority = (priorityMap[(patch.priority ?? base.priority) as string] ?? (patch.priority ?? base.priority)) as Priority;

  const start_date = patch.start_date ?? base.start_date;
  const start_time = enable_start_time ? ensureTimeOrDefault(patch.start_time ?? base.start_time) : null;

  const due_date = enable_due_date ? (patch.due_date ?? base.due_date) : null;
  const due_time = enable_due_date ? ensureTimeOrDefault(patch.due_time ?? base.due_time) : null;

  const tags = (() => {
    const raw = (patch.tags ?? base.tags).split(",").map(s => s.trim()).filter(Boolean);
    const set = new Set(raw);
    return Array.from(set).join(",");
  })();

  const is_reminder = patch.is_reminder ?? base.is_reminder;
  const reminder_advance = patch.reminder_advance ?? base.reminder_advance;
  const reminder_time = (() => {
    const rt = patch.reminder_time ?? base.reminder_time;
    if (!is_reminder) return null;
    if (rt && /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(rt)) return rt;
    const hm = ensureTimeOrDefault(patch.start_time ?? patch.due_time ?? base.start_time ?? base.due_time);
    const baseDate = start_date ?? due_date;
    if (!baseDate) throw new Error("reminder_time requires start_date or due_date");
    return `${baseDate} ${hm}`;
  })();

  return {
    ...base,
    ...patch,
    enable_start_time,
    enable_due_date,
    start_date,
    start_time,
    due_date,
    due_time,
    repeat_rule,
    priority,
    tags,
    reminder_time,
    reminder_advance,
    updated_at: now.toISOString()
  } as Task;
}


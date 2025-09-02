export type RepeatRule = "none" | "daily" | "every_2_days" | "every_3_days" | "every_7_days";
export type Priority = "none" | "low" | "medium" | "high";

export interface Task {
  task_id: string;               // uuid
  title: string;
  enable_start_time: boolean;
  start_date: string | null;     // YYYY-MM-DD
  start_time: string | null;     // HH:MM (24h)
  enable_due_date: boolean;
  due_date: string | null;       // YYYY-MM-DD
  due_time: string | null;       // HH:MM (24h)
  repeat_rule: RepeatRule;       // 有 due_date 时必须为 "none"
  priority: Priority;
  tags: string;                  // 逗号分隔，无空格 "a,b"
  notes: string;
  estimated_duration: number;    // 分钟，>=0
  is_reminder: boolean;
  reminder_time: string | null;  // YYYY-MM-DD HH:MM (24h)
  reminder_advance: number | null; // 分钟，>=0
  created_at: string;            // ISO
  updated_at: string;            // ISO
}

export type CreateAction = { action: "CREATE"; payload: Partial<Task> };
export type UpdateAction = { action: "UPDATE"; payload: Partial<Task> & { task_id: string } };
export type DeleteAction = { action: "DELETE"; payload: { task_id: string } };
export type QueryAction  = { action: "QUERY";  payload: { task_id: string } };
export type ErrorAction  = { action: "ERROR";  payload: {}; reason: string; suggest?: string };

export type ParsedCommand = CreateAction | UpdateAction | DeleteAction | QueryAction | ErrorAction;


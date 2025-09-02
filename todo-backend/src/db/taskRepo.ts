import { db, toInt } from "./index";
import type { Task } from "../core/types";

const insertSQL = db.prepare(`
INSERT INTO tasks (
  task_id, title, enable_start_time, start_date, start_time,
  enable_due_date, due_date, due_time, repeat_rule, priority,
  tags, notes, estimated_duration, is_reminder, reminder_time, reminder_advance,
  created_at, updated_at
) VALUES (
  @task_id, @title, @enable_start_time, @start_date, @start_time,
  @enable_due_date, @due_date, @due_time, @repeat_rule, @priority,
  @tags, @notes, @estimated_duration, @is_reminder, @reminder_time, @reminder_advance,
  @created_at, @updated_at
)`);

const updatePartialBase = `UPDATE tasks SET `;

export function createTask(task: Task) {
  insertSQL.run({
    ...task,
    enable_start_time: toInt(task.enable_start_time),
    enable_due_date: toInt(task.enable_due_date),
    is_reminder: toInt(task.is_reminder)
  });
  return getTask(task.task_id)!;
}

export function updateTaskPartial(taskId: string, patch: Partial<Task>) {
  const allowed = [
    "title","enable_start_time","start_date","start_time",
    "enable_due_date","due_date","due_time","repeat_rule","priority",
    "tags","notes","estimated_duration","is_reminder","reminder_time","reminder_advance","updated_at"
  ] as const;
  const keys = Object.keys(patch).filter(k => allowed.includes(k as any));
  if (keys.length === 0) return getTask(taskId);
  const sets = keys.map(k => `${k}=@${k}`).join(", ");
  const stmt = db.prepare(`${updatePartialBase}${sets} WHERE task_id=@task_id`);
  const payload: any = { task_id: taskId, ...patch };
  if (payload.enable_start_time !== undefined) payload.enable_start_time = toInt(payload.enable_start_time);
  if (payload.enable_due_date !== undefined) payload.enable_due_date = toInt(payload.enable_due_date);
  if (payload.is_reminder !== undefined) payload.is_reminder = toInt(payload.is_reminder);
  stmt.run(payload);
  return getTask(taskId)!;
}

export function deleteTask(taskId: string) {
  db.prepare(`DELETE FROM tasks WHERE task_id=?`).run(taskId);
}

export function getTask(taskId: string): Task | null {
  const row = db.prepare(`SELECT * FROM tasks WHERE task_id=?`).get(taskId) as any;
  return row ? rowToTask(row) : null;
}

export function listTasks(filter: { date?: string; tag?: string; priority?: string } = {}) {
  const clauses: string[] = [];
  const params: any[] = [];
  if (filter.date) { clauses.push(`(start_date = ? OR due_date = ?)`); params.push(filter.date, filter.date); }
  if (filter.tag)  { clauses.push(`(tags LIKE ?) `); params.push(`%${filter.tag}%`); }
  if (filter.priority) { clauses.push(`priority = ?`); params.push(filter.priority); }
  const where = clauses.length ? `WHERE ${clauses.join(" AND ")}` : "";
  const rows = db.prepare(`SELECT * FROM tasks ${where} ORDER BY created_at ASC`).all(...params) as any[];
  return rows.map(rowToTask);
}

function rowToTask(row: any): Task {
  return {
    task_id: row.task_id,
    title: row.title,
    enable_start_time: !!row.enable_start_time,
    start_date: row.start_date,
    start_time: row.start_time,
    enable_due_date: !!row.enable_due_date,
    due_date: row.due_date,
    due_time: row.due_time,
    repeat_rule: row.repeat_rule,
    priority: row.priority,
    tags: row.tags,
    notes: row.notes,
    estimated_duration: row.estimated_duration,
    is_reminder: !!row.is_reminder,
    reminder_time: row.reminder_time,
    reminder_advance: row.reminder_advance,
    created_at: row.created_at,
    updated_at: row.updated_at
  };
}



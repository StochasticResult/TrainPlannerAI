CREATE TABLE IF NOT EXISTS tasks (
  task_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  enable_start_time INTEGER NOT NULL DEFAULT 0,
  start_date TEXT,
  start_time TEXT,
  enable_due_date INTEGER NOT NULL DEFAULT 0,
  due_date TEXT,
  due_time TEXT,
  repeat_rule TEXT NOT NULL DEFAULT 'none',
  priority TEXT NOT NULL DEFAULT 'none',
  tags TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  estimated_duration INTEGER NOT NULL DEFAULT 0,
  is_reminder INTEGER NOT NULL DEFAULT 0,
  reminder_time TEXT,
  reminder_advance INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_date);


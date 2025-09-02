import { Router } from "express";
import { createTask, updateTaskPartial, deleteTask, getTask, listTasks } from "../db/taskRepo";
import { CreatePayloadSchema, UpdatePayloadSchema } from "../core/validation";
import { normalizeCreate, normalizeUpdate } from "../core/normalize";
import { NotFoundError, ValidationError } from "../core/errors";

export const tasksRouter = Router();

tasksRouter.post("/tasks", (req, res, next) => {
  try {
    const v = CreatePayloadSchema.safeParse(req.body);
    if (!v.success) throw new ValidationError(v.error.issues);
    const task = normalizeCreate(v.data);
    const saved = createTask(task);
    res.status(201).json(saved);
  } catch (e) { next(e) }
});

tasksRouter.patch("/tasks/:taskId", (req, res, next) => {
  try {
    const id = req.params.taskId;
    const exist = getTask(id);
    if (!exist) throw new NotFoundError("task not found");
    const v = UpdatePayloadSchema.safeParse({ ...req.body, task_id: id });
    if (!v.success) throw new ValidationError(v.error.issues);
    const merged = normalizeUpdate(exist, v.data);
    const saved = updateTaskPartial(id, { ...merged, task_id: undefined });
    res.json(saved);
  } catch (e) { next(e) }
});

tasksRouter.delete("/tasks/:taskId", (req, res, next) => {
  try {
    const id = req.params.taskId;
    const exist = getTask(id);
    if (!exist) throw new NotFoundError("task not found");
    deleteTask(id);
    res.json({ status: "success" });
  } catch (e) { next(e) }
});

tasksRouter.get("/tasks/:taskId", (req, res, next) => {
  try {
    const id = req.params.taskId;
    const t = getTask(id);
    if (!t) throw new NotFoundError("task not found");
    res.json(t);
  } catch (e) { next(e) }
});

tasksRouter.get("/tasks", (req, res, next) => {
  try {
    const { date, tag, priority } = req.query as any;
    const list = listTasks({ date, tag, priority });
    res.json(list);
  } catch (e) { next(e) }
});



import { Router } from "express";
import { parseCommandByLLM, toExecutable } from "../ai/parser";
import { getTask, createTask, updateTaskPartial, deleteTask } from "../db/taskRepo";

export const nlRouter = Router();

nlRouter.post("/nl/command", async (req, res, next) => {
  try {
    const { text, task_id } = req.body as { text: string; task_id?: string };
    if (!text || typeof text !== "string" || text.length > 512) { return res.status(400).json({ status: "fail", message: "text required (<=512)" }) }
    const parsed = await parseCommandByLLM(text, task_id);
    let result: any = null;
    if (parsed.action === "CREATE") {
      const exec = toExecutable(parsed);
      result = createTask(exec.data);
    } else if (parsed.action === "UPDATE") {
      const base = getTask((parsed as any).payload.task_id);
      if (!base) return res.status(404).json({ status: "fail", message: "task not found" });
      const exec = toExecutable(parsed, base);
      result = updateTaskPartial(base.task_id, { ...exec.data, task_id: undefined });
    } else if (parsed.action === "DELETE") {
      const id = (parsed as any).payload.task_id;
      const base = getTask(id);
      if (!base) return res.status(404).json({ status: "fail", message: "task not found" });
      deleteTask(id);
      result = { status: "success" };
    } else if (parsed.action === "QUERY") {
      const id = (parsed as any).payload.task_id;
      result = getTask(id);
      if (!result) return res.status(404).json({ status: "fail", message: "task not found" });
    }
    res.json({ status: "success", action: parsed.action, data: result });
  } catch (e) { next(e) }
});



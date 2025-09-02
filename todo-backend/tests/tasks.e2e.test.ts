import { describe, it, expect, beforeAll, afterAll } from "vitest";
import request from "supertest";
import app from "../src/server";
import { db } from "../src/db/index";

describe("tasks CRUD", () => {
  beforeAll(() => { process.env.VITEST = "1" });
  afterAll(() => { db.exec("DELETE FROM tasks"); });

  it("create -> get -> patch -> delete", async () => {
    const create = await request(app).post("/tasks").send({
      title: "Buy milk",
      enable_start_time: true,
      start_date: "2025-01-01",
      start_time: "09:00",
      enable_due_date: true,
      due_date: "2025-01-01",
      due_time: "18:00"
    }).expect(201);
    expect(create.body.task_id).toBeDefined();
    expect(create.body.repeat_rule).toBe("none");

    const taskId = create.body.task_id as string;
    const got = await request(app).get(`/tasks/${taskId}`).expect(200);
    expect(got.body.title).toBe("Buy milk");

    const patched = await request(app).patch(`/tasks/${taskId}`).send({ priority: "high", reminder_advance: 30, is_reminder: true }).expect(200);
    expect(patched.body.priority).toBe("high");

    await request(app).delete(`/tasks/${taskId}`).expect(200);
    await request(app).get(`/tasks/${taskId}`).expect(404);
  });
});



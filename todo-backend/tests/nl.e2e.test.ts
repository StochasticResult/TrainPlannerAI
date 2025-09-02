import { describe, it, expect, beforeAll, afterAll } from "vitest";
import request from "supertest";
import app from "../src/server";
import { db } from "../src/db/index";

describe("/nl/command", () => {
  beforeAll(() => { process.env.VITEST = "1"; process.env.MOCK_OPENAI = "1" });
  afterAll(() => { db.exec("DELETE FROM tasks"); });

  it("create by natural language (mock)", async () => {
    const res = await request(app).post("/nl/command").send({ text: "明天早上9点提醒我交水费，优先级高，标签账单，预计15分钟" }).expect(200);
    expect(res.body.status).toBe("success");
    expect(["CREATE","UPDATE","DELETE","QUERY"]).toContain(res.body.action);
  });

  it("update by natural language (mock)", async () => {
    const create = await request(app).post("/tasks").send({ title: "test", enable_start_time: true, start_date: "2025-01-01", start_time: "09:00" }).expect(201);
    const id = create.body.task_id as string;
    const res = await request(app).post("/nl/command").send({ text: "把优先级改成中，提醒提前30分钟", task_id: id }).expect(200);
    expect(res.body.status).toBe("success");
  });

  it("delete by natural language (mock)", async () => {
    const create = await request(app).post("/tasks").send({ title: "to be deleted", enable_start_time: true, start_date: "2025-01-01", start_time: "09:00" }).expect(201);
    const id = create.body.task_id as string;
    await request(app).post("/nl/command").send({ text: "删除这个任务", task_id: id }).expect(200);
    await request(app).get(`/tasks/${id}`).expect(404);
  });
});



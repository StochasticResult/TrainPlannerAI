import { SYSTEM_PROMPT } from "./systemPrompt";
import { openai } from "./openai";
import { z } from "zod";
import { CreatePayloadSchema, UpdatePayloadSchema, DeletePayloadSchema, QueryPayloadSchema } from "../core/validation";
import { normalizeCreate, normalizeUpdate } from "../core/normalize";
import type { ParsedCommand, Task } from "../core/types";
import { BadRequestError, ValidationError } from "../core/errors";

const ActionEnum = z.enum(["CREATE","UPDATE","DELETE","QUERY","ERROR"]);

const LLMResponseSchema = z.object({ action: ActionEnum, payload: z.record(z.any()), reason: z.string().optional(), suggest: z.string().optional() });

function jsonSchemaPayload() {
  return {
    name: "task_command",
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        action: { type: "string", enum: ["CREATE","UPDATE","DELETE","QUERY","ERROR"] },
        payload: { type: "object" },
        reason: { type: "string" },
        suggest: { type: "string" }
      },
      required: ["action","payload"]
    }
  } as const;
}

export async function parseCommandByLLM(text: string, taskId?: string): Promise<ParsedCommand> {
  const content = [
    { role: "system" as const, content: SYSTEM_PROMPT },
    { role: "user" as const, content: JSON.stringify({ text, task_id: taskId || null }) }
  ];

  const useMock = process.env.MOCK_OPENAI === "1";
  let parsed: any;
  if (useMock) {
    // 简易 MOCK：若包含 "删除" → DELETE；包含 "修改" → UPDATE；否则 CREATE
    const lower = text.toLowerCase();
    if (lower.includes("删除")) parsed = { action: "DELETE", payload: { task_id: taskId } };
    else if (lower.includes("改") || lower.includes("修改")) parsed = { action: "UPDATE", payload: { task_id: taskId, priority: "medium" } };
    else parsed = { action: "CREATE", payload: { title: text, enable_start_time: true, start_date: null, start_time: null, enable_due_date: false, repeat_rule: "none" } };
  } else {
    const resp = await openai.responses.create({
      model: "gpt-5-nano",
      temperature: 0.2,
      max_output_tokens: 160,
      input: content,
      response_format: { type: "json_schema", json_schema: jsonSchemaPayload() }
    } as any);
    const textOut = resp.output_text;
    parsed = JSON.parse(textOut || "{}");
  }

  const safe = LLMResponseSchema.safeParse(parsed);
  if (!safe.success) throw new BadRequestError("LLM parse failed", safe.error.issues);
  const cmd = safe.data as ParsedCommand;
  if (cmd.action === "ERROR") throw new BadRequestError((parsed.reason as string) || "LLM error");
  return cmd;
}

export function toExecutable(cmd: ParsedCommand, base?: Task) {
  switch (cmd.action) {
    case "CREATE": {
      const v = CreatePayloadSchema.safeParse(cmd.payload);
      if (!v.success) throw new ValidationError(v.error.issues);
      const t = normalizeCreate(v.data);
      return { action: "CREATE" as const, data: t };
    }
    case "UPDATE": {
      const v = UpdatePayloadSchema.safeParse(cmd.payload);
      if (!v.success) throw new ValidationError(v.error.issues);
      if (!base) throw new BadRequestError("base task required for UPDATE");
      const t = normalizeUpdate(base, v.data);
      return { action: "UPDATE" as const, data: t };
    }
    case "DELETE": {
      const v = DeletePayloadSchema.safeParse(cmd.payload);
      if (!v.success) throw new ValidationError(v.error.issues);
      return { action: "DELETE" as const, data: v.data };
    }
    case "QUERY": {
      const v = QueryPayloadSchema.safeParse(cmd.payload);
      if (!v.success) throw new ValidationError(v.error.issues);
      return { action: "QUERY" as const, data: v.data };
    }
    default:
      throw new BadRequestError("unsupported action");
  }
}


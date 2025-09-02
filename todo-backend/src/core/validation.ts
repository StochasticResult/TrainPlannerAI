import { z } from "zod";
import type { RepeatRule, Priority } from "./types";

export const RepeatRuleEnum = z.enum(["none","daily","every_2_days","every_3_days","every_7_days"]) as z.ZodType<RepeatRule>;
export const PriorityEnum = z.enum(["none","low","medium","high"]) as z.ZodType<Priority>;

const YMD = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const HM = z.string().regex(/^\d{2}:\d{2}$/);
const YMDHM = z.string().regex(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/);

export const CreatePayloadSchema = z.object({
  task_id: z.string().uuid().optional(),
  title: z.string().min(1),
  enable_start_time: z.boolean().optional(),
  start_date: YMD.optional().nullable(),
  start_time: HM.optional().nullable(),
  enable_due_date: z.boolean().optional(),
  due_date: YMD.optional().nullable(),
  due_time: HM.optional().nullable(),
  repeat_rule: RepeatRuleEnum.optional(),
  priority: PriorityEnum.optional(),
  tags: z.string().optional(),
  notes: z.string().optional(),
  estimated_duration: z.number().int().min(0).optional(),
  is_reminder: z.boolean().optional(),
  reminder_time: YMDHM.optional().nullable(),
  reminder_advance: z.number().int().min(0).optional().nullable()
});

export const UpdatePayloadSchema = CreatePayloadSchema.partial().extend({ task_id: z.string().uuid() });
export const DeletePayloadSchema = z.object({ task_id: z.string().uuid() });
export const QueryPayloadSchema = z.object({ task_id: z.string().uuid() });

export type CreatePayload = z.infer<typeof CreatePayloadSchema>;
export type UpdatePayload = z.infer<typeof UpdatePayloadSchema>;
export type DeletePayload = z.infer<typeof DeletePayloadSchema>;
export type QueryPayload = z.infer<typeof QueryPayloadSchema>;


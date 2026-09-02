"use server";

import { revalidatePath } from "next/cache";
import { apiGet, apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

// ─────────────────────────────────────────────
// Plan Day wire-contract types — mirrors the /api/whatnow/* backend contract
// used by the Plan Day page. Declared here (not in lib/whatnow/types.ts)
// because this is a shared-lib module (lib/server/**) and the boundaries
// lint only allows shared-lib to depend on shared-lib, never a feature-lib —
// same reason CalendarEvent is declared directly in lib/server/calendar.ts
// rather than imported from lib/calendar/types.ts. The /now feature's own
// Task type in lib/whatnow/types.ts is untouched and unrelated to this one.
// ─────────────────────────────────────────────

export type PlanTaskStatus = "inbox" | "planned" | "active" | "paused" | "done" | "decayed";

export interface PlanChip {
  id: string;
  kind: "deadline" | "category" | "duration" | "vague";
  label: string;
  value?: string;
}

export interface PlanTask {
  id: string;
  title: string;
  status: PlanTaskStatus;
  durationMin?: number;
  deadline?: string;
  category?: string;
  chips?: PlanChip[];
  /** RFC3339 start time of this task's time block; absent when unscheduled. */
  scheduledStart?: string;
}

export interface DayPlan {
  date: string;
  scheduled: PlanTask[];
  unscheduled: PlanTask[];
}

export interface PlanToday {
  tasks: PlanTask[];
  cap: number;
  throughput: number;
}

export async function getDayPlanAction(date: string, tzOffsetMin = 0): Promise<ActionResult<DayPlan>> {
  try {
    const plan = await apiGet<DayPlan>(`/api/whatnow/plan/day?date=${date}&tz=${tzOffsetMin}`);
    return { ok: true, data: plan };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not load the day plan." };
  }
}

export async function getPlanInboxAction(): Promise<ActionResult<PlanTask[]>> {
  try {
    const tasks = await apiGet<PlanTask[]>("/api/whatnow/tasks/inbox");
    return { ok: true, data: tasks };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not load the inbox." };
  }
}

export interface SchedulePatch {
  /** RFC3339 start time to schedule the block; null clears it (unschedule). */
  scheduledStart?: string | null;
  durationMin?: number;
  /** Set to "planned" when promoting an inbox task straight onto the timeline. */
  status?: "planned";
}

export async function scheduleTaskAction(id: string, patch: SchedulePatch): Promise<ActionResult<PlanTask>> {
  const result = await apiAction<PlanTask>("PATCH", `/api/whatnow/tasks/${id}`, {
    ...patch,
    scheduledStart: patch.scheduledStart === null ? "" : patch.scheduledStart,
  });
  if (result.ok) revalidatePath(ROUTES.PLAN);
  return result;
}

export async function completeTaskAction(id: string): Promise<ActionResult<{ unlockedTasks: PlanTask[] }>> {
  const result = await apiAction<{ unlockedTasks: PlanTask[] }>("POST", `/api/whatnow/tasks/${id}/complete`);
  if (result.ok) revalidatePath(ROUTES.PLAN);
  return result;
}

// Reorders (and/or grows) the planned queue. taskIds must include every
// currently-planned task's ID, not just the ones being reordered — the
// backend demotes any planned task omitted from this array back to inbox.
export async function reorderBacklogAction(taskIds: string[]): Promise<ActionResult<PlanToday>> {
  const result = await apiAction<PlanToday>("POST", "/api/whatnow/plan/today", { taskIds });
  if (result.ok) revalidatePath(ROUTES.PLAN);
  return result;
}

// ─────────────────────────────────────────────
// Linked Task Board — same whatnow_tasks data as PlanTask above (one source
// of truth shared with the Diary), extended with tags/urgency/importance/
// body/links. A distinct BoardTask type (not a PlanTask extension) so /plan's
// type doesn't widen with fields it never uses.
// ─────────────────────────────────────────────

export type LinkTargetType = "task" | "diary_entry" | "journal_entry" | "project";

export interface TaskLink {
  id: string;
  sourceTaskId: string;
  targetType: LinkTargetType;
  targetId: string;
  targetLabel: string;
}

export interface BoardTask {
  id: string;
  title: string;
  status: PlanTaskStatus;
  category?: string;
  tags?: string[];
  body?: string;
  urgency?: "urgent" | "not_urgent";
  importance?: "important" | "not_important";
  links?: TaskLink[];
}

export type TemplateFieldKind = "text" | "textarea";

export interface TemplateField {
  id: string;
  label: string;
  kind: TemplateFieldKind;
}

export interface TaskTemplate {
  id: string;
  name: string;
  fields: TemplateField[];
}

export async function getBoardAction(): Promise<ActionResult<{ tasks: BoardTask[] }>> {
  try {
    const board = await apiGet<{ tasks: BoardTask[] }>("/api/whatnow/board");
    return { ok: true, data: board };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not load the board." };
  }
}

export interface BoardTaskPatch {
  status?: PlanTaskStatus;
  category?: string;
  tags?: string[];
  body?: string;
  urgency?: "urgent" | "not_urgent" | "";
  importance?: "important" | "not_important" | "";
}

export async function patchBoardTaskAction(id: string, patch: BoardTaskPatch): Promise<ActionResult<BoardTask>> {
  const result = await apiAction<BoardTask>("PATCH", `/api/whatnow/tasks/${id}`, patch);
  if (result.ok) revalidatePath(ROUTES.BOARD);
  return result;
}

// Quick-add: same free-text capture as /now (deadline/duration/#category
// parsing included) — no separate create endpoint for plain board tasks.
export async function captureBoardTaskAction(raw: string): Promise<ActionResult<BoardTask>> {
  const result = await apiAction<BoardTask>("POST", "/api/whatnow/tasks", { raw });
  if (result.ok) revalidatePath(ROUTES.BOARD);
  return result;
}

export async function createLinkAction(
  taskId: string,
  targetType: LinkTargetType,
  targetId: string,
  targetLabel: string,
): Promise<ActionResult<TaskLink>> {
  const result = await apiAction<TaskLink>("POST", `/api/whatnow/tasks/${taskId}/links`, {
    targetType,
    targetId,
    targetLabel,
  });
  if (result.ok) revalidatePath(ROUTES.BOARD);
  return result;
}

export async function deleteLinkAction(linkId: string): Promise<ActionResult<undefined>> {
  const result = await apiAction<undefined>("DELETE", `/api/whatnow/links/${linkId}`);
  if (result.ok) revalidatePath(ROUTES.BOARD);
  return result;
}

export async function listTemplatesAction(): Promise<ActionResult<TaskTemplate[]>> {
  try {
    const templates = await apiGet<TaskTemplate[]>("/api/whatnow/templates");
    return { ok: true, data: templates };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Could not load templates." };
  }
}

export async function createTemplateAction(
  name: string,
  fields: { label: string; kind: TemplateFieldKind }[],
): Promise<ActionResult<TaskTemplate>> {
  const result = await apiAction<TaskTemplate>("POST", "/api/whatnow/templates", { name, fields });
  if (result.ok) revalidatePath(ROUTES.BOARD);
  return result;
}

export async function instantiateTemplateAction(
  templateId: string,
  values: Record<string, string>,
): Promise<ActionResult<BoardTask>> {
  const result = await apiAction<BoardTask>("POST", `/api/whatnow/templates/${templateId}/instantiate`, { values });
  if (result.ok) revalidatePath(ROUTES.BOARD);
  return result;
}

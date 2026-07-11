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

// Reorders (and/or grows) the planned queue. taskIds must include every
// currently-planned task's ID, not just the ones being reordered — the
// backend demotes any planned task omitted from this array back to inbox.
export async function reorderBacklogAction(taskIds: string[]): Promise<ActionResult<PlanToday>> {
  const result = await apiAction<PlanToday>("POST", "/api/whatnow/plan/today", { taskIds });
  if (result.ok) revalidatePath(ROUTES.PLAN);
  return result;
}

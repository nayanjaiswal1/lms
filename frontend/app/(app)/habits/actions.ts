"use server"

import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type { HabitColorValue } from "@/lib/constants"
import type { CustomField, Habit, HabitCadence, HabitType } from "@/lib/server/habits"

export async function createHabitAction(
  name: string,
  cadence: HabitCadence,
  targetCount?: number,
  weekdays?: number[],
  type?: HabitType,
  customFields?: CustomField[],
  icon?: string,
  tags?: string[],
): Promise<ActionResult<Habit>> {
  return apiAction<Habit>("POST", "/api/habits", {
    name,
    cadence,
    target_count: targetCount,
    weekdays,
    type,
    custom_fields: customFields,
    icon,
    tags,
  })
}

export async function deleteHabitAction(habitId: string): Promise<ActionResult<null>> {
  return apiAction<null>("DELETE", `/api/habits/${habitId}`)
}

export async function updateHabitColorAction(habitId: string, color: HabitColorValue): Promise<ActionResult<null>> {
  return apiAction<null>("PATCH", `/api/habits/${habitId}`, { color })
}

// Partial update — only the fields present in the body change; the color
// picker still calls updateHabitColorAction above for exactly that reason.
export async function updateHabitAppearanceAction(
  habitId: string,
  fields: { icon?: string; tags?: string[] },
): Promise<ActionResult<null>> {
  return apiAction<null>("PATCH", `/api/habits/${habitId}`, fields)
}

export async function setHabitCompletionAction(habitId: string, period: string): Promise<ActionResult<null>> {
  return apiAction<null>("PUT", `/api/habits/${habitId}/completions/${period}`)
}

export async function clearHabitCompletionAction(habitId: string, period: string): Promise<ActionResult<null>> {
  return apiAction<null>("DELETE", `/api/habits/${habitId}/completions/${period}`)
}

export async function updateHabitCompletionMetadataAction(
  habitId: string,
  period: string,
  metadata: Record<string, unknown>,
): Promise<ActionResult<null>> {
  return apiAction<null>("PUT", `/api/habits/${habitId}/completions/${period}/metadata`, { metadata })
}

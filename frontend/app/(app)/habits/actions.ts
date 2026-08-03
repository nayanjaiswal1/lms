"use server"

import { apiAction } from "@/lib/server/api"
import type { ActionResult } from "@/lib/server/api"
import type { HabitColorValue } from "@/lib/constants"
import type { Habit, HabitCadence } from "@/lib/server/habits"

export async function createHabitAction(
  name: string,
  cadence: HabitCadence,
  targetCount?: number,
  weekdays?: number[],
): Promise<ActionResult<Habit>> {
  return apiAction<Habit>("POST", "/api/habits", {
    name,
    cadence,
    target_count: targetCount,
    weekdays,
  })
}

export async function deleteHabitAction(habitId: string): Promise<ActionResult<null>> {
  return apiAction<null>("DELETE", `/api/habits/${habitId}`)
}

export async function updateHabitColorAction(habitId: string, color: HabitColorValue): Promise<ActionResult<null>> {
  return apiAction<null>("PATCH", `/api/habits/${habitId}`, { color })
}

export async function setHabitCompletionAction(habitId: string, period: string): Promise<ActionResult<null>> {
  return apiAction<null>("PUT", `/api/habits/${habitId}/completions/${period}`)
}

export async function clearHabitCompletionAction(habitId: string, period: string): Promise<ActionResult<null>> {
  return apiAction<null>("DELETE", `/api/habits/${habitId}/completions/${period}`)
}

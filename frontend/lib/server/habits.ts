import { apiGet } from "@/lib/server/api"
import type { HabitColorValue } from "@/lib/constants"

export type HabitCadence = "daily" | "weekly" | "monthly"

export interface Habit {
  id: string
  user_id: string
  name: string
  cadence: HabitCadence
  sort_order: number
  color: HabitColorValue
  // Weekly-only tracking mode, mutually exclusive: target_count > 1 means
  // "any N times a week" (weekdays empty); weekdays non-empty means
  // "specific weekdays" (target_count forced to 1). Daily/monthly habits
  // always carry target_count 1 and empty weekdays. Values in weekdays are
  // Sunday=0..Saturday=6, matching JS Date#getDay().
  target_count: number
  weekdays: number[]
  created_at: string
}

export interface HabitCompletion {
  habit_id: string
  period_start: string
  count: number
}

export interface HabitMonthView {
  habits: Habit[]
  completions: HabitCompletion[]
}

export async function getHabitMonth(month: string): Promise<HabitMonthView> {
  return apiGet<HabitMonthView>(`/api/habits?month=${month}`)
}

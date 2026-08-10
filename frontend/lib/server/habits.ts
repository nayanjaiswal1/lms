import { apiGet } from "@/lib/server/api"
import type { HabitColorValue } from "@/lib/constants"

export type HabitCadence = "daily" | "weekly" | "monthly"

export type HabitType = "generic" | "gym" | "sleep" | "reading" | "custom"

export interface CustomField {
  key: string
  label: string
  kind: "text" | "number" | "textarea"
}

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
  // Selects the dynamic entry form (if any) shown below the grid when this
  // habit is clicked — see lib/habits/type-schemas.ts. "custom" fields are
  // user-defined per habit; every other type's fields are fixed.
  type: HabitType
  custom_fields: CustomField[]
  // icon overrides the type/cadence default icon when set (one of
  // HABIT_ICONS in lib/habits/icons.ts); "" means no override. tags are
  // free-form user categories, used to filter the tracker.
  icon: string
  tags: string[]
  created_at: string
}

export interface HabitCompletion {
  habit_id: string
  period_start: string
  count: number
  metadata: Record<string, unknown>
}

export interface HabitMonthView {
  habits: Habit[]
  completions: HabitCompletion[]
}

export async function getHabitMonth(month: string): Promise<HabitMonthView> {
  return apiGet<HabitMonthView>(`/api/habits?month=${month}`)
}

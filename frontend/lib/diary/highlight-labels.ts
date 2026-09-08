import type { HighlightKind } from "@/lib/server/diary";

// Single source of truth for how each AI-detected highlight kind is labeled
// in the UI (editor <mark> tooltip and the analyze review panel) — "habit"
// and "goal" used to carry different English (Habit/Detected habit,
// New goal/🎯 New goal) between the two call sites, which is what made the
// diary page read as if habits and goals were two unrelated things. They
// aren't: a "goal" span creates a new habit; a "habit" span completes an
// existing one — both surface as "Goal" here, matching the diary page's
// Goals strip (see GoalStatus in internal/diary/models.go).
export const HIGHLIGHT_KIND_LABEL: Record<HighlightKind, string> = {
  habit: "Goal",
  task_done: "Task done",
  task_new: "New task",
  buy_new: "Buy list",
  goal: "🎯 New goal",
};

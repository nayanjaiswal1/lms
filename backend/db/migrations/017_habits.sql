-- ═════════════════════════════════════════════════════════════════════════
-- Migration 017 — habits
-- ═════════════════════════════════════════════════════════════════════════
-- Backs the Habit Tracker (internal/habit) — personal daily/weekly/monthly
-- habits with a check-off history. A single `period_start` date represents
-- "the day" for a daily habit, "the Monday of that ISO week" for weekly, and
-- "the 1st of the month" for monthly, so one completions table and one
-- range query serve all three cadences with no per-cadence branching.

CREATE TABLE public.habits (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name        text NOT NULL,
    cadence     text NOT NULL CHECK (cadence IN ('daily', 'weekly', 'monthly')),
    sort_order  integer NOT NULL DEFAULT 0,
    created_at  timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX idx_habits_user ON public.habits (user_id, sort_order);

-- Row presence = done for that period; no separate boolean or surrogate id.
-- habit_id join is also the ownership check, same as focus_wall_categories.
CREATE TABLE public.habit_completions (
    habit_id     uuid NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
    period_start date NOT NULL,
    created_at   timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (habit_id, period_start)
);

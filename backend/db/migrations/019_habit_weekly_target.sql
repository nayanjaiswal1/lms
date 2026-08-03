-- ═════════════════════════════════════════════════════════════════════════
-- Migration 019 — habit_weekly_target
-- ═════════════════════════════════════════════════════════════════════════
-- Lets a weekly habit be tracked in either of two modes, chosen per habit:
--   - "any N times a week": target_count > 1, weekdays empty. The weekly
--     wedge is checked off repeatedly (up to target_count) on whichever days
--     the user actually does it — habit_completions.count tracks progress
--     within that week's single period_start row.
--   - "specific weekdays": weekdays non-empty, target_count forced to 1. The
--     habit reuses the same per-day period_start granularity as a daily
--     habit, just restricted to the chosen weekdays (Sunday=0..Saturday=6,
--     matching Go's time.Weekday and JS's Date#getDay so no translation is
--     needed on either side).
-- Daily and monthly habits are unaffected: target_count stays 1 and weekdays
-- stays empty, so completion stays a plain presence check exactly as before.

ALTER TABLE public.habits
    ADD COLUMN target_count integer NOT NULL DEFAULT 1 CHECK (target_count BETWEEN 1 AND 7),
    ADD COLUMN weekdays integer[] NOT NULL DEFAULT '{}';

-- Row presence still means "at least started"; count tracks how many of
-- target_count check-ins have landed in that one period_start row.
ALTER TABLE public.habit_completions
    ADD COLUMN count integer NOT NULL DEFAULT 1 CHECK (count > 0);

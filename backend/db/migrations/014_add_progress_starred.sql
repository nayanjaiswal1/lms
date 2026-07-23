-- ═════════════════════════════════════════════════════════════════════════
-- Migration 014 — add_progress_starred
-- Per-user bookmark flag on a sheet item's progress row, independent of the
-- todo/done/revisit status cycle — lets a user flag problems to revisit
-- later without changing their solved state.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.user_problem_progress
    ADD COLUMN is_starred boolean DEFAULT false NOT NULL;

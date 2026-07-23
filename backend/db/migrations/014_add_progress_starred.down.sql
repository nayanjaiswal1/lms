-- ═════════════════════════════════════════════════════════════════════════
-- Migration 014 — add_progress_starred (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.user_problem_progress
    DROP COLUMN IF EXISTS is_starred;

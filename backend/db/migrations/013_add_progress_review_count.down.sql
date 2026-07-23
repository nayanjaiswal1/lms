-- ═════════════════════════════════════════════════════════════════════════
-- Migration 013 — add_progress_review_count (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.user_problem_progress
    DROP COLUMN IF EXISTS review_count;

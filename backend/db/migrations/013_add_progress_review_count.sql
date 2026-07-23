-- ═════════════════════════════════════════════════════════════════════════
-- Migration 013 — add_progress_review_count
-- Tracks how many times an item has been successfully re-reviewed (the
-- "Reviewed" action, distinct from the todo/done/revisit status cycle) so
-- the next revision_at can be computed from the sheet's growth scheme.
-- Resets to 0 whenever the item is freshly marked done or cleared to todo.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.user_problem_progress
    ADD COLUMN review_count integer DEFAULT 0 NOT NULL;

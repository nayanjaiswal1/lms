-- ═════════════════════════════════════════════════════════════════════════
-- Migration 011 — add_sheet_progress_notes (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.user_problem_progress
    DROP COLUMN IF EXISTS notes;

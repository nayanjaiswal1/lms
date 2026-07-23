-- ═════════════════════════════════════════════════════════════════════════
-- Migration 011 — add_sheet_progress_notes
-- Per-problem notes for the sheet tracker (cross-sheet, keyed by topic_tag
-- like the rest of user_problem_progress). Stored as TipTap JSON, same shape
-- as wiki_pages.content, so the frontend can reuse the TipTap editor stack.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.user_problem_progress
    ADD COLUMN notes jsonb DEFAULT '{}'::jsonb NOT NULL;

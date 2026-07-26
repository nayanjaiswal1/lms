-- ═════════════════════════════════════════════════════════════════════════
-- Migration 018 — add_highlight_notes
-- Personal note a user can attach to a highlight when saving it for revision.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.highlights
    ADD COLUMN note text;

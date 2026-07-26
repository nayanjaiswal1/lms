-- ═════════════════════════════════════════════════════════════════════════
-- Migration 018 — add_highlight_notes (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.highlights
    DROP COLUMN IF EXISTS note;

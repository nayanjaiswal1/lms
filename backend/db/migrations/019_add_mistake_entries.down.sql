-- ═════════════════════════════════════════════════════════════════════════
-- Migration 019 — add_mistake_entries (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.srs_cards
    DROP CONSTRAINT IF EXISTS srs_cards_mistake_entry_fk,
    DROP COLUMN IF EXISTS mistake_entry_id;

DROP TABLE IF EXISTS public.mistake_entries;

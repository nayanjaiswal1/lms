-- ═════════════════════════════════════════════════════════════════════════
-- Migration 012 — add_sheet_revision_settings (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.user_sheet_settings;

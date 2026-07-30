-- ═════════════════════════════════════════════════════════════════════════
-- Migration 020 — add_courses_tags_gin_index (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DROP INDEX IF EXISTS public.courses_tags_gin;

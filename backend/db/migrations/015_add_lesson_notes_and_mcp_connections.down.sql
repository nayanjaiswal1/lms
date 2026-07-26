-- ═════════════════════════════════════════════════════════════════════════
-- Migration 015 — add_lesson_notes_and_mcp_connections (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.mcp_auth_codes;
DROP TABLE IF EXISTS public.mcp_access_tokens;
DROP TABLE IF EXISTS public.mcp_connections;
DROP TABLE IF EXISTS public.mcp_clients;

ALTER TABLE public.lesson_reflections
    DROP CONSTRAINT IF EXISTS lesson_reflections_source_check,
    DROP COLUMN IF EXISTS source;

DROP TABLE IF EXISTS public.lesson_notes;

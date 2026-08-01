-- ═════════════════════════════════════════════════════════════════════════
-- Migration 007 — mentor_conversations (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.mentor_direct_messages;
DROP TABLE IF EXISTS public.mentor_conversations;

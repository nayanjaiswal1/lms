-- ═════════════════════════════════════════════════════════════════════════
-- Migration 004 — add_public_attempt_override (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.public_attempts
    DROP COLUMN IF EXISTS override_note,
    DROP COLUMN IF EXISTS overridden_by,
    DROP COLUMN IF EXISTS overridden_at;

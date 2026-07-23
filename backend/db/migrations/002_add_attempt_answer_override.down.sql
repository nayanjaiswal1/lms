-- ═════════════════════════════════════════════════════════════════════════
-- Migration 002 — add_attempt_answer_override (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.attempt_answers
    DROP COLUMN IF EXISTS override_note,
    DROP COLUMN IF EXISTS overridden_by,
    DROP COLUMN IF EXISTS overridden_at;

-- ═════════════════════════════════════════════════════════════════════════
-- Migration 004 — add_public_attempt_override
-- Mirrors 002_add_attempt_answer_override, but for no-auth hiring candidates
-- (public_attempts has no per-question attempt_answers row — a single
-- aggregate score is all there is to override here). Lets staff manually
-- adjust a candidate's total score during hiring review — e.g. docking or
-- crediting points beyond the auto-graded pass/fail.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.public_attempts
    ADD COLUMN override_note text,
    ADD COLUMN overridden_by uuid REFERENCES public.users(id),
    ADD COLUMN overridden_at timestamp with time zone;

-- ═════════════════════════════════════════════════════════════════════════
-- Migration 002 — add_attempt_answer_override
-- Lets staff (admin/instructor/mentor) manually override an auto-graded
-- answer's score during hiring-assessment review — e.g. spot-checking a
-- sandbox-graded FastAPI/React submission's code quality on top of its
-- pass/fail test result. See assessment.OverrideAnswerScore.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.attempt_answers
    ADD COLUMN override_note text,
    ADD COLUMN overridden_by uuid REFERENCES public.users(id),
    ADD COLUMN overridden_at timestamp with time zone;

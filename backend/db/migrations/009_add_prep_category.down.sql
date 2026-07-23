-- ═════════════════════════════════════════════════════════════════════════
-- Migration 009 — add_prep_category (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.interview_prep_rounds
    DROP CONSTRAINT interview_prep_rounds_round_type_check,
    ADD CONSTRAINT interview_prep_rounds_round_type_check CHECK (round_type IN ('conceptual', 'coding'));

ALTER TABLE public.interview_prep_plans
    DROP CONSTRAINT IF EXISTS interview_prep_plans_category_check,
    DROP COLUMN IF EXISTS category;

ALTER TABLE public.practice_sessions
    DROP CONSTRAINT IF EXISTS practice_sessions_category_check,
    DROP COLUMN IF EXISTS category;

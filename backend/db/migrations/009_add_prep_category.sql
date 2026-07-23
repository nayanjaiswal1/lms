-- ═════════════════════════════════════════════════════════════════════════
-- Migration 009 — add_prep_category
-- Widens Interview Prep beyond technical roles: a session/round/plan now
-- carries a category ('technical' | 'behavioral'). practice_sessions.category
-- drives which system prompt/rubric practice.Service uses for question
-- generation and answer grading; interview_prep_plans.category is set from
-- the (already-existing) JD-extraction call's new role_type field for
-- targeted plans, or chosen directly for quick plans. A non-technical
-- targeted plan gets exactly one behavioral round (no coding round) — see
-- internal/interviewprep.Service.createTargetedPlan.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.practice_sessions
    ADD COLUMN category text NOT NULL DEFAULT 'technical'
        CONSTRAINT practice_sessions_category_check CHECK (category IN ('technical', 'behavioral'));

ALTER TABLE public.interview_prep_plans
    ADD COLUMN category text NOT NULL DEFAULT 'technical'
        CONSTRAINT interview_prep_plans_category_check CHECK (category IN ('technical', 'behavioral'));

ALTER TABLE public.interview_prep_rounds
    DROP CONSTRAINT interview_prep_rounds_round_type_check,
    ADD CONSTRAINT interview_prep_rounds_round_type_check CHECK (round_type IN ('conceptual', 'behavioral', 'coding'));

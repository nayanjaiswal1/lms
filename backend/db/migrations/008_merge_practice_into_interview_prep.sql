-- ═════════════════════════════════════════════════════════════════════════
-- Migration 008 — merge_practice_into_interview_prep
-- Interview Prep's "conceptual round" has always delegated to a practice
-- session (interview_prep_rounds.practice_session_id). This migration makes
-- that the only path: interview_prep_plans becomes the single top-level
-- entity, with a plan_type distinguishing a lightweight "quick" practice
-- session (technology/difficulty, one round, no report) from a full
-- "targeted" mock test (JD-derived, conceptual + coding rounds, report).
-- Every existing standalone practice_sessions row (one with no plan wrapping
-- it yet) is backfilled into its own quick plan so no history is lost.
-- See internal/interviewprep.Service.CreatePlan.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.interview_prep_plans
    ADD COLUMN plan_type text NOT NULL DEFAULT 'targeted'
        CONSTRAINT interview_prep_plans_plan_type_check CHECK (plan_type IN ('quick', 'targeted')),
    ADD COLUMN technology text,
    ADD COLUMN difficulty text;

-- Backfill: every practice_sessions row not already wrapped by a plan
-- becomes its own quick plan with one conceptual round.
INSERT INTO public.interview_prep_plans
    (user_id, org_id, job_title, technology, difficulty, plan_type, status, ai_model, created_at, completed_at)
SELECT
    ps.user_id, ps.org_id, ps.technology, ps.technology, ps.difficulty, 'quick',
    CASE ps.status
        WHEN 'completed' THEN 'completed'
        WHEN 'abandoned' THEN 'failed'
        ELSE 'ready'
    END,
    ps.ai_model, ps.created_at, ps.completed_at
FROM public.practice_sessions ps
WHERE NOT EXISTS (
    SELECT 1 FROM public.interview_prep_rounds r WHERE r.practice_session_id = ps.id
);

-- One conceptual round per backfilled plan, pointing at the original session.
-- Safe to join on (user_id, technology, created_at) here only because this
-- runs once, immediately after the INSERT above, before any new plan can
-- collide on that triple.
INSERT INTO public.interview_prep_rounds (plan_id, round_type, order_index, practice_session_id, status)
SELECT
    p.id, 'conceptual', 0, ps.id,
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM public.practice_items i WHERE i.session_id = ps.id AND i.answered_at IS NULL
        ) THEN 'completed'
        ELSE 'active'
    END
FROM public.practice_sessions ps
JOIN public.interview_prep_plans p
    ON p.plan_type = 'quick'
   AND p.user_id = ps.user_id
   AND p.technology = ps.technology
   AND p.created_at = ps.created_at
WHERE NOT EXISTS (
    SELECT 1 FROM public.interview_prep_rounds r WHERE r.practice_session_id = ps.id
);

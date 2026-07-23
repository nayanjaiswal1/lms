-- ═════════════════════════════════════════════════════════════════════════
-- Migration 008 — merge_practice_into_interview_prep (rollback)
-- Structural rollback only — backfilled quick plans/rounds are not removed,
-- matching this repo's other down migrations.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.interview_prep_plans
    DROP CONSTRAINT IF EXISTS interview_prep_plans_plan_type_check,
    DROP COLUMN IF EXISTS plan_type,
    DROP COLUMN IF EXISTS technology,
    DROP COLUMN IF EXISTS difficulty;

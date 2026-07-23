-- ═════════════════════════════════════════════════════════════════════════
-- Migration 005 — add_cohort_groups (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.batches DROP COLUMN IF EXISTS cohort_group_id;
DROP TABLE IF EXISTS public.cohort_groups;

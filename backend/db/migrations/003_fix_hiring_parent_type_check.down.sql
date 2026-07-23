-- ═════════════════════════════════════════════════════════════════════════
-- Migration 003 — fix_hiring_parent_type_check (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.assessments DROP CONSTRAINT assessments_parent_type_check;
ALTER TABLE public.assessments ADD CONSTRAINT assessments_parent_type_check
    CHECK (parent_type = ANY (ARRAY['standalone'::text, 'course'::text, 'module'::text, 'roadmap'::text, 'batch'::text, 'bootcamp'::text]));

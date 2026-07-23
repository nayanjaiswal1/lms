-- ═════════════════════════════════════════════════════════════════════════
-- Migration 003 — fix_hiring_parent_type_check
-- assessment.ParentHiring = "hiring" (models.go), ValidParentTypes, and the
-- entire no-auth public-candidate flow (handler_public.go, routes.go) already
-- treat "hiring" as a real parent_type — but assessments_parent_type_check
-- was never updated to allow it, so every CreateAssessment with
-- parent_type="hiring" 500s on the DB CHECK violation. Pre-existing gap
-- between application code and schema; this closes it.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.assessments DROP CONSTRAINT assessments_parent_type_check;
ALTER TABLE public.assessments ADD CONSTRAINT assessments_parent_type_check
    CHECK (parent_type = ANY (ARRAY['standalone'::text, 'course'::text, 'module'::text, 'roadmap'::text, 'batch'::text, 'bootcamp'::text, 'hiring'::text]));

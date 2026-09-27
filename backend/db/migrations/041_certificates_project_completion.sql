-- ══════════════════════════════════════════════════════════════════════════
-- 041_certificates_project_completion.sql — Project Workspace, Phase 5
--
-- Additive: lets certificates.course_id go unset when a certificate is
-- instead issued for a completed Project Workspace project (project_id).
-- Never touches an existing course-issued row's shape.
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

ALTER TABLE public.certificates ALTER COLUMN course_id DROP NOT NULL;
ALTER TABLE public.certificates ADD COLUMN project_id uuid REFERENCES public.workspace_projects(id) ON DELETE CASCADE;
ALTER TABLE public.certificates ADD COLUMN note text CHECK (note IS NULL OR char_length(note) <= 2000);

ALTER TABLE public.certificates DROP CONSTRAINT certificates_issue_type_check;
ALTER TABLE public.certificates ADD CONSTRAINT certificates_issue_type_check
  CHECK (issue_type = ANY (ARRAY['final_test'::text, 'manual'::text, 'threshold'::text, 'project_completion'::text]));

ALTER TABLE public.certificates ADD CONSTRAINT certificates_course_xor_project
  CHECK ((course_id IS NOT NULL) <> (project_id IS NOT NULL));

CREATE UNIQUE INDEX uq_certificates_project_user ON public.certificates (project_id, user_id) WHERE project_id IS NOT NULL;
CREATE INDEX idx_certificates_project ON public.certificates (project_id) WHERE project_id IS NOT NULL;

SET LOCAL lock_timeout = '5s';

DROP INDEX IF EXISTS public.idx_certificates_project;
DROP INDEX IF EXISTS public.uq_certificates_project_user;
ALTER TABLE public.certificates DROP CONSTRAINT IF EXISTS certificates_course_xor_project;
ALTER TABLE public.certificates DROP CONSTRAINT IF EXISTS certificates_issue_type_check;
ALTER TABLE public.certificates ADD CONSTRAINT certificates_issue_type_check
  CHECK (issue_type = ANY (ARRAY['final_test'::text, 'manual'::text, 'threshold'::text]));
DELETE FROM public.certificates WHERE project_id IS NOT NULL;
ALTER TABLE public.certificates DROP COLUMN IF EXISTS note;
ALTER TABLE public.certificates DROP COLUMN IF EXISTS project_id;
ALTER TABLE public.certificates ALTER COLUMN course_id SET NOT NULL;

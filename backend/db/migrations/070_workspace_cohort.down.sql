DROP INDEX IF EXISTS public.workspace_projects_cohort_idx;
ALTER TABLE public.workspace_projects DROP COLUMN IF EXISTS cohort_id;

-- A workspace may belong to a cohort: a project_assignments row shared by
-- several workspaces' teams.
ALTER TABLE public.workspace_projects
    ADD COLUMN cohort_id uuid REFERENCES public.project_assignments(id) ON DELETE SET NULL;

CREATE INDEX workspace_projects_cohort_idx ON public.workspace_projects (cohort_id) WHERE cohort_id IS NOT NULL;

-- Legacy projectmarket jobs no longer have a handler.
DELETE FROM public.jobs WHERE handler LIKE 'projectmarket.%';

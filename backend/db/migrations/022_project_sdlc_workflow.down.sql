DROP TABLE IF EXISTS public.project_tasks;
DROP TABLE IF EXISTS public.project_design_votes;
DROP TABLE IF EXISTS public.project_design_proposals;
ALTER TABLE public.project_checkpoints DROP COLUMN IF EXISTS kind;

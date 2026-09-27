SET LOCAL lock_timeout = '5s';

DELETE FROM public.role_permissions
WHERE permission_id IN (SELECT id FROM public.permissions WHERE code IN ('projects.create', 'projects.oversee'));
DELETE FROM public.permissions WHERE code IN ('projects.create', 'projects.oversee');

DROP INDEX IF EXISTS public.uq_wiki_spaces_project;
ALTER TABLE public.wiki_spaces DROP COLUMN IF EXISTS project_id;

DROP TABLE IF EXISTS public.onboarding_progress;
DROP TABLE IF EXISTS public.onboarding_steps;
DROP TABLE IF EXISTS public.requirement_versions;
DROP TABLE IF EXISTS public.project_interests;
DROP TABLE IF EXISTS public.project_track_members;
DROP TABLE IF EXISTS public.project_tracks;
DROP TABLE IF EXISTS public.project_members;
DROP TABLE IF EXISTS public.workspace_projects;

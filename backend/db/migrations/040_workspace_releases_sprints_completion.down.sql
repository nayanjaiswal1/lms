SET LOCAL lock_timeout = '5s';

ALTER TABLE public.project_members DROP COLUMN IF EXISTS showcase_opt_in;
DROP TABLE IF EXISTS public.peer_feedback;

DROP INDEX IF EXISTS public.idx_work_items_sprint;
DROP INDEX IF EXISTS public.idx_work_items_release;
ALTER TABLE public.work_items
  DROP CONSTRAINT IF EXISTS work_items_sprint_fk,
  DROP CONSTRAINT IF EXISTS work_items_release_fk,
  DROP COLUMN IF EXISTS sprint_id,
  DROP COLUMN IF EXISTS release_id;

DROP TABLE IF EXISTS public.sprint_commitments;
DROP TABLE IF EXISTS public.sprints;
DROP TABLE IF EXISTS public.release_snapshots;
DROP TABLE IF EXISTS public.releases;

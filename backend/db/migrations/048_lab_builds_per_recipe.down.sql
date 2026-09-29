SET LOCAL lock_timeout = '5s';

ALTER TABLE public.lab_recipes DROP COLUMN IF EXISTS is_platform;
ALTER TABLE public.lab_task_versions DROP COLUMN IF EXISTS build_id;

DROP INDEX IF EXISTS public.lab_builds_recipe_idx;
DROP INDEX IF EXISTS public.lab_builds_gc_idx;
DROP INDEX IF EXISTS public.lab_builds_inflight_recipe_hash_idx;
DROP INDEX IF EXISTS public.lab_builds_verified_recipe_hash_idx;
CREATE UNIQUE INDEX lab_builds_verified_hash_idx ON public.lab_builds (recipe_hash) WHERE status = 'verified';

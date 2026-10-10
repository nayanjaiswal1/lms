-- 004_lab_builds_runtime_id.sql
-- A build's identity is (recipe, recipe_hash, runtime_id): runtime_id is the
-- content stamp of the lab image (grader + renderer bundle) it was built and
-- verified against. Builds made before this column keep '' (unknown runtime) so
-- they never match a live runtime and are re-verified on the next build request;
-- published labs are untouched. Idempotent.
ALTER TABLE public.lab_builds ADD COLUMN IF NOT EXISTS runtime_id text NOT NULL DEFAULT '';

DROP INDEX IF EXISTS public.lab_builds_inflight_recipe_hash_idx;
DROP INDEX IF EXISTS public.lab_builds_verified_recipe_hash_idx;
CREATE UNIQUE INDEX IF NOT EXISTS lab_builds_inflight_recipe_hash_runtime_idx
    ON public.lab_builds USING btree (recipe_id, recipe_hash, runtime_id)
    WHERE (status = ANY (ARRAY['queued'::text, 'rendering'::text, 'verifying'::text]));
CREATE UNIQUE INDEX IF NOT EXISTS lab_builds_verified_recipe_hash_runtime_idx
    ON public.lab_builds USING btree (recipe_id, recipe_hash, runtime_id)
    WHERE (status = 'verified'::text);

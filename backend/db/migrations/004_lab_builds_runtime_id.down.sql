-- Restores the runtime-blind unique indexes. Fails if a recipe now has several
-- verified/in-flight builds of one hash under different runtimes; remove the
-- older ones first.
DROP INDEX IF EXISTS public.lab_builds_inflight_recipe_hash_runtime_idx;
DROP INDEX IF EXISTS public.lab_builds_verified_recipe_hash_runtime_idx;
CREATE UNIQUE INDEX IF NOT EXISTS lab_builds_inflight_recipe_hash_idx
    ON public.lab_builds USING btree (recipe_id, recipe_hash)
    WHERE (status = ANY (ARRAY['queued'::text, 'rendering'::text, 'verifying'::text]));
CREATE UNIQUE INDEX IF NOT EXISTS lab_builds_verified_recipe_hash_idx
    ON public.lab_builds USING btree (recipe_id, recipe_hash)
    WHERE (status = 'verified'::text);
ALTER TABLE public.lab_builds DROP COLUMN IF EXISTS runtime_id;

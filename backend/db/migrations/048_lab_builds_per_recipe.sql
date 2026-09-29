-- ══════════════════════════════════════════════════════════════════════════
-- 048_lab_builds_per_recipe.sql — build pipeline (docs/debug-labs.md Phase 1c-ii)
--
-- A verified build is unique per (recipe, recipe_hash), not per recipe_hash
-- alone. Reusing another recipe's verified build for an identical composition
-- would hand one org a build row (report, variants) owned by another, so each
-- recipe verifies its own; the dedupe that matters (re-clicking Build on an
-- unchanged recipe) is preserved.
--
-- lab_task_versions.build_id ties a published task version to the build it was
-- cut from (docs/debug-labs.md B5), so a session pinned to a task version keeps
-- resolving ITS build's variants after the lab is republished from a newer build.
--
-- Also indexes the columns the unpublished-build GC (lab.build_gc) scans.
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

DROP INDEX IF EXISTS public.lab_builds_verified_hash_idx;
CREATE UNIQUE INDEX lab_builds_verified_recipe_hash_idx
  ON public.lab_builds (recipe_id, recipe_hash) WHERE status = 'verified';

-- One in-flight build per (recipe, hash): a double click enqueues once.
CREATE UNIQUE INDEX lab_builds_inflight_recipe_hash_idx
  ON public.lab_builds (recipe_id, recipe_hash) WHERE status IN ('queued', 'rendering', 'verifying');

CREATE INDEX lab_builds_gc_idx ON public.lab_builds (created_at) WHERE status IN ('failed', 'verified');
CREATE INDEX lab_builds_recipe_idx ON public.lab_builds (recipe_id, created_at DESC);

ALTER TABLE public.lab_task_versions ADD COLUMN build_id UUID REFERENCES public.lab_builds(id);

-- Platform recipes (content/ recipe.yaml, emitted by coursegen) are built and
-- auto-published by lab.platform_recipes_sync; instructor recipes never are.
ALTER TABLE public.lab_recipes ADD COLUMN is_platform BOOLEAN NOT NULL DEFAULT false;

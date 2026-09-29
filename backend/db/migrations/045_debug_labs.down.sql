SET LOCAL lock_timeout = '5s';

DROP INDEX IF EXISTS public.idx_lab_catalog_meta_filter;
DROP TABLE IF EXISTS public.lab_catalog_meta;

DROP TABLE IF EXISTS public.lab_ai_drafts;
DROP TABLE IF EXISTS public.lab_block_usages;
DROP TABLE IF EXISTS public.lab_build_variants;
ALTER TABLE public.lab_definitions DROP CONSTRAINT IF EXISTS lab_definitions_build_id_fkey;
DROP INDEX IF EXISTS public.lab_builds_verified_hash_idx;
DROP TABLE IF EXISTS public.lab_builds;
DROP TABLE IF EXISTS public.lab_recipes;
DROP TABLE IF EXISTS public.lab_block_versions;
DROP TABLE IF EXISTS public.lab_blocks;

ALTER TABLE public.lab_sessions DROP COLUMN IF EXISTS variant_key;

ALTER TABLE public.lab_ai_interactions DROP CONSTRAINT IF EXISTS lab_ai_interactions_interaction_type_check;
ALTER TABLE public.lab_ai_interactions ADD CONSTRAINT lab_ai_interactions_interaction_type_check
  CHECK (interaction_type = ANY (ARRAY['hint'::text, 'explain'::text, 'diagnose'::text, 'generate'::text]));

ALTER TABLE public.lab_task_version_items DROP COLUMN IF EXISTS grader;
ALTER TABLE public.lab_tasks DROP COLUMN IF EXISTS grader;

ALTER TABLE public.lab_definitions DROP COLUMN IF EXISTS build_id;

ALTER TABLE public.lab_definitions DROP CONSTRAINT IF EXISTS lab_definitions_lab_type_check;
ALTER TABLE public.lab_definitions ADD CONSTRAINT lab_definitions_lab_type_check
  CHECK (lab_type = ANY (ARRAY['terminal'::text, 'code'::text, 'playground'::text, 'guided'::text, 'sandbox'::text]));

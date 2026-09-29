-- ══════════════════════════════════════════════════════════════════════════
-- 045_debug_labs.sql — Generic pluggable lab-kind schema (Phase 1a), first
-- consumed by the "debug" lab kind (docs/debug-labs.md).
--
-- The platform will grow more than one composed lab kind ("debug" now,
-- "learn"/build-a-feature and others later), so the block/recipe/build/
-- variant tables are named generically (lab_blocks, lab_recipes, lab_builds,
-- lab_build_variants, lab_block_usages, lab_ai_drafts) rather than debug-
-- specific. Kind-specific content (for debug: root_cause_md, fix_diff,
-- rubric, hint_ladder, baseline_commit) lives in lab_build_variants.payload
-- JSONB instead of dedicated columns, so a new lab kind needs no migration
-- to add its own variant fields.
--
-- lab_type (lab_definitions.lab_type, this migration's CHECK) is the closed,
-- DB-enumerated RUNTIME/WORKSPACE shape — it drives container image/profile
-- selection and which frontend workspace component renders, both of which
-- are genuinely closed sets today. lab_kind (lab_recipes.lab_kind) is the
-- open-ended AUTHORING-PLUGIN identity the Go registry
-- (backend/internal/labkinds) resolves against — adding a new kind never
-- needs a migration. For v1 there is a 1:1 mapping (lab_kind='debug' always
-- runs lab_type='debug'), but they are independent dimensions on purpose: a
-- future lab_kind could reuse the 'debug' IDE workspace shape with different
-- composition rules, or a brand-new lab_type could exist with no composed
-- lab_kind behind it at all (hand-authored, as every non-debug lab is today).
--
-- Only truly closed value sets keep a DB CHECK: lab_type (workspace shape),
-- lab_builds.status (build lifecycle), grader (grading mechanism: script vs
-- writeup_review), difficulty (a fixed 4-level rubric). block kind, block
-- stack, and catalog stack/category are open-ended and validated by the Go
-- registry/constants instead, per the "no migration to add a kind" goal.
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

-- ── lab_type gains 'debug' (the first pluggable-kind-backed workspace shape) ─
ALTER TABLE public.lab_definitions DROP CONSTRAINT lab_definitions_lab_type_check;
ALTER TABLE public.lab_definitions ADD CONSTRAINT lab_definitions_lab_type_check
  CHECK (lab_type = ANY (ARRAY['terminal'::text, 'code'::text, 'playground'::text, 'guided'::text, 'sandbox'::text, 'debug'::text]));

-- lab_definitions.build_id: which lab_builds row (if any) this lab's content
-- was published from. NULL for every hand-authored lab (the overwhelming
-- majority today) — only kind-driven labs (built through the Part 2 builder,
-- not yet shipped) set this.
ALTER TABLE public.lab_definitions ADD COLUMN build_id UUID;

-- ── lab_tasks / lab_task_version_items gain `grader` ───────────────────────
-- 'script' (default) dispatches through the existing verification_script
-- exec path (every lab type today, and a kind-driven lab's exec-graded
-- tasks, where verification_script holds a grader-mode keyword instead of an
-- actual script). 'writeup_review' tasks are never run through
-- VerifyTask/SubmitAll — only through POST .../writeup-review.
ALTER TABLE public.lab_tasks
  ADD COLUMN grader TEXT NOT NULL DEFAULT 'script' CHECK (grader IN ('script', 'writeup_review'));
ALTER TABLE public.lab_task_version_items
  ADD COLUMN grader TEXT NOT NULL DEFAULT 'script' CHECK (grader IN ('script', 'writeup_review'));

-- ── lab_ai_interactions interaction_type gains 'writeup_review' ────────────
ALTER TABLE public.lab_ai_interactions DROP CONSTRAINT lab_ai_interactions_interaction_type_check;
ALTER TABLE public.lab_ai_interactions ADD CONSTRAINT lab_ai_interactions_interaction_type_check
  CHECK (interaction_type = ANY (ARRAY['hint'::text, 'explain'::text, 'diagnose'::text, 'generate'::text, 'writeup_review'::text]));

-- ── lab_sessions gains variant_key ──────────────────────────────────────────
-- Chosen at session start (hash(user_id, lab_id) % N over the build's
-- verified variants) and pinned for the life of the session — retries,
-- hints, and the debrief all read against the same variant the student
-- started with. Generic across every lab kind.
ALTER TABLE public.lab_sessions ADD COLUMN variant_key TEXT;

-- ══════════════════════════════════════════════════════════════════════════
-- Generic composition/builder tables — schema only; the builder job/UI ships
-- in a later phase. Named generically so a second lab kind never needs a
-- table rename.
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE public.lab_blocks (
  id          UUID PRIMARY KEY,
  org_id      UUID REFERENCES public.organizations(id), -- NULL = platform-shipped
  block_key   TEXT NOT NULL,
  -- kind: 'app' | 'fault' | 'data' | 'stub' | 'env' | 'check' | 'ticket' |
  -- 'hints' | 'rubric' | 'custom' today (docs/debug-labs.md Part 2 §B1) —
  -- validated by the Go registry (backend/internal/labkinds), not a DB CHECK,
  -- so a lab kind can introduce new block kinds without a migration.
  kind        TEXT NOT NULL,
  -- stack: open-ended (django/fastapi/react/fullstack/any today, more will
  -- be added as lab kinds grow) — validated by Go constants, not a DB CHECK.
  stack       TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT (org_id, block_key)
);

CREATE TABLE public.lab_block_versions ( -- immutable
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id      UUID NOT NULL REFERENCES public.lab_blocks(id) ON DELETE CASCADE,
  version       TEXT NOT NULL,
  content_hash  TEXT NOT NULL,
  manifest      JSONB NOT NULL,
  -- Block payload (tar.gz) lives in the private bundle store, content-
  -- addressed as lab-bundles/<sha256>.tar.gz; NULL for text-only blocks.
  payload_key     TEXT,
  payload_sha256  TEXT,
  changelog     TEXT,
  yanked_at     TIMESTAMPTZ,
  yanked_reason TEXT,
  created_by    UUID REFERENCES public.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (block_id, version),
  UNIQUE (block_id, content_hash)
);

CREATE TABLE public.lab_recipes (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id            UUID NOT NULL REFERENCES public.organizations(id),
  owner_id          UUID NOT NULL REFERENCES public.users(id),
  -- lab_kind: the authoring-plugin identity the Go registry resolves against
  -- (e.g. 'debug') — see this file's header comment for how this differs
  -- from lab_definitions.lab_type. Not a DB CHECK: adding a kind must never
  -- need a migration.
  lab_kind          TEXT NOT NULL,
  title             TEXT NOT NULL,
  spec              JSONB NOT NULL, -- [{block_version_id, params, role}], variant axes, overrides
  revision          INT NOT NULL DEFAULT 1,
  lab_id            UUID REFERENCES public.lab_definitions(id),
  -- target_placement (docs/debug-labs.md Part 3 L5): {course_id, section_id,
  -- position} captured when a recipe is started from "Create debug lab here"
  -- so the eventual publish step can pre-fill and run library.Attach in the
  -- same transaction.
  target_placement  JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.lab_builds (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id           UUID NOT NULL REFERENCES public.lab_recipes(id) ON DELETE CASCADE,
  recipe_hash         TEXT NOT NULL,
  spec_snapshot       JSONB NOT NULL,
  -- status is a closed build-lifecycle enum, the same for every lab kind.
  status              TEXT NOT NULL CHECK (status IN ('queued', 'rendering', 'verifying', 'verified', 'failed')),
  job_id              UUID,
  report              JSONB,
  derived_difficulty  TEXT,
  created_by          UUID NOT NULL REFERENCES public.users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at         TIMESTAMPTZ
);
CREATE UNIQUE INDEX lab_builds_verified_hash_idx ON public.lab_builds (recipe_hash) WHERE status = 'verified';

ALTER TABLE public.lab_definitions
  ADD CONSTRAINT lab_definitions_build_id_fkey FOREIGN KEY (build_id) REFERENCES public.lab_builds(id);

CREATE TABLE public.lab_build_variants ( -- immutable; what sessions run
  build_id            UUID NOT NULL REFERENCES public.lab_builds(id) ON DELETE CASCADE,
  variant_key         TEXT NOT NULL,
  -- Generic fields every lab kind needs:
  -- Bundles live in the PRIVATE object store (storage.PrivateStore), never
  -- in the DB and never in the public-read bucket: content-addressed keys
  -- lab-bundles/<sha256>.tar.gz, written before this row commits, immutable.
  -- The sha256 is re-verified on every download.
  workspace_bundle_key     TEXT NOT NULL,
  workspace_bundle_sha256  TEXT NOT NULL,
  grader_bundle_key        TEXT NOT NULL,
  grader_bundle_sha256     TEXT NOT NULL,
  brief_md            TEXT NOT NULL,
  protected_manifest  JSONB NOT NULL,
  app_ports           INT[] NOT NULL,
  ide_port            INT NOT NULL DEFAULT 3000,
  -- payload: kind-specific artifact fields. For lab_kind='debug':
  -- {root_cause_md, fix_diff, rubric, hint_ladder, baseline_commit}. A new
  -- lab kind defines its own payload shape without a migration.
  payload             JSONB NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (build_id, variant_key)
);

CREATE TABLE public.lab_block_usages (
  build_id          UUID NOT NULL REFERENCES public.lab_builds(id) ON DELETE CASCADE,
  block_version_id  UUID NOT NULL REFERENCES public.lab_block_versions(id),
  PRIMARY KEY (build_id, block_version_id)
);

CREATE TABLE public.lab_ai_drafts (
  cache_key    TEXT PRIMARY KEY,
  org_id       UUID NOT NULL REFERENCES public.organizations(id),
  kind         TEXT NOT NULL,
  prompt       TEXT NOT NULL,
  response     TEXT NOT NULL,
  tokens_used  INT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── lab_catalog_meta: generic catalog/filter tags for ANY lab type ─────────
-- Not tied to lab_builds/lab_kind — a hand-authored lab can carry these tags
-- too. Used by GET /api/labs/catalog and the library's stack/category/
-- difficulty filters (docs/debug-labs.md Part 3's L4 deviation note).
CREATE TABLE public.lab_catalog_meta (
  lab_id      UUID PRIMARY KEY REFERENCES public.lab_definitions(id) ON DELETE CASCADE,
  -- stack/category are open-ended (grow with content, not a fixed platform
  -- concept) — validated by Go constants, not a DB CHECK.
  stack       TEXT NOT NULL,
  category    TEXT NOT NULL,
  -- difficulty is a closed, fixed 4-level rubric shared across the whole
  -- platform (courses, sheets, labs) — worth a real CHECK.
  difficulty  TEXT NOT NULL CHECK (difficulty IN ('beginner', 'intermediate', 'advanced', 'expert')),
  skills      TEXT[] NOT NULL DEFAULT '{}'
);
CREATE INDEX idx_lab_catalog_meta_filter ON public.lab_catalog_meta (stack, category, difficulty);

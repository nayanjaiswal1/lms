-- ══════════════════════════════════════════════════════════════════════════
-- 005_phase2_structural.sql — Phase 2 structural fixes (#27, #5, #4, #8)
--
-- SCHEMA_REVIEW.md / REMAINING_PHASES.md Phase 2, bundled into one migration
-- per plan decision. Sections applied in risk order (lowest risk first).
-- ══════════════════════════════════════════════════════════════════════════


-- ── Section A — Issue #27: email columns → citext ──────────────────────────
-- Pure DB-side; citext already used for users.email in 001_baseline.sql.
-- No Go change needed (citext round-trips as text over the wire).

CREATE EXTENSION IF NOT EXISTS citext;

ALTER TABLE public.batch_invitations
    ALTER COLUMN email TYPE citext USING LOWER(email);

ALTER TABLE public.batch_member_details
    ALTER COLUMN email TYPE citext USING LOWER(email);

ALTER TABLE public.org_invites
    ALTER COLUMN email TYPE citext USING LOWER(email);

ALTER TABLE public.calendar_event_invites
    ALTER COLUMN email TYPE citext USING LOWER(email);

ALTER TABLE public.public_attempts
    ALTER COLUMN email TYPE citext USING LOWER(email);


-- ── Section B — Issue #5: lab task versioning integrity ────────────────────
-- lab_task_completions.task_id today points at the mutable lab_tasks table
-- with no FK at all, so a completion can silently reference a task that was
-- since edited or deleted, and no longer matches what the student actually
-- saw (lab_task_versions.tasks is the frozen jsonb snapshot of record).
--
-- lab_task_version_items gets its own surrogate id rather than reusing the
-- task's embedded snapshot id as the primary key: task ids are generated
-- deterministically per task (canonical.ID) and stay identical across
-- multiple published versions of the same lab when a task is unchanged, so
-- the embedded id is only unique per (task_version_id), not globally.
-- source_task_id keeps that original id around for the completions backfill
-- join below.
--
-- lab_tasks itself is left in place — it's still the mutable authoring copy
-- written by the seed generator and the (not-yet-built) instructor editor;
-- only the completions FK integrity is fixed here.

CREATE TABLE public.lab_task_version_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_version_id uuid NOT NULL,
    source_task_id uuid NOT NULL,
    "position" integer NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    verification_script text NOT NULL,
    hint_context text,
    explanation_context text,
    points integer NOT NULL,
    is_optional boolean NOT NULL,
    is_stateful boolean NOT NULL,
    CONSTRAINT lab_task_version_items_pkey PRIMARY KEY (id),
    CONSTRAINT lab_task_version_items_task_version_id_fkey
        FOREIGN KEY (task_version_id) REFERENCES public.lab_task_versions(id) ON DELETE CASCADE,
    CONSTRAINT lab_task_version_items_task_version_id_position_key
        UNIQUE (task_version_id, "position"),
    CONSTRAINT lab_task_version_items_task_version_id_source_task_id_key
        UNIQUE (task_version_id, source_task_id)
);

INSERT INTO public.lab_task_version_items
    (task_version_id, source_task_id, "position", title, description,
     verification_script, hint_context, explanation_context, points,
     is_optional, is_stateful)
SELECT
    ltv.id,
    (elem->>'id')::uuid,
    (elem->>'position')::int,
    elem->>'title',
    elem->>'description',
    elem->>'verification_script',
    elem->>'hint_context',
    elem->>'explanation_context',
    (elem->>'points')::int,
    (elem->>'is_optional')::boolean,
    (elem->>'is_stateful')::boolean
FROM public.lab_task_versions ltv,
     jsonb_array_elements(ltv.tasks) AS elem;

ALTER TABLE public.lab_task_completions
    ADD COLUMN task_version_item_id uuid;

UPDATE public.lab_task_completions ltc
SET task_version_item_id = ltvi.id
FROM public.lab_sessions ls
JOIN public.lab_task_version_items ltvi
    ON ltvi.task_version_id = ls.task_version_id
WHERE ltc.session_id = ls.id
  AND ltvi.source_task_id = ltc.task_id;

ALTER TABLE public.lab_task_completions
    DROP CONSTRAINT lab_task_completions_session_id_task_id_key;

ALTER TABLE public.lab_task_completions
    DROP COLUMN task_id;

ALTER TABLE public.lab_task_completions
    ALTER COLUMN task_version_item_id SET NOT NULL;

ALTER TABLE public.lab_task_completions
    ADD CONSTRAINT lab_task_completions_task_version_item_id_fkey
    FOREIGN KEY (task_version_item_id) REFERENCES public.lab_task_version_items(id) ON DELETE CASCADE;

ALTER TABLE public.lab_task_completions
    ADD CONSTRAINT lab_task_completions_session_id_task_version_item_id_key
    UNIQUE (session_id, task_version_item_id);

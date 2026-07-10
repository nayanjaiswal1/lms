-- ══════════════════════════════════════════════════════════════════════════
-- 005_phase2_structural.down.sql — revert Phase 2 structural fixes
-- Sections reverted in reverse order (D, C, B, A).
-- ══════════════════════════════════════════════════════════════════════════


-- ── Revert Section B — lab_task_version_items / lab_task_completions ───────

ALTER TABLE public.lab_task_completions
    ADD COLUMN task_id uuid;

UPDATE public.lab_task_completions ltc
SET task_id = ltvi.source_task_id
FROM public.lab_task_version_items ltvi
WHERE ltvi.id = ltc.task_version_item_id;

ALTER TABLE public.lab_task_completions
    ALTER COLUMN task_id SET NOT NULL;

ALTER TABLE public.lab_task_completions
    DROP CONSTRAINT lab_task_completions_session_id_task_version_item_id_key;

ALTER TABLE public.lab_task_completions
    DROP CONSTRAINT lab_task_completions_task_version_item_id_fkey;

ALTER TABLE public.lab_task_completions
    DROP COLUMN task_version_item_id;

ALTER TABLE public.lab_task_completions
    ADD CONSTRAINT lab_task_completions_session_id_task_id_key UNIQUE (session_id, task_id);

DROP TABLE public.lab_task_version_items;


-- ── Revert Section A — email columns back to text ──────────────────────────

ALTER TABLE public.batch_invitations
    ALTER COLUMN email TYPE text;

ALTER TABLE public.batch_member_details
    ALTER COLUMN email TYPE text;

ALTER TABLE public.org_invites
    ALTER COLUMN email TYPE text;

ALTER TABLE public.calendar_event_invites
    ALTER COLUMN email TYPE text;

ALTER TABLE public.public_attempts
    ALTER COLUMN email TYPE text;

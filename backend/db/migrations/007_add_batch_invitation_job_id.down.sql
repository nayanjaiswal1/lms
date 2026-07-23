-- ═════════════════════════════════════════════════════════════════════════
-- Migration 007 — add_batch_invitation_job_id (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DROP INDEX IF EXISTS idx_batch_invitations_import_job_id;

ALTER TABLE public.batch_invitations
    DROP COLUMN IF EXISTS import_job_id;

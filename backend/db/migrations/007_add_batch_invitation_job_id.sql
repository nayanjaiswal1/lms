-- ═════════════════════════════════════════════════════════════════════════
-- Migration 007 — add_batch_invitation_job_id
-- Tracks which batch_import job created/last-refreshed each invitation, so
-- the invite history UI can group invites sent together (a bulk Excel
-- import, or a single "invite new" from Add People — both run through the
-- same batch_import job) into one unit instead of a flat, indistinguishable
-- row-per-email list. See assessment.Repo.CreateBatchInvitations.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.batch_invitations
    ADD COLUMN import_job_id uuid REFERENCES public.jobs(id) ON DELETE SET NULL;

CREATE INDEX idx_batch_invitations_import_job_id ON public.batch_invitations (import_job_id);

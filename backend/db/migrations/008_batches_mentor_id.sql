-- ══════════════════════════════════════════════════════════════════════════
-- 008_batches_mentor_id.sql
-- batches.mentor_id: internal/assessment/repo_batch.go's CreateBatch,
-- UpdateBatch, ListBatches, ListBatchesForUser, and GetBatch have referenced
-- this column since they were written, but no migration ever added it —
-- every one of those queries has been failing at the DB with "column
-- mentor_id does not exist" (found via a real DB-backed test run against
-- internal/testdb, not previously exercised). Nullable + ON DELETE SET NULL,
-- matching audit_logs.actor_user_id's convention for an optional user
-- reference: removing the mentor's account shouldn't delete the batch or its
-- members/messages.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.batches
    ADD COLUMN mentor_id uuid,
    ADD CONSTRAINT batches_mentor_id_fkey FOREIGN KEY (mentor_id) REFERENCES public.users(id) ON DELETE SET NULL;

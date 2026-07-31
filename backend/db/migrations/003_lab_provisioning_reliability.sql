-- ═════════════════════════════════════════════════════════════════════════
-- Migration 003 — lab_provisioning_reliability
-- ═════════════════════════════════════════════════════════════════════════
-- A session's provisionContainer runs as a fire-and-forget goroutine
-- (labs.Service.provisionContainer) — if the backend process restarts while
-- a session is mid-provisioning, that goroutine and its ProvisionTimeoutSeconds
-- context timeout die with it, and the DB row is left in 'provisioning'
-- forever. lab_sessions_one_active only excludes terminal statuses, so an
-- orphaned 'provisioning' row permanently blocks that user from starting any
-- other lab. lab.expire_sessions (backend/internal/jobs/handlers/labs.go)
-- is extended in this change to reap these; provision_error gives it (and
-- the immediate-failure path in provisionContainer) somewhere to persist
-- *why*, instead of the reason only ever reaching slog.

ALTER TABLE lab_sessions ADD COLUMN provision_error TEXT;

ALTER TABLE lab_sessions DROP CONSTRAINT lab_sessions_end_reason_check;
ALTER TABLE lab_sessions ADD CONSTRAINT lab_sessions_end_reason_check
    CHECK (end_reason = ANY (ARRAY['time_limit', 'idle_timeout', 'provision_timeout', 'provision_failed']));

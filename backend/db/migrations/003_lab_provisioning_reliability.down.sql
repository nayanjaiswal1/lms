-- ═════════════════════════════════════════════════════════════════════════
-- Migration 003 — lab_provisioning_reliability (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE lab_sessions DROP CONSTRAINT lab_sessions_end_reason_check;
ALTER TABLE lab_sessions ADD CONSTRAINT lab_sessions_end_reason_check
    CHECK (end_reason = ANY (ARRAY['time_limit', 'idle_timeout']));

ALTER TABLE lab_sessions DROP COLUMN provision_error;

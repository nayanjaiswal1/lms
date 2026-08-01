-- Reverse of 011_lab_hardening_and_usage.sql.

DROP INDEX IF EXISTS lab_usage_events_org_type_recorded_idx;
DROP INDEX IF EXISTS lab_usage_events_session_id_idx;
DROP INDEX IF EXISTS lab_usage_events_container_seconds_uq;

ALTER TABLE lab_sessions DROP CONSTRAINT lab_sessions_end_reason_check;
ALTER TABLE lab_sessions ADD CONSTRAINT lab_sessions_end_reason_check
    CHECK (end_reason = ANY (ARRAY[
        'time_limit',
        'idle_timeout',
        'provision_timeout',
        'provision_failed'
    ]));

ALTER TABLE lab_sessions DROP COLUMN paused_at;

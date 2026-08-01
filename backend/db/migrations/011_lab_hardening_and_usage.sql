-- ═════════════════════════════════════════════════════════════════════════
-- Migration 011 — lab hardening + usage metering
-- ═════════════════════════════════════════════════════════════════════════
-- Schema half of the labs correctness/security pass:
--
--  1. paused_at — idle-pause is now actually implemented (lab.expire_sessions
--     pauses an idle container instead of destroying the student's work).
--     paused_seconds is a cumulative counter, so the moment the pause STARTED
--     has to be persisted somewhere for the resume path to know how much to
--     add. Without this column paused_seconds can only ever stay 0, which is
--     exactly the state the column was in before this change.
--
--  2. end_reason — a normal user-driven end/completion intentionally keeps
--     this NULL (see lab_sessions.EndReason's own doc comment); the one gap
--     is a staged reset whose replacement container never comes up — that IS
--     a system-driven termination worth recording, so it gets a reason.
--
--  3. lab_usage_events — the table existed with no writer and no reader.
--     Metering now records one container_seconds row per session at close.
--     The partial UNIQUE index makes that write idempotent: the reaper is a
--     retrying cron job, and a retried batch must not double-bill an org.
--     The session_id index backs the by-course / by-student reports, which
--     join usage back through lab_sessions -> lab_definitions.

-- ── 1. Idle-pause bookkeeping ────────────────────────────────────────────
ALTER TABLE lab_sessions ADD COLUMN paused_at TIMESTAMPTZ;

COMMENT ON COLUMN lab_sessions.paused_at IS
    'When the current pause began; NULL whenever status <> ''paused''. Resume adds now() - paused_at into paused_seconds and clears this.';

-- ── 2. End reason for a failed staged reset ──────────────────────────────
ALTER TABLE lab_sessions DROP CONSTRAINT lab_sessions_end_reason_check;
ALTER TABLE lab_sessions ADD CONSTRAINT lab_sessions_end_reason_check
    CHECK (end_reason = ANY (ARRAY[
        'time_limit',
        'idle_timeout',
        'provision_timeout',
        'provision_failed',
        'reset_failed'
    ]));

-- ── 3. Usage metering ────────────────────────────────────────────────────
-- One container_seconds row per session, ever. ON CONFLICT DO NOTHING against
-- this index is what makes the reaper's at-least-once delivery safe to bill.
CREATE UNIQUE INDEX lab_usage_events_container_seconds_uq
    ON lab_usage_events (session_id)
    WHERE event_type = 'container_seconds' AND session_id IS NOT NULL;

-- Backs the by-course / by-student rollups, which start from lab_usage_events
-- and join outward through session_id.
CREATE INDEX lab_usage_events_session_id_idx
    ON lab_usage_events (session_id)
    WHERE session_id IS NOT NULL;

-- The by-org report filters on (org_id, event_type, recorded_at); the existing
-- lab_usage_events_org_id_recorded_at_idx can't skip event types cheaply once
-- ai_tokens rows share the table.
CREATE INDEX lab_usage_events_org_type_recorded_idx
    ON lab_usage_events (org_id, event_type, recorded_at DESC);

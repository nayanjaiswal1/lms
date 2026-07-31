-- ═════════════════════════════════════════════════════════════════════════
-- Migration 002 — add_calendar_event_priority
-- ═════════════════════════════════════════════════════════════════════════
-- Prioritization for time-blocked tasks (event_type='task'). Nullable and
-- unchecked against event_type at the DB layer (mirrors how completed_at is
-- meaningful only for tasks but not constrained to them) — enforcement lives
-- in calendar.Service.normalizeAndValidateEvent instead.

ALTER TABLE calendar_events
    ADD COLUMN priority TEXT
        CHECK (priority IS NULL OR priority IN ('low', 'medium', 'high', 'urgent'));

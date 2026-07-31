-- ═════════════════════════════════════════════════════════════════════════
-- Migration 002 — add_calendar_event_priority (rollback)
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE calendar_events DROP COLUMN priority;

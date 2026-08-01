-- ═════════════════════════════════════════════════════════════════════════
-- Migration 012 — users_last_active_at
-- ═════════════════════════════════════════════════════════════════════════
-- The mentor profile page shows "last active" for a mentor, and there was no
-- user-level presence signal anywhere in the schema to back it (lab_sessions
-- has its own last_active_at, but that's an idle-timeout heartbeat scoped to
-- one lab session, not a general "when did this user last use the app").
--
-- Nullable: never touched means the column stays NULL rather than lying with
-- a fabricated timestamp — RequireAuth (internal/middleware/auth.go) sets it
-- on the user's first authenticated request after this migration runs.

ALTER TABLE public.users ADD COLUMN last_active_at timestamp with time zone;

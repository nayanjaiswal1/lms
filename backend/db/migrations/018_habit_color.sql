-- ═════════════════════════════════════════════════════════════════════════
-- Migration 018 — habit_color
-- ═════════════════════════════════════════════════════════════════════════
-- Lets each habit render as a distinct color across the daily wheel, weekly
-- table, and monthly checklist. Fixed 8-hue set (not free-form hex) so every
-- value stays inside the CVD-safe categorical palette already validated for
-- charts elsewhere in the app.

ALTER TABLE public.habits
    ADD COLUMN color text NOT NULL DEFAULT 'blue'
    CHECK (color IN ('blue', 'orange', 'aqua', 'yellow', 'magenta', 'green', 'violet', 'red'));

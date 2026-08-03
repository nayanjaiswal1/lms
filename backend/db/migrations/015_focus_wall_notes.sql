-- ═════════════════════════════════════════════════════════════════════════
-- Migration 015 — focus_wall_notes
-- ═════════════════════════════════════════════════════════════════════════
-- Backs the Focus Wall (internal/focuswall) — a personal sticky-note corkboard
-- for study reminders/todos, freely positioned and rotated by the user rather
-- than tied to a grid.

CREATE TABLE public.focus_wall_notes (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    text          text NOT NULL,
    color         text NOT NULL DEFAULT 'yellow' CHECK (color IN ('yellow', 'blue', 'pink', 'green')),
    category      text NOT NULL DEFAULT 'personal' CHECK (category IN ('personal', 'study', 'urgent')),
    position_x    double precision NOT NULL DEFAULT 0,
    position_y    double precision NOT NULL DEFAULT 0,
    rotation      double precision NOT NULL DEFAULT 0,
    created_at    timestamp with time zone NOT NULL DEFAULT now(),
    updated_at    timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX idx_focus_wall_notes_user ON public.focus_wall_notes (user_id, created_at);

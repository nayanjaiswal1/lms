-- ═════════════════════════════════════════════════════════════════════════
-- Migration 016 — focus_wall_categories
-- ═════════════════════════════════════════════════════════════════════════
-- Lets a user add their own Focus Wall categories beyond the three built-ins
-- (personal/study/urgent). Built-ins stay hardcoded in the Go service layer
-- (no seed rows here) — a category is now valid if it's one of those three
-- OR an existing row in this table for that user, checked in the service
-- instead of a fixed CHECK constraint.

CREATE TABLE public.focus_wall_categories (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name       text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    UNIQUE (user_id, name)
);

CREATE INDEX idx_focus_wall_categories_user ON public.focus_wall_categories (user_id, created_at);

ALTER TABLE public.focus_wall_notes DROP CONSTRAINT focus_wall_notes_category_check;

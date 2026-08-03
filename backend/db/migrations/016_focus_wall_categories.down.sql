-- Rolling back assumes no note has been given a custom category name in the
-- meantime — re-adding the CHECK constraint fails otherwise.
ALTER TABLE public.focus_wall_notes ADD CONSTRAINT focus_wall_notes_category_check
    CHECK (category IN ('personal', 'study', 'urgent'));

DROP TABLE public.focus_wall_categories;

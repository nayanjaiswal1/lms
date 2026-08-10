-- ══════════════════════════════════════════════════════════════════════════
-- 011_habit_tags_icon.sql
-- habits.tags: free-form user categories, filterable via chips in the UI.
-- habits.icon: an optional override of the type-based default icon, picked
-- from a curated lucide-react set (kept in sync with frontend/lib/habits/
-- icons.ts) — '' means "no override, fall back to the type/cadence icon".
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.habits
    ADD COLUMN tags text[] NOT NULL DEFAULT '{}'::text[],
    ADD COLUMN icon text NOT NULL DEFAULT '',
    ADD CONSTRAINT habits_icon_check
        CHECK (icon = ANY (ARRAY[
            ''::text, 'dumbbell'::text, 'moon'::text, 'book-open'::text, 'brain'::text,
            'droplet'::text, 'utensils'::text, 'flower'::text, 'footprints'::text,
            'phone-off'::text, 'heart'::text, 'music'::text, 'palette'::text, 'code'::text,
            'piggy-bank'::text, 'leaf'::text, 'sun'::text, 'coffee'::text, 'pen-tool'::text,
            'target'::text, 'users'::text, 'briefcase'::text, 'graduation-cap'::text,
            'bike'::text, 'smile'::text
        ]));

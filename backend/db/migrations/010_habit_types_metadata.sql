-- ══════════════════════════════════════════════════════════════════════════
-- 010_habit_types_metadata.sql
-- habits.type + habits.custom_fields: a habit can now declare a domain
-- (gym/sleep/reading) or a user-defined "custom" field set, driving a
-- dynamic entry form in the UI. habit_completions.metadata stores that
-- day's structured entry (flat key/value map, keys validated server-side
-- against the habit's type/custom_fields — see internal/habit/service.go).
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.habits
    ADD COLUMN type text NOT NULL DEFAULT 'generic',
    ADD COLUMN custom_fields jsonb NOT NULL DEFAULT '[]'::jsonb,
    ADD CONSTRAINT habits_type_check
        CHECK (type = ANY (ARRAY['generic'::text, 'gym'::text, 'sleep'::text, 'reading'::text, 'custom'::text]));

ALTER TABLE public.habit_completions
    ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

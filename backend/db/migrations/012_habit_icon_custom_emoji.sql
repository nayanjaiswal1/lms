-- ══════════════════════════════════════════════════════════════════════════
-- 012_habit_icon_custom_emoji.sql
-- Relaxes habits_icon_check: icon may still be '' or one of the curated
-- IconOptions keys, or now also any short custom value — an emoji typed via
-- the OS/Android keyboard's emoji picker, not just the curated lucide set.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.habits
    DROP CONSTRAINT habits_icon_check,
    ADD CONSTRAINT habits_icon_check
        CHECK (
            icon = ''::text
            OR icon = ANY (ARRAY[
                'dumbbell'::text, 'moon'::text, 'book-open'::text, 'brain'::text,
                'droplet'::text, 'utensils'::text, 'flower'::text, 'footprints'::text,
                'phone-off'::text, 'heart'::text, 'music'::text, 'palette'::text, 'code'::text,
                'piggy-bank'::text, 'leaf'::text, 'sun'::text, 'coffee'::text, 'pen-tool'::text,
                'target'::text, 'users'::text, 'briefcase'::text, 'graduation-cap'::text,
                'bike'::text, 'smile'::text
            ])
            OR char_length(icon) <= 8
        );

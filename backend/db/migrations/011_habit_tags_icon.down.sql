ALTER TABLE public.habits
    DROP CONSTRAINT IF EXISTS habits_icon_check,
    DROP COLUMN IF EXISTS icon,
    DROP COLUMN IF EXISTS tags;

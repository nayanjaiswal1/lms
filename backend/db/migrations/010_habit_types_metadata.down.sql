ALTER TABLE public.habit_completions
    DROP COLUMN IF EXISTS metadata;

ALTER TABLE public.habits
    DROP CONSTRAINT IF EXISTS habits_type_check,
    DROP COLUMN IF EXISTS custom_fields,
    DROP COLUMN IF EXISTS type;

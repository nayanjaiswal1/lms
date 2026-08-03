ALTER TABLE public.habit_completions
    DROP COLUMN count;

ALTER TABLE public.habits
    DROP COLUMN weekdays,
    DROP COLUMN target_count;

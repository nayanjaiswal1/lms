ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_last_page_check,
    DROP COLUMN IF EXISTS last_page;

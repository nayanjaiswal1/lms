ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_default_landing_page_check,
    DROP COLUMN IF EXISTS default_landing_page;

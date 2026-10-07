UPDATE public.user_profiles SET default_landing_page = NULL WHERE default_landing_page = '/last-visited';
ALTER TABLE public.user_profiles
    DROP CONSTRAINT user_profiles_default_landing_page_check,
    ADD CONSTRAINT user_profiles_default_landing_page_check
        CHECK (default_landing_page = ANY (ARRAY['/dashboard'::text, '/learn'::text, '/calendar'::text, '/mistakes'::text]));

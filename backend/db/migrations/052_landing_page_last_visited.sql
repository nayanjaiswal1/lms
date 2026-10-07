-- default_landing_page may now be '/last-visited': the frontend route that
-- redirects to the last app page the user viewed (tracked in a cookie).
ALTER TABLE public.user_profiles
    DROP CONSTRAINT user_profiles_default_landing_page_check,
    ADD CONSTRAINT user_profiles_default_landing_page_check
        CHECK (default_landing_page = ANY (ARRAY['/dashboard'::text, '/learn'::text, '/calendar'::text, '/mistakes'::text, '/last-visited'::text]));

-- Last app page the user viewed; synced (throttled) from the frontend so the
-- "last visited" landing works on a device whose cookie is missing.
ALTER TABLE public.user_profiles
    ADD COLUMN last_page text,
    ADD CONSTRAINT user_profiles_last_page_check
        CHECK (last_page IS NULL OR (last_page LIKE '/%' AND last_page NOT LIKE '//%' AND length(last_page) <= 512));

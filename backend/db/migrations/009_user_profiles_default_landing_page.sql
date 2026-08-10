-- ══════════════════════════════════════════════════════════════════════════
-- 009_user_profiles_default_landing_page.sql
-- user_profiles.default_landing_page: lets a user pick which page the
-- sidebar/mobile-nav logo click lands on (defaults to /dashboard when unset).
-- Restricted to routes with no feature/permission gate (see frontend/lib/
-- nav.ts's ALL_NAV_ITEMS) so the chosen page is always reachable regardless
-- of the user's org features or RBAC permissions.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.user_profiles
    ADD COLUMN default_landing_page text,
    ADD CONSTRAINT user_profiles_default_landing_page_check
        CHECK (default_landing_page = ANY (ARRAY['/dashboard'::text, '/learn'::text, '/calendar'::text, '/mistakes'::text]));

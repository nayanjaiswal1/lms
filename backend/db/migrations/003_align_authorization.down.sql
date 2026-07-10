-- ══════════════════════════════════════════════════════════════════════════
-- 003_align_authorization.sql — rollback
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.nav_permissions
    DROP CONSTRAINT nav_permissions_role_check;

UPDATE public.nav_permissions
    SET role = 'student'
    WHERE role = 'learner';

ALTER TABLE public.nav_permissions
    ADD CONSTRAINT nav_permissions_role_check
    CHECK ((role = ANY (ARRAY['student'::text, 'instructor'::text, 'mentor'::text, 'admin'::text])));

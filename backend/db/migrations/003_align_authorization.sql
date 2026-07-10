-- ══════════════════════════════════════════════════════════════════════════
-- 003_align_authorization.sql — Align role vocabulary across authz tables
--
-- SCHEMA_REVIEW.md Issue #2: nav_permissions.role uses 'student' for the role
-- that org_members.role calls 'learner'. Confirmed against 001_baseline.sql:
--   • org_members  — DEFAULT 'learner', CHECK IN (owner,admin,instructor,
--                    mentor,learner). Already correct — left untouched.
--   • nav_permissions — CHECK IN (student,instructor,mentor,admin), all seed
--                    rows use 'student'. This is the mismatch; realign to
--                    'learner' so nav lookups keyed on an org member's role
--                    match instead of silently returning no rows.
--
-- RBAC liveness note (SCHEMA_REVIEW.md Issue #2, "System 1"): the
-- roles/permissions/user_roles/role_permissions tables are LIVE, not dead
-- schema — GetEffectivePermissions() walks them and authz.RequirePermission
-- middleware guards real admin and mentoring routes. Do NOT drop them here;
-- consolidating the four parallel authz systems is a separate decision.
-- ══════════════════════════════════════════════════════════════════════════

-- Drop the old constraint first: the data UPDATE below sets 'learner', which
-- the old CHECK (which only allows 'student') would reject.
ALTER TABLE public.nav_permissions
    DROP CONSTRAINT nav_permissions_role_check;

UPDATE public.nav_permissions
    SET role = 'learner'
    WHERE role = 'student';

ALTER TABLE public.nav_permissions
    ADD CONSTRAINT nav_permissions_role_check
    CHECK ((role = ANY (ARRAY['learner'::text, 'instructor'::text, 'mentor'::text, 'admin'::text])));

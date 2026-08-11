-- Two permission codes were seeded in 001_baseline.sql but never granted to
-- any role, so no user could ever hold them:
--
--   mentoring.verify_mentors — the verified-expert badge toggle
--   (backend/internal/mentoring/routes.go) is documented as
--   "default: instructor + tenant_admin" but the seed grants it to nobody.
--
--   content.interview_exp — granted only to member, so there was no
--   moderator role for the interview-experience board even though
--   backend/internal/interviewexp/service.go checks RoleAdmin for
--   moderation. docs/rbac.md gives tenant_admin all permissions, so it
--   must hold this one too.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT '11111111-1111-1111-1111-000000000003', id FROM public.permissions WHERE code = 'mentoring.verify_mentors'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT '11111111-1111-1111-1111-000000000005', id FROM public.permissions WHERE code = 'mentoring.verify_mentors'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT '11111111-1111-1111-1111-000000000005', id FROM public.permissions WHERE code = 'content.interview_exp'
ON CONFLICT DO NOTHING;

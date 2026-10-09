-- Knowledge Captures is exclusive to jaiswal2062@gmail.com: drop the role
-- grants from 033 and hold it as a per-user override instead.
DELETE FROM public.role_permissions
WHERE permission_id IN (SELECT id FROM public.permissions WHERE code = 'content.captures');

DELETE FROM public.user_permission_overrides
WHERE permission_id IN (SELECT id FROM public.permissions WHERE code = 'content.captures');

INSERT INTO public.user_permission_overrides (user_id, org_id, permission_id, granted_by)
SELECT u.id, om.org_id, p.id, u.id
FROM public.users u
JOIN public.org_members om ON om.user_id = u.id
CROSS JOIN public.permissions p
WHERE u.email = 'jaiswal2062@gmail.com'
  AND p.code = 'content.captures'
ON CONFLICT (user_id, org_id, permission_id) DO NOTHING;

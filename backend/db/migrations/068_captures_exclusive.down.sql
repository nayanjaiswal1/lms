DELETE FROM public.user_permission_overrides
WHERE permission_id IN (SELECT id FROM public.permissions WHERE code = 'content.captures');

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.role_id, p.id
FROM (VALUES
    ('11111111-1111-1111-1111-000000000002'::uuid),
    ('11111111-1111-1111-1111-000000000003'::uuid),
    ('11111111-1111-1111-1111-000000000004'::uuid),
    ('11111111-1111-1111-1111-000000000005'::uuid)
) AS r(role_id), public.permissions p
WHERE p.code = 'content.captures'
ON CONFLICT DO NOTHING;

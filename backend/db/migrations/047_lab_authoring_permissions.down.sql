SET LOCAL lock_timeout = '5s';

DELETE FROM public.role_permissions
WHERE permission_id IN (SELECT id FROM public.permissions WHERE code IN ('labauthor.compose', 'labauthor.manage_blocks'));
DELETE FROM public.permissions WHERE code IN ('labauthor.compose', 'labauthor.manage_blocks');

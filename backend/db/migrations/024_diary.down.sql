DELETE FROM public.role_permissions
WHERE permission_id = (SELECT id FROM public.permissions WHERE code = 'content.diary');
DELETE FROM public.permissions WHERE code = 'content.diary';
DROP TABLE IF EXISTS public.diary_entries;

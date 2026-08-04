DELETE FROM public.role_permissions
 WHERE permission_id IN (SELECT id FROM public.permissions WHERE code = 'content.moderate');
DELETE FROM public.permissions WHERE code = 'content.moderate';
DROP TABLE IF EXISTS public.content_reports;

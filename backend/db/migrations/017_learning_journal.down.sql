DELETE FROM public.role_permissions
WHERE permission_id = (SELECT id FROM public.permissions WHERE code = 'content.learning_journal');
DELETE FROM public.permissions WHERE code = 'content.learning_journal';
DROP TABLE IF EXISTS public.learning_journal_entries;

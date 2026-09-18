DELETE FROM public.role_permissions
WHERE permission_id IN (SELECT id FROM public.permissions WHERE code = 'content.captures');
DELETE FROM public.permissions WHERE code = 'content.captures';

DROP INDEX IF EXISTS public.idx_srs_cards_front_trgm_capture;
DROP INDEX IF EXISTS public.idx_captures_user_status;
DROP TABLE IF EXISTS public.captures;

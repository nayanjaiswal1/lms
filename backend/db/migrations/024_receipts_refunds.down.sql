DELETE FROM public.role_permissions
 WHERE permission_id IN (SELECT id FROM public.permissions WHERE code = 'payments.manage_refunds');
DELETE FROM public.permissions WHERE code = 'payments.manage_refunds';
ALTER TABLE public.course_purchases DROP COLUMN IF EXISTS receipt_number;
DROP SEQUENCE IF EXISTS public.receipt_number_seq;

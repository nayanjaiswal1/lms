DELETE FROM public.role_permissions
WHERE permission_id = (SELECT id FROM public.permissions WHERE code = 'payments.manage_coupons');
DELETE FROM public.permissions WHERE code = 'payments.manage_coupons';

DROP INDEX IF EXISTS idx_course_purchases_user_course;
DROP INDEX IF EXISTS ux_course_purchases_provider_ref;
DROP INDEX IF EXISTS ux_course_purchases_completed;

ALTER TABLE public.course_purchases ADD CONSTRAINT course_purchases_user_id_course_id_key UNIQUE (user_id, course_id);
ALTER TABLE public.course_purchases ALTER COLUMN status SET DEFAULT 'completed';

ALTER TABLE public.course_purchases
    DROP CONSTRAINT course_purchases_discount_cents_check,
    DROP COLUMN coupon_id,
    DROP COLUMN discount_cents,
    DROP COLUMN payment_ref,
    DROP COLUMN updated_at;

DROP TABLE IF EXISTS public.payment_events;
DROP TABLE IF EXISTS public.coupon_redemptions;
DROP TABLE IF EXISTS public.coupons;

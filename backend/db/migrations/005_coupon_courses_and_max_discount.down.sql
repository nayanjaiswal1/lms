DROP TABLE IF EXISTS public.coupon_courses;

ALTER TABLE public.coupons
    DROP CONSTRAINT coupons_max_discount_cents_check,
    DROP COLUMN max_discount_cents;

ALTER TABLE public.coupons ADD COLUMN course_id uuid REFERENCES courses(id) ON DELETE CASCADE;

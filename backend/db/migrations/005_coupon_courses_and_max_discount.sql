-- ═════════════════════════════════════════════════════════════════════════
-- Migration 005 — coupon_courses_and_max_discount
-- ═════════════════════════════════════════════════════════════════════════
-- 004_payments_coupons.sql gave a coupon a single optional course_id (NULL =
-- any paid course in the org). That's too narrow — a coupon needs to scope
-- to one, several, or all courses. Replaced with a join table:
-- zero rows for a coupon = org-wide (unchanged default), one or more rows =
-- restricted to exactly those courses.
--
-- Also adds max_discount_cents: a percent-off coupon ("30% off") can
-- otherwise discount an arbitrarily large amount on an expensive course —
-- this caps the absolute discount regardless of percentage. Meaningless for
-- a fixed-amount coupon (its discount_value already IS the cap), so no
-- coupons.discount_type coupling is enforced — it's simply a no-op there.

ALTER TABLE public.coupons DROP COLUMN course_id;

ALTER TABLE public.coupons ADD COLUMN max_discount_cents integer;
ALTER TABLE public.coupons
    ADD CONSTRAINT coupons_max_discount_cents_check CHECK (max_discount_cents IS NULL OR max_discount_cents > 0);

CREATE TABLE public.coupon_courses (
    coupon_id uuid NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    course_id uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    PRIMARY KEY (coupon_id, course_id)
);

CREATE INDEX idx_coupon_courses_course ON public.coupon_courses (course_id);

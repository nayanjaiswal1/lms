-- Reverses 009_coupon_hold_guard.sql. The purchases the up-migration retired
-- to 'failed' are not resurrected: they were abandoned checkouts by the same
-- 30-minute rule StartCheckout already applies, and a student can simply
-- start a new one.
DROP INDEX IF EXISTS ux_course_purchases_coupon_user_open;

-- ═════════════════════════════════════════════════════════════════════════
-- Migration 009 — coupon_hold_guard
-- ═════════════════════════════════════════════════════════════════════════
-- coupon_redemptions.UNIQUE(coupon_id, user_id) enforces "one redemption per
-- user per coupon", but that row is only written at webhook confirmation
-- (coupons.Repo.ConsumeTx) — deliberately, so an abandoned checkout never
-- burns a redemption. Nothing guarded the window in between: a student could
-- open N simultaneous checkouts on N different courses with the same
-- one-per-customer coupon and be charged the discounted price on every one.
-- Only the first ConsumeTx then succeeds; the rest hit the unique violation
-- that mentoring.Service.confirmPurchase deliberately swallows (the money is
-- already captured, so the enrollment must still proceed) — so the discount
-- was granted N times while redeemed_count rose by one.
--
-- The fix is a second unique index covering the OPEN window (pending or
-- completed), which is what makes the guarantee atomic rather than a
-- check-then-insert the application could race. A pending row is the "hold";
-- StartCheckout expires the caller's own stale holds (older than the same 30
-- minutes GetLivePendingPurchase already treats as dead) before inserting, so
-- an abandoned checkout never locks a coupon up permanently.

-- Existing data must satisfy the index before it can be created: retire
-- pending coupon-backed purchases that are already dead by the 30-minute rule,
-- then any pending hold whose coupon the same user has already redeemed.
UPDATE public.course_purchases
   SET status = 'failed', updated_at = now()
 WHERE status = 'pending'
   AND coupon_id IS NOT NULL
   AND purchased_at < now() - interval '30 minutes';

UPDATE public.course_purchases p
   SET status = 'failed', updated_at = now()
 WHERE p.status = 'pending'
   AND p.coupon_id IS NOT NULL
   AND EXISTS (
       SELECT 1 FROM public.course_purchases done
        WHERE done.coupon_id = p.coupon_id
          AND done.user_id = p.user_id
          AND done.status = 'completed'
   );

CREATE UNIQUE INDEX ux_course_purchases_coupon_user_open
    ON public.course_purchases (coupon_id, user_id)
    WHERE coupon_id IS NOT NULL AND status IN ('pending', 'completed');

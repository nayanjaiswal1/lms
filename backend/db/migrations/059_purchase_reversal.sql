-- Purchase reversal: a 'refunding' status persisted before the gateway refund
-- call (so a crash between call and DB write is recoverable), and a ledger
-- reason for clawing back credit-pack sessions on refund or dispute.
ALTER TABLE public.purchases DROP CONSTRAINT course_purchases_status_check;
ALTER TABLE public.purchases ADD CONSTRAINT course_purchases_status_check
    CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'refunding'::text, 'refunded'::text]));

ALTER TABLE public.session_credit_ledger DROP CONSTRAINT session_credit_ledger_reason_chk;
ALTER TABLE public.session_credit_ledger ADD CONSTRAINT session_credit_ledger_reason_chk
    CHECK (reason = ANY (ARRAY['purchase'::text, 'admin_grant'::text, 'admin_revoke'::text, 'booking'::text, 'cancellation_refund'::text, 'purchase_reversal'::text]));

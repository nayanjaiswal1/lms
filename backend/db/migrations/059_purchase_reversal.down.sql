UPDATE public.purchases SET status = 'completed' WHERE status = 'refunding';
ALTER TABLE public.purchases DROP CONSTRAINT course_purchases_status_check;
ALTER TABLE public.purchases ADD CONSTRAINT course_purchases_status_check
    CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'refunded'::text]));

DELETE FROM public.session_credit_ledger WHERE reason = 'purchase_reversal';
ALTER TABLE public.session_credit_ledger DROP CONSTRAINT session_credit_ledger_reason_chk;
ALTER TABLE public.session_credit_ledger ADD CONSTRAINT session_credit_ledger_reason_chk
    CHECK (reason = ANY (ARRAY['purchase'::text, 'admin_grant'::text, 'admin_revoke'::text, 'booking'::text, 'cancellation_refund'::text]));

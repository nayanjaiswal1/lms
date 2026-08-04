-- ═════════════════════════════════════════════════════════════════════════
-- Migration 024 — receipts_refunds
-- ═════════════════════════════════════════════════════════════════════════
-- receipt_number gives a completed purchase a stable, human-readable
-- reference ("MF-2026-000123") for the student-facing receipt page —
-- stamped once, at the moment a purchase transitions to 'completed'
-- (mentoring.Repo.MarkPurchaseCompletedTx), never reused across purchases.
-- No GST breakdown/invoice fields: the platform has no GSTIN yet, so this is
-- a plain payment receipt, not a tax invoice.

CREATE SEQUENCE public.receipt_number_seq;

ALTER TABLE public.course_purchases ADD COLUMN receipt_number text;

-- ── RBAC ─────────────────────────────────────────────────────────────────
-- Gates triggering a refund (POST .../refund) — admin-triggered only, never
-- self-serve auto-approved, so a human reviews every refund before money
-- moves back out.
INSERT INTO public.permissions (code, name, description, module)
VALUES ('payments.manage_refunds', 'Issue Refunds',
        'Trigger a refund against a completed purchase', 'payments')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
 WHERE p.code = 'payments.manage_refunds'
   AND r.is_system
   AND r.name IN ('tenant_admin')
ON CONFLICT DO NOTHING;

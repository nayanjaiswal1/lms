-- ═════════════════════════════════════════════════════════════════════════
-- Migration 004 — payments_coupons
-- ═════════════════════════════════════════════════════════════════════════
-- course_purchases already anticipated real gateways (provider CHECK already
-- includes 'stripe'/'razorpay', status already includes 'pending'/'failed')
-- but purchasing only ever went through payments.StubProvider, which charges
-- nothing and completes synchronously. This migration adds what a real,
-- webhook-confirmed, coupon-capable purchase flow needs:
--   - coupons / coupon_redemptions: discount codes, redemption capped and
--     de-duplicated entirely by DB constraints (see backend/internal/coupons)
--   - payment_events: webhook delivery dedup + audit trail, keyed on the
--     gateway's own event id so a retried/duplicated webhook is a no-op
--   - course_purchases: gains coupon linkage, a real "only one COMPLETED
--     purchase per user+course" constraint (replacing the old blanket
--     unique, which would have permanently blocked retrying a failed/
--     abandoned checkout), and a lookup index for webhook confirmation.

CREATE TABLE public.coupons (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    code             text NOT NULL,
    description      text NOT NULL DEFAULT '',
    discount_type    text NOT NULL,
    discount_value   integer NOT NULL,
    course_id        uuid REFERENCES courses(id) ON DELETE CASCADE,
    max_redemptions  integer,
    redeemed_count   integer NOT NULL DEFAULT 0,
    starts_at        timestamptz,
    expires_at       timestamptz,
    is_active        boolean NOT NULL DEFAULT true,
    created_by       uuid REFERENCES users(id) ON DELETE SET NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT coupons_discount_type_check CHECK (discount_type = ANY (ARRAY['percent'::text, 'fixed'::text])),
    CONSTRAINT coupons_discount_value_check CHECK (
        (discount_type = 'percent' AND discount_value BETWEEN 1 AND 100)
        OR (discount_type = 'fixed' AND discount_value > 0)
    ),
    CONSTRAINT coupons_max_redemptions_check CHECK (max_redemptions IS NULL OR max_redemptions > 0),
    CONSTRAINT coupons_redeemed_count_check CHECK (
        redeemed_count >= 0 AND (max_redemptions IS NULL OR redeemed_count <= max_redemptions)
    ),
    CONSTRAINT coupons_window_check CHECK (starts_at IS NULL OR expires_at IS NULL OR expires_at > starts_at)
);

CREATE UNIQUE INDEX coupons_org_code_key ON public.coupons (org_id, upper(code));
CREATE INDEX idx_coupons_org ON public.coupons (org_id, created_at DESC);

CREATE TABLE public.coupon_redemptions (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    coupon_id      uuid NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purchase_id    uuid NOT NULL REFERENCES course_purchases(id) ON DELETE CASCADE,
    discount_cents integer NOT NULL CHECK (discount_cents >= 0),
    redeemed_at    timestamptz NOT NULL DEFAULT now(),
    -- Per-user reuse is enforced here, not in application code, so a race
    -- between two concurrent redemption attempts by the same user cannot
    -- both succeed (see backend/internal/coupons/repo.go ConsumeTx).
    CONSTRAINT coupon_redemptions_coupon_user_key UNIQUE (coupon_id, user_id),
    CONSTRAINT coupon_redemptions_purchase_key UNIQUE (purchase_id)
);

CREATE INDEX idx_coupon_redemptions_coupon ON public.coupon_redemptions (coupon_id, redeemed_at DESC);

CREATE TABLE public.payment_events (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider     text NOT NULL CHECK (provider = ANY (ARRAY['stub'::text, 'stripe'::text, 'razorpay'::text])),
    event_id     text NOT NULL,
    event_type   text NOT NULL,
    provider_ref text,
    purchase_id  uuid REFERENCES course_purchases(id) ON DELETE SET NULL,
    payload      jsonb NOT NULL,
    received_at  timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    error        text,
    -- The webhook replay guard: a duplicate delivery of the same gateway
    -- event id is a required, expected occurrence (Stripe retries for up to
    -- 72h; both gateways may redeliver), not an error condition.
    CONSTRAINT payment_events_provider_event_key UNIQUE (provider, event_id)
);

CREATE INDEX idx_payment_events_unprocessed ON public.payment_events (received_at) WHERE processed_at IS NULL;

ALTER TABLE public.course_purchases
    ADD COLUMN coupon_id      uuid REFERENCES coupons(id) ON DELETE SET NULL,
    ADD COLUMN discount_cents integer NOT NULL DEFAULT 0,
    ADD COLUMN payment_ref    text,
    ADD COLUMN updated_at     timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.course_purchases
    ADD CONSTRAINT course_purchases_discount_cents_check CHECK (discount_cents >= 0);

ALTER TABLE public.course_purchases ALTER COLUMN status SET DEFAULT 'pending';

-- The old constraint blocked ever retrying a failed/abandoned purchase (it
-- covered every status, not just completed ones). A pending or failed
-- attempt must not block a new checkout; only one COMPLETED purchase per
-- user+course may ever exist.
ALTER TABLE public.course_purchases DROP CONSTRAINT course_purchases_user_id_course_id_key;
CREATE UNIQUE INDEX ux_course_purchases_completed
    ON public.course_purchases (user_id, course_id) WHERE status = 'completed';

-- Webhook confirmation looks purchases up by the gateway's own reference.
-- provider_ref is set to a "checkout_<uuid>" placeholder at insert time
-- (before the gateway call) and overwritten once the gateway returns its
-- real session/order id, so it is never NULL and this index needs no
-- partial-index clause.
CREATE UNIQUE INDEX ux_course_purchases_provider_ref
    ON public.course_purchases (provider, provider_ref);

CREATE INDEX idx_course_purchases_user_course
    ON public.course_purchases (user_id, course_id, purchased_at DESC);

INSERT INTO public.permissions (code, name, description, module)
VALUES (
    'payments.manage_coupons',
    'Manage Coupons',
    'Create, edit, and deactivate course discount coupons',
    'payments'
);

-- Granted to tenant_admin only by default — discounting is a business
-- decision, not a course-authoring one. The existing RBAC admin UI can
-- grant it to instructor at runtime with no further migration needed.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r, public.permissions p
WHERE p.code = 'payments.manage_coupons' AND r.is_system = true AND r.name = 'tenant_admin';

-- ════════════════════════════════════════════════════════════════════════════
-- 018_payments_stub.sql — Payment provider stub
-- ════════════════════════════════════════════════════════════════════════════
-- No real payment gateway is wired up yet. This table records purchases made
-- through the stub provider (backend/internal/payments) so the mentor-ticket
-- flow has something concrete to key off of. `provider`/`provider_ref` are
-- shaped so a real gateway (Stripe/Razorpay) can be swapped in later without
-- a schema change — only the provider implementation changes.

CREATE TABLE course_purchases (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id       UUID        NOT NULL REFERENCES users(id)         ON DELETE CASCADE,
  course_id     UUID        NOT NULL REFERENCES courses(id)       ON DELETE CASCADE,
  amount_cents  INT         NOT NULL CHECK (amount_cents >= 0),
  currency      TEXT        NOT NULL DEFAULT 'USD',
  provider      TEXT        NOT NULL DEFAULT 'stub' CHECK (provider IN ('stub','stripe','razorpay')),
  provider_ref  TEXT        NOT NULL,
  status        TEXT        NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','failed','refunded')),
  purchased_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, course_id)
);

CREATE INDEX idx_course_purchases_org ON course_purchases (org_id, purchased_at DESC);

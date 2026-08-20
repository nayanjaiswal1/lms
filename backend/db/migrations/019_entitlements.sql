-- ══════════════════════════════════════════════════════════════════════════
-- 019_entitlements.sql
-- Links pricing_tiers (marketing, migration 004) to real enforcement, per
-- docs/entitlements.md. Two pieces:
--
--   1. tier_id on users/organizations — which pricing_tiers row an account is
--      actually on. Nothing sells a tier upgrade yet (every paid CTA on the
--      landing pages is still "Coming soon"), so this is platform-admin-set
--      for now, same as every other admin-only knob in this schema.
--   2. plan_limits — one row per (tier, feature_key) the resolvers below
--      actually read. Deliberately NOT a full mirror of docs/entitlements.md
--      §2's matrix: only feature_keys with a real reader are seeded here
--      (backend/internal/features.Service.Resolve for the gate rows,
--      backend/internal/labs.Service for the two quota rows) — an
--      admin-editable number nothing enforces is exactly the "feature flag
--      deferral" anti-pattern CLAUDE.md bans. The rest of the matrix (AI
--      practice quota, mentor credits, sheet tracker, seats) stays
--      unimplemented until it has a real call site to wire into.
--
-- usage_counters backs the two quota rows: lab_sessions_concurrent is a live
-- COUNT(*) against lab_sessions (no counter needed), lab_hours accrues here,
-- written by labs.Repo.RecordSessionContainerUsage(Batch) at session close —
-- see docs/entitlements.md §6's "flush periodically, not on every tick".
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.users
    ADD COLUMN tier_id text NOT NULL DEFAULT 'individual_free' REFERENCES public.pricing_tiers(id);

ALTER TABLE public.organizations
    ADD COLUMN tier_id text NOT NULL DEFAULT 'org_starter' REFERENCES public.pricing_tiers(id);

CREATE TABLE public.plan_limits (
    id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    tier_id       text NOT NULL REFERENCES public.pricing_tiers(id) ON DELETE CASCADE,
    feature_key   text NOT NULL,
    kind          text NOT NULL CHECK (kind IN ('gate', 'quota', 'unlimited')),
    bool_value    boolean,
    numeric_value integer,
    period        text CHECK (period IN ('day', 'month', 'concurrent')),
    updated_by    uuid REFERENCES public.users(id),
    updated_at    timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE (tier_id, feature_key),
    CHECK (
        (kind = 'gate' AND bool_value IS NOT NULL AND numeric_value IS NULL AND period IS NULL) OR
        (kind = 'quota' AND numeric_value IS NOT NULL AND period IS NOT NULL AND bool_value IS NULL) OR
        (kind = 'unlimited' AND bool_value IS NULL AND numeric_value IS NULL)
    )
);

-- account_id is polymorphic (a users.id or an organizations.id depending on
-- which pricing_tiers.audience the feature_key belongs to) — same
-- "account_id resolves to user_id or org_id" shape docs/entitlements.md §3
-- describes, so no single FK target. period_start is the bucket key (month
-- truncation for lab_hours); period_end is stored alongside for display only.
CREATE TABLE public.usage_counters (
    account_id  uuid NOT NULL,
    feature_key text NOT NULL,
    period_start date NOT NULL,
    period_end   date NOT NULL,
    used_count   bigint NOT NULL DEFAULT 0,
    updated_at   timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (account_id, feature_key, period_start)
);

-- ─── Seed: org-tier gates ────────────────────────────────────────────────
-- Both keys already exist in features.alwaysOrgEnabled (defaulted to `true`
-- for every org before this migration); these rows are what Service.Resolve
-- now reads instead of the hardcoded default, for these two keys only.
INSERT INTO public.plan_limits (tier_id, feature_key, kind, bool_value) VALUES
    ('org_starter',    'assessments',        'gate', false),
    ('org_growth',     'assessments',        'gate', true),
    ('org_enterprise',  'assessments',        'gate', true),
    ('org_starter',    'gitlab_integration', 'gate', false),
    ('org_growth',     'gitlab_integration', 'gate', true),
    ('org_enterprise',  'gitlab_integration', 'gate', true);

-- ─── Seed: individual-tier gates ────────────────────────────────────────────
-- All four keys already exist in features.alwaysEntitled. Every individual
-- user shares the platform's cfg.DefaultOrgID org, so these can only be
-- resolved per-user (via users.tier_id), never per-org — see
-- features.Service.Resolve's DefaultOrgID branch. what_now/revision_digest
-- are deliberately not here — see entitlements.IndividualGateKeys' doc
-- comment for why.
INSERT INTO public.plan_limits (tier_id, feature_key, kind, bool_value) VALUES
    ('individual_free', 'system_design',   'gate', false),
    ('individual_plus', 'system_design',   'gate', false),
    ('individual_pro',  'system_design',   'gate', true),
    ('individual_free', 'interview_board', 'gate', false),
    ('individual_plus', 'interview_board', 'gate', false),
    ('individual_pro',  'interview_board', 'gate', true),
    ('individual_free', 'load_test',       'gate', false),
    ('individual_plus', 'load_test',       'gate', false),
    ('individual_pro',  'load_test',       'gate', true),
    ('individual_free', 'certificates',    'gate', false),
    ('individual_plus', 'certificates',    'gate', true),
    ('individual_pro',  'certificates',    'gate', true);

-- ─── Seed: individual-tier lab quotas ───────────────────────────────────────
-- Numbers match the marketing copy already seeded in migration 004
-- ("1 lab session at a time" / "Up to 15 lab-hours a month, 2 sessions at
-- once" / "Up to 40 lab-hours a month, priority queue") and
-- docs/entitlements.md §2's Individual matrix. 'concurrent' period means "live
-- count, no time bucket" — labs.Service checks it against a COUNT(*) of the
-- user's active sessions, never touches usage_counters.
INSERT INTO public.plan_limits (tier_id, feature_key, kind, numeric_value, period) VALUES
    ('individual_free', 'lab_sessions_concurrent', 'quota', 1, 'concurrent'),
    ('individual_plus', 'lab_sessions_concurrent', 'quota', 2, 'concurrent'),
    ('individual_pro',  'lab_sessions_concurrent', 'quota', 3, 'concurrent'),
    ('individual_free', 'lab_hours',               'quota', 3, 'month'),
    ('individual_plus', 'lab_hours',               'quota', 15, 'month'),
    ('individual_pro',  'lab_hours',               'quota', 40, 'month');

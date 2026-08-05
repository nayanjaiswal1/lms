-- ══════════════════════════════════════════════════════════════════════════
-- 004_pricing_tiers.sql
-- Marketing pricing tiers for the two public landing pages (/ and /org),
-- previously hardcoded as INDIVIDUAL_PRICING_TIERS/ORG_PRICING_TIERS in the
-- frontend (frontend/lib/features.ts) — every price/feature-bullet change
-- required a rebuild+redeploy. Moving them here lets a platform admin edit
-- price, tagline, feature bullets, and CTA state from /platform/pricing
-- without touching code. Still presentational only: there is no billing
-- backend, so cta_disabled continues to gate real checkout the same way the
-- old static PLAN_TIERS placeholders did.
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE public.pricing_tiers (
    id           text PRIMARY KEY,
    audience     text NOT NULL CHECK (audience IN ('individual', 'org')),
    position     smallint NOT NULL,
    name         text NOT NULL,
    price        text NOT NULL,
    billing_note text NOT NULL,
    tagline      text NOT NULL,
    features     jsonb NOT NULL DEFAULT '[]'::jsonb,
    cta_label    text NOT NULL,
    cta_disabled boolean NOT NULL DEFAULT true,
    cta_href     text,
    highlighted  boolean NOT NULL DEFAULT false,
    updated_by   uuid REFERENCES public.users(id),
    updated_at   timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX pricing_tiers_audience_position_idx ON public.pricing_tiers (audience, position);

-- Seed with the exact values the static frontend constants shipped, so
-- applying this migration changes nothing visible until an admin edits a row.
INSERT INTO public.pricing_tiers
    (id, audience, position, name, price, billing_note, tagline, features, cta_label, cta_disabled, cta_href, highlighted)
VALUES
    ('individual_free', 'individual', 1, 'Free', '₹0', 'forever', 'Enough to actually learn something.',
     '["Enroll in free courses, no limit", "Coding problems, quizzes, and spaced-repetition flashcards", "1 lab session at a time", "Public practice tests — no account needed to try them"]'::jsonb,
     'Start learning free', false, '/register', false),

    ('individual_plus', 'individual', 2, 'Plus', '₹299', '/month', 'For steady, self-paced study.',
     '["Everything in Free", "Up to 15 lab-hours a month, 2 sessions at once", "AI-generated revision digest and quiz variants", "Verifiable completion certificates", "Multi-sheet problem tracker with overlap view"]'::jsonb,
     'Coming soon', true, NULL, false),

    ('individual_pro', 'individual', 3, 'Pro', '₹799', '/month', 'For interview prep on a deadline.',
     '["Everything in Plus", "Up to 40 lab-hours a month, priority queue", "System design canvas and live interview board", "AI mock interviews with personalized feedback", "2 mentor session credits every month"]'::jsonb,
     'Coming soon', true, NULL, true),

    ('org_starter', 'org', 1, 'Starter', '₹0', 'up to 10 seats', 'Everything you need to run one cohort.',
     '["Up to 10 members", "Admin, instructor, mentor, and student roles", "Shared course library and wiki", "Batch chat for each cohort"]'::jsonb,
     'Set up your organization', false, '/org/create', false),

    ('org_growth', 'org', 2, 'Growth', '₹499', '/seat/month', 'For programs that need proof of learning.',
     '["Unlimited seats", "Proctored assessments with auto-grading and analytics", "Anonymous public tests for candidate screening", "Mentor session booking with credit pools", "GitLab integration for graded submissions"]'::jsonb,
     'Coming soon', true, NULL, true),

    ('org_enterprise', 'org', 3, 'Enterprise', 'Contact us', 'custom', 'For large programs with custom requirements.',
     '["Everything in Growth", "SSO and custom domain", "Audit log and compliance exports", "Dedicated support and a custom AI token budget"]'::jsonb,
     'Coming soon', true, NULL, false);

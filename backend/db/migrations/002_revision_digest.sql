-- ══════════════════════════════════════════════════════════════════════════
-- 002_revision_digest.sql
-- Nightly AI revision digest: per-student beta feature gated via the
-- existing features.* permission-override mechanism (see features.what_now
-- for the precedent). revision_digests is simultaneously the 1-email/day
-- cap (UNIQUE(user_id, digest_date)), the "AI called once" cache, and the
-- cost ledger the budget caps in internal/digest read from.
-- ══════════════════════════════════════════════════════════════════════════

INSERT INTO public.permissions (code, name, module, is_active)
VALUES ('features.revision_digest', 'Revision Digest (beta)', 'features', true)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE public.revision_digests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    org_id uuid NOT NULL,
    digest_date date NOT NULL,
    cadences text[] NOT NULL,
    window_start timestamp with time zone NOT NULL,
    window_end timestamp with time zone NOT NULL,
    ai_status text NOT NULL,
    model text,
    input_tokens integer DEFAULT 0 NOT NULL,
    output_tokens integer DEFAULT 0 NOT NULL,
    cost_usd numeric(10,6) DEFAULT 0 NOT NULL,
    subject text NOT NULL,
    body text NOT NULL,
    email_job_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT revision_digests_pkey PRIMARY KEY (id),
    CONSTRAINT revision_digests_user_id_digest_date_key UNIQUE (user_id, digest_date),
    CONSTRAINT revision_digests_ai_status_check CHECK ((ai_status = ANY (ARRAY['generated'::text, 'skipped_budget'::text, 'skipped_unavailable'::text, 'failed'::text]))),
    CONSTRAINT revision_digests_cadences_check CHECK ((cardinality(cadences) > 0)),
    CONSTRAINT revision_digests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT revision_digests_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE
);

CREATE INDEX revision_digests_digest_date_idx ON public.revision_digests (digest_date);
CREATE INDEX revision_digests_user_id_digest_date_idx ON public.revision_digests (user_id, digest_date DESC);

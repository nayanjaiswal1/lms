-- ═════════════════════════════════════════════════════════════════════════
-- Migration 022 — legal_acceptances
-- ═════════════════════════════════════════════════════════════════════════
-- Append-only record that a user accepted a given version of the Terms of
-- Service or Privacy Policy. The policy text itself lives as static frontend
-- pages, not in the database — this table only proves consent happened, for
-- which version, and when. Never updated or deleted: it is the audit trail.
--
-- "Current version" is a Go constant (backend/internal/legal), not a DB row —
-- bumping the constant is how a policy change forces re-acceptance; the
-- comparison happens by reading each user's latest row per doc_type.

CREATE TABLE public.legal_acceptances (
    id          uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    doc_type    text NOT NULL,
    version     text NOT NULL,
    ip          text,
    accepted_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT legal_acceptances_doc_type_check CHECK (doc_type = ANY (ARRAY['terms'::text, 'privacy'::text]))
);

-- Read pattern is always "this user's latest row for this doc_type".
CREATE INDEX idx_legal_acceptances_user ON public.legal_acceptances (user_id, doc_type, accepted_at DESC);

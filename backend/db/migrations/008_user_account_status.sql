-- ═════════════════════════════════════════════════════════════════════════
-- Migration 008 — user_account_status
-- ═════════════════════════════════════════════════════════════════════════
-- The users table had no way to lock an account. org_members.status can
-- suspend a membership, but that is per-org: a suspended member keeps a valid
-- session, keeps signing in, and keeps their other org memberships. There was
-- no answer to "stop this person from signing in at all" short of deleting the
-- row, which destroys their work and cascades.
--
-- status is deliberately platform-level and orthogonal to org_members.status:
--   active      — normal.
--   suspended   — an admin locked the account. Sign-in is refused, existing
--                 sessions die (the writer bumps session_version), the data is
--                 untouched, and it is reversible.
--   deactivated — the user asked to leave. Same enforcement as suspended; kept
--                 distinct so "we locked them out" and "they left" do not
--                 report as the same thing.
--
-- Both non-active states are enforced at every sign-in path (password, social
-- exchange, passkey) and at refresh, so no new session can be minted. Live
-- access tokens are retired by the session_version bump the status writer
-- performs, which is why RequireAuth needs no extra per-request query.

ALTER TABLE public.users
    ADD COLUMN status text DEFAULT 'active' NOT NULL;

ALTER TABLE public.users
    ADD CONSTRAINT users_status_check
    CHECK (status = ANY (ARRAY['active'::text, 'suspended'::text, 'deactivated'::text]));

-- status_reason is operator-facing context for why an account was locked
-- (support ticket, abuse report). NULL whenever status = 'active'.
ALTER TABLE public.users
    ADD COLUMN status_reason text;

ALTER TABLE public.users
    ADD COLUMN status_changed_at timestamp with time zone;

-- Sign-in reads status for exactly one user at a time, so the lookup rides the
-- existing primary key. This partial index instead serves the admin console's
-- "show me the locked accounts" listing, and stays tiny because the
-- overwhelming majority of rows are active.
CREATE INDEX users_status_idx ON public.users (status) WHERE status <> 'active';

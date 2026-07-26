-- ═════════════════════════════════════════════════════════════════════════
-- Migration 017 — add_mcp_action_log
-- Per-user audit trail of every tool call a student's connected AI (via the
-- MCP connector) makes on their behalf, with enough before/after state to
-- selectively revert a mutation. Deliberately separate from audit_logs
-- (internal/orgs): that table is org_id-scoped and role-gated for org
-- admins reviewing member/invite/role changes, none of which are
-- revertible — bolting revert columns onto it would leave them null/false
-- on every non-MCP row. This table is user_id-first (a student only ever
-- sees their own AI's actions) and every row has exactly one actor
-- connection.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.mcp_action_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    connection_id uuid NOT NULL,
    tool_name text NOT NULL,
    args jsonb NOT NULL,
    target_type text,
    target_id uuid,
    before_state jsonb,
    after_state jsonb,
    revertible boolean DEFAULT false NOT NULL,
    reverted_at timestamp with time zone,
    reverted_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mcp_action_log_pkey PRIMARY KEY (id),
    CONSTRAINT mcp_action_log_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT mcp_action_log_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT mcp_action_log_connection_fk FOREIGN KEY (connection_id)
        REFERENCES public.mcp_connections(id) ON DELETE CASCADE,
    CONSTRAINT mcp_action_log_reverted_by_fk FOREIGN KEY (reverted_by)
        REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE INDEX idx_mcp_action_log_user ON public.mcp_action_log (user_id, created_at DESC);

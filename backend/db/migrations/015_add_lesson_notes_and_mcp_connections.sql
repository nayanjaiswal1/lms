-- ═════════════════════════════════════════════════════════════════════════
-- Migration 015 — add_lesson_notes_and_mcp_connections
-- Two additions for the "connect your own Claude/ChatGPT" feature:
--   1. lesson_notes: a per-user editable overlay on a lesson, separate from
--      the graded/ungraded content on the module itself (edit/update/view
--      original in the UI). One row per (user, module), upserted.
--   2. mcp_clients / mcp_connections / mcp_access_tokens / mcp_auth_codes:
--      OAuth 2.1+PKCE state for external MCP clients (the student's own
--      Claude/ChatGPT) connecting to our MCP server.
--        - mcp_clients: one row per Dynamic-Client-Registration call (the
--          external app itself, e.g. "Claude").
--        - mcp_connections: one row per (user, client) the user has actually
--          approved — holds the long-lived refresh token, hashed the same
--          way the existing refresh_tokens table hashes login refresh
--          tokens (SHA-256, compare-only, nothing to decrypt if breached).
--        - mcp_access_tokens: short-lived bearer tokens minted from a
--          connection's refresh token, hashed the same way.
--        - mcp_auth_codes: single-use authorization codes, mirrors the
--          existing oauth_exchanges table's shape/TTL pattern.
--   3. lesson_reflections.source: tags whether a reflection row was typed by
--      the student or written by their connected AI client via the
--      log_understanding MCP tool, so revisionplan can weight them separately.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.lesson_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    module_id uuid NOT NULL,
    content text NOT NULL,
    source text DEFAULT 'manual'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lesson_notes_pkey PRIMARY KEY (id),
    CONSTRAINT lesson_notes_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT lesson_notes_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT lesson_notes_module_fk FOREIGN KEY (module_id)
        REFERENCES public.course_modules(id) ON DELETE CASCADE,
    CONSTRAINT lesson_notes_user_module_key UNIQUE (user_id, module_id),
    CONSTRAINT lesson_notes_content_not_blank_check CHECK (btrim(content) <> ''::text),
    CONSTRAINT lesson_notes_source_check CHECK (source = ANY (ARRAY['manual'::text, 'ai'::text]))
);

CREATE INDEX idx_lesson_notes_org_module ON public.lesson_notes (org_id, module_id);

ALTER TABLE public.lesson_reflections
    ADD COLUMN source text DEFAULT 'manual'::text NOT NULL,
    ADD CONSTRAINT lesson_reflections_source_check CHECK (source = ANY (ARRAY['manual'::text, 'ai'::text]));

CREATE TABLE public.mcp_clients (
    client_id text NOT NULL,
    client_name text NOT NULL,
    redirect_uris text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mcp_clients_pkey PRIMARY KEY (client_id)
);

CREATE TABLE public.mcp_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id text NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    refresh_token_hash text NOT NULL,
    refresh_token_expires_at timestamp with time zone NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT mcp_connections_pkey PRIMARY KEY (id),
    CONSTRAINT mcp_connections_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT mcp_connections_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT mcp_connections_client_fk FOREIGN KEY (client_id)
        REFERENCES public.mcp_clients(client_id) ON DELETE CASCADE,
    CONSTRAINT mcp_connections_status_check CHECK (status = ANY (ARRAY['active'::text, 'revoked'::text]))
);

CREATE UNIQUE INDEX idx_mcp_connections_user_client ON public.mcp_connections (user_id, client_id);
CREATE UNIQUE INDEX idx_mcp_connections_refresh_hash ON public.mcp_connections (refresh_token_hash);

CREATE TABLE public.mcp_access_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    connection_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mcp_access_tokens_pkey PRIMARY KEY (id),
    CONSTRAINT mcp_access_tokens_connection_fk FOREIGN KEY (connection_id)
        REFERENCES public.mcp_connections(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX idx_mcp_access_tokens_hash ON public.mcp_access_tokens (token_hash);
CREATE INDEX idx_mcp_access_tokens_expires ON public.mcp_access_tokens (expires_at);

CREATE TABLE public.mcp_auth_codes (
    code text NOT NULL,
    client_id text NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    code_challenge text NOT NULL,
    redirect_uri text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mcp_auth_codes_pkey PRIMARY KEY (code),
    CONSTRAINT mcp_auth_codes_client_fk FOREIGN KEY (client_id)
        REFERENCES public.mcp_clients(client_id) ON DELETE CASCADE,
    CONSTRAINT mcp_auth_codes_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT mcp_auth_codes_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE
);

CREATE INDEX idx_mcp_auth_codes_expires ON public.mcp_auth_codes (expires_at);

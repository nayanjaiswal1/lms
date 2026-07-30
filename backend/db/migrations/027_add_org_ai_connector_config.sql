-- ═════════════════════════════════════════════════════════════════════════
-- Migration 027 — org_ai_connector_config
-- Adds a per-org on/off switch for the AI Connector (MCP) feature
-- (docs/ai-connector.md) — org admins can now disable /mcp OAuth + tool
-- access for their whole org. Defaults to enabled=true so existing
-- connected students aren't silently cut off the day this ships.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.org_ai_connector_config (
    org_id     uuid NOT NULL,
    enabled    boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_ai_connector_config_pkey PRIMARY KEY (org_id),
    CONSTRAINT org_ai_connector_config_org_id_fkey FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE
);

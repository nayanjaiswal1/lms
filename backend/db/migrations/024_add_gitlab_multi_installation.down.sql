-- ═════════════════════════════════════════════════════════════════════════
-- Migration 024 — add_gitlab_multi_installation (rollback)
--
-- Restoring UNIQUE(org_id) only succeeds if every org still has at most one
-- gitlab_installations row at rollback time — if any org has connected a
-- second installation since this migration applied, delete/consolidate
-- those rows first or this rollback fails on the ADD CONSTRAINT below.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.gitlab_oauth_states
    DROP CONSTRAINT IF EXISTS gitlab_oauth_states_installation_fk,
    DROP COLUMN IF EXISTS installation_id,
    DROP COLUMN IF EXISTS name;

DROP TRIGGER IF EXISTS set_gitlab_org_config_updated_at ON public.gitlab_org_config;
DROP TABLE IF EXISTS public.gitlab_org_config;

ALTER TABLE public.project_assignments
    DROP CONSTRAINT IF EXISTS project_assignments_installation_fk,
    DROP COLUMN IF EXISTS installation_id;

DROP INDEX IF EXISTS public.gitlab_installations_org_default_uq;

ALTER TABLE public.gitlab_installations
    DROP CONSTRAINT IF EXISTS gitlab_installations_org_name_key,
    ADD CONSTRAINT gitlab_installations_org_key UNIQUE (org_id);

ALTER TABLE public.gitlab_installations
    DROP COLUMN IF EXISTS is_default,
    DROP COLUMN IF EXISTS name;

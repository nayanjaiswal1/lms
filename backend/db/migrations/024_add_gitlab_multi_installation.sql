-- ═════════════════════════════════════════════════════════════════════════
-- Migration 024 — add_gitlab_multi_installation
--
-- 023 gave each org exactly one gitlab_installations row (UNIQUE(org_id)),
-- used implicitly everywhere as "the org's GitLab". This migration lets an
-- org connect several named GitLab hosts (e.g. "GitLab.com" + a self-hosted
-- instance) and lets individual project_assignments pin themselves to a
-- specific one instead of always following the org default:
--
--   1. gitlab_installations gains name + is_default. UNIQUE(org_id) is
--      dropped in favor of UNIQUE(org_id, name); a partial unique index on
--      (org_id) WHERE is_default guarantees exactly one default per org.
--      Existing rows (one per org today) satisfy both with no backfill.
--   2. project_assignments gains installation_id, nullable — NULL means
--      "use the org's current default installation". ON DELETE RESTRICT:
--      an installation still pinned to a live assignment must not be
--      silently deleted out from under repos already provisioned against it.
--   3. gitlab_org_config: one boolean policy row per org
--      (allow_project_override) — mirrors the existing per-domain org
--      config pattern (lab_org_config, org_auth_config), reusing
--      public.set_updated_at() the same way lab_org_config does.
--   4. gitlab_oauth_states gains name + installation_id so a purpose=
--      'installation' OAuth round trip (admin leaves the app to consent on
--      GitLab, comes back to the callback route) can carry which pool entry
--      it's completing: installation_id set = updating that existing row;
--      NULL = creating a new one, using name (only meaningful on the create
--      path — updates keep the installation's existing name).
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.gitlab_installations
    ADD COLUMN name text DEFAULT 'Default'::text NOT NULL,
    ADD COLUMN is_default boolean DEFAULT true NOT NULL;

ALTER TABLE public.gitlab_installations
    DROP CONSTRAINT gitlab_installations_org_key,
    ADD CONSTRAINT gitlab_installations_org_name_key UNIQUE (org_id, name);

CREATE UNIQUE INDEX gitlab_installations_org_default_uq
    ON public.gitlab_installations (org_id)
    WHERE is_default;

ALTER TABLE public.project_assignments
    ADD COLUMN installation_id uuid,
    ADD CONSTRAINT project_assignments_installation_fk FOREIGN KEY (installation_id)
        REFERENCES public.gitlab_installations(id) ON DELETE RESTRICT;

CREATE TABLE public.gitlab_org_config (
    org_id uuid NOT NULL,
    allow_project_override boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_org_config_pkey PRIMARY KEY (org_id),
    CONSTRAINT gitlab_org_config_org_id_fkey FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE
);

CREATE TRIGGER set_gitlab_org_config_updated_at
    BEFORE UPDATE ON public.gitlab_org_config
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.gitlab_oauth_states
    ADD COLUMN name text,
    ADD COLUMN installation_id uuid,
    ADD CONSTRAINT gitlab_oauth_states_installation_fk FOREIGN KEY (installation_id)
        REFERENCES public.gitlab_installations(id) ON DELETE CASCADE;

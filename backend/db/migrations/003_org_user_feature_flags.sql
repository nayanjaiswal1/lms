-- ══════════════════════════════════════════════════════════════════════════
-- 003_org_user_feature_flags.sql
-- Generic feature-flag admin surface, replacing the hardcoded on/off lists
-- in internal/features/service.go with DB-backed overrides:
--   - org_feature_flags:  platform admin (super_admin) turns a feature on/off
--                         for an entire org.
--   - user_feature_flags: org admin (owner/admin org role) turns a feature
--                         on/off for one member, scoped to features the org
--                         itself already has enabled.
-- A missing row means "use the code default" — see Service.Resolve, which
-- keeps every org/user behaving exactly as before until an admin explicitly
-- overrides a key.
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE public.org_feature_flags (
    org_id      uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    feature_key text NOT NULL,
    enabled     boolean NOT NULL,
    updated_by  uuid NOT NULL REFERENCES public.users(id),
    updated_at  timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_feature_flags_pkey PRIMARY KEY (org_id, feature_key)
);

CREATE TABLE public.user_feature_flags (
    org_id      uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    feature_key text NOT NULL,
    enabled     boolean NOT NULL,
    updated_by  uuid NOT NULL REFERENCES public.users(id),
    updated_at  timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_feature_flags_pkey PRIMARY KEY (org_id, user_id, feature_key)
);

CREATE INDEX user_feature_flags_org_user_idx ON public.user_feature_flags (org_id, user_id);

-- "features.what_now" is read by Repo.GrantedFeatureKeys/EntitledUserIDs and
-- referenced in comments throughout internal/features as the precedent
-- "features.revision_digest" followed (see 002_revision_digest.sql), but the
-- permission row itself was never seeded — no admin could ever grant it.
INSERT INTO public.permissions (code, name, module, is_active)
VALUES ('features.what_now', 'What Now? (beta)', 'features', true)
ON CONFLICT (code) DO NOTHING;

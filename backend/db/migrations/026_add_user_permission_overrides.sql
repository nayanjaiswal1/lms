-- ═════════════════════════════════════════════════════════════════════════
-- Migration 026 — user_permission_overrides
-- RBAC previously resolved permissions only through roles (user_roles →
-- role_permissions → permissions) — "roles are bags of permissions, nothing
-- more" (docs/rbac.md §1). Admins now need to grant a single permission
-- straight to a user without creating or editing a role for it. This adds a
-- parallel, audited override table that GetEffectivePermissions unions
-- alongside the role-based result — role resolution itself is untouched.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.user_permission_overrides (
    user_id       uuid NOT NULL,
    tenant_id     uuid NOT NULL,
    permission_id uuid NOT NULL,
    granted_by    uuid,
    granted_at    timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_permission_overrides_pkey PRIMARY KEY (user_id, tenant_id, permission_id),
    CONSTRAINT user_permission_overrides_user_fkey FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT user_permission_overrides_tenant_fkey FOREIGN KEY (tenant_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT user_permission_overrides_permission_fkey FOREIGN KEY (permission_id)
        REFERENCES public.permissions(id) ON DELETE RESTRICT,
    CONSTRAINT user_permission_overrides_granted_by_fkey FOREIGN KEY (granted_by)
        REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE INDEX idx_user_permission_overrides_user_tenant
    ON public.user_permission_overrides (user_id, tenant_id);

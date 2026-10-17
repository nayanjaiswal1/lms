# Organizations

Everything about organization management, membership, roles, and the org-invite flow.

---

## Overview

An org is a tenant — a college, bootcamp, or company. Each org has its own members, courses, wiki spaces, and auth configuration. A user can belong to multiple orgs with different roles in each.

Org roles: `admin` · `instructor` · `mentor` · `student`

---

## API Endpoints

```
POST   /api/orgs                    (super_admin) create org
GET    /api/orgs/:slug              org detail

PATCH  /api/orgs/:id                       (admin.manage_org) update org
POST   /api/orgs/:id/activate              (owner label) activate org
PATCH  /api/orgs/:id/onboarding            (admin.manage_org)
GET|PATCH /api/orgs/:id/auth-config        (admin.manage_org)
GET|PATCH /api/orgs/:id/ai-connector-config (admin.manage_org)
*      /api/orgs/:id/domains/...           (admin.manage_org)
*      /api/orgs/:id/invites/...           (admin.manage_members) → see auth.md for invite flow
GET    /api/orgs/:id/members               (admin.manage_members)
DELETE /api/orgs/:id/members/:memberID     (admin.manage_members) remove member
PATCH  /api/orgs/:id/members/:memberID     (admin.manage_members) body: {role} — change member role
                                           → bumps session_version for the affected user on demotion/removal
GET    /api/admin/rbac/audit               (admin.view_audit_log; org-scoped by the caller's token org — the former /api/orgs/:id/audit-logs was removed, see docs/rbac.md Audit Log)
```

Every permission above is checked in the `:id` org (`authz.RequireOrgCtxPermission`, after `RequireOrgMember`), not the org the caller's token is switched to. Invite/role-change/remove additionally apply the `OrgRoleRank` label ceiling (an actor cannot grant or manage a label at or above their own; owners are exempt).

Every membership insert or role change also assigns the RBAC system role mapped from the label (`owner`/`admin` → `tenant_admin`, `instructor`, `mentor`, `learner` → `member`) in the same transaction via `sysrole.Sync`; removal revokes all of the member's roles in the org. Permissions come only from `user_roles` — see `rbac.md` §`user_roles`.

Auth config endpoints are in `auth.md`.

---

## Database Schema

```sql
organizations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  slug       TEXT NOT NULL UNIQUE,
  logo_url   TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
)

org_members (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id    UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'student',  -- 'admin' | 'instructor' | 'mentor' | 'student'
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (org_id, user_id)
)

org_settings (
  org_id    UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  auth      JSONB DEFAULT '{}',          -- AuthSettings namespace
  ai_connector JSONB DEFAULT '{}',       -- AIConnectorSettings namespace
  jobs      JSONB DEFAULT '{}',          -- JobsSettings namespace
  gitlab    JSONB DEFAULT '{}',          -- GitlabSettings namespace
  labs      JSONB DEFAULT '{}',          -- LabsSettings namespace
  session_booking JSONB DEFAULT '{}',    -- SessionBookingSettings namespace
  updated_at TIMESTAMPTZ DEFAULT now()
)
```

## Org Settings Namespaces

All org configuration is stored as JSONB in the `org_settings` table, organized by namespace. Each namespace has a Go struct with sensible zero-value defaults when the column is empty.

| Namespace | Fields | Purpose |
|---|---|---|
| `auth` | sso_enabled, oidc_issuer_url, oidc_client_id, saml_metadata_xml | SSO/OIDC/SAML configuration |
| `ai_connector` | enabled | AI Connector feature toggle and settings |
| `jobs` | max_concurrent_jobs, queued_job_ttl_minutes, active_job_timeout_hrs | Lab and project job limits |
| `gitlab` | allow_project_override | GitLab integration settings |
| `labs` | max_concurrent_sessions, max_session_duration, allowed_images, egress_proxy_enabled, debug_ui (`old` default / `new`) | Lab sandboxing and execution limits; `debug_ui` picks the debug lab workspace (Org settings > Labs, `admin.manage_org`, `GET/PATCH /api/admin/labs/settings`; see `docs/debug-labs.md` "Mission UI") |
| `session_booking` | enabled, credits_per_session, cancellation_window, feedback_required, min/max_session_duration_mins | Mentor session booking configuration |

Accessor pattern: `orgs.Repo.GetAuthSettings(ctx, orgID)`, etc. — never raw SQL. Zero-value structs are returned when the namespace column is empty, enabling front-end defaults to apply without special-casing.

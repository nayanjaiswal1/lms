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

POST   /api/orgs/:id/members        (org_admin) invite member by email → see auth.md for invite flow
DELETE /api/orgs/:id/members/:uid   (org_admin) remove member
PATCH  /api/orgs/:id/members/:uid   (org_admin) body: {role} — change member role
                                    → bumps session_version for the affected user on demotion/removal
```

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
| `labs` | max_concurrent_sessions, max_session_duration, allowed_images, egress_proxy_enabled | Lab sandboxing and execution limits |
| `session_booking` | enabled, credits_per_session, cancellation_window, feedback_required, min/max_session_duration_mins | Mentor session booking configuration |

Accessor pattern: `orgs.Repo.GetAuthSettings(ctx, orgID)`, etc. — never raw SQL. Zero-value structs are returned when the namespace column is empty, enabling front-end defaults to apply without special-casing.

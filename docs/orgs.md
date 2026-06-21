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
  plan       TEXT NOT NULL DEFAULT 'free',  -- 'free' | 'pro' | 'enterprise'
  logo_url   TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
)

org_members (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id    UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'student',  -- 'admin' | 'instructor' | 'mentor' | 'student'
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (org_id, user_id)
)
```

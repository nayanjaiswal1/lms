# RBAC — Role-Based Access Control

> Single source of truth for MindForge's permission system.
> Every design decision, file path, API contract, and extension recipe is here.
> Read this before touching anything permission-related.

---

## Contents

1. [Design Principles](#1-design-principles)
2. [Database Schema](#2-database-schema)
3. [Seed Data — Permissions & System Roles](#3-seed-data--permissions--system-roles)
4. [Backend Go Engine](#4-backend-go-engine)
5. [API Endpoints](#5-api-endpoints)
6. [Frontend Infrastructure](#6-frontend-infrastructure)
7. [Admin UI Pages](#7-admin-ui-pages)
8. [Navigation & Sidebar](#8-navigation--sidebar)
9. [Cache Lifecycle](#9-cache-lifecycle)
10. [Multi-Tenant Scoping Rules](#10-multi-tenant-scoping-rules)
11. [How To — Recipes for Common Changes](#11-how-to--recipes-for-common-changes)

---

## 1. Design Principles

**Every access check is permission-code-based — role names never appear in application code.**

A user's effective permissions are the union of all permissions granted through all roles assigned to them within a given tenant. The system never checks `role.name == "admin"`. It checks `user has permission "admin.manage_roles"`.

| Rule | Why |
|---|---|
| Roles are bags of permissions, nothing more | Adding a new role costs zero code changes |
| Permission codes never change once seeded | They are referenced in code, tests, and audit logs |
| System roles are immutable (`is_editable=false`) | Tenants cannot modify the platform's built-in defaults |
| Tenant-owned roles are isolated to their org at the DB level | A trigger enforces this — no application code can bypass it |
| Cross-tenant probing returns identical 404 | No existence leakage about other orgs' roles |
| Cache always comes from Redis; DB is always authoritative | A Redis failure falls through to the DB, never blocks the request |

**One deliberate exception to "roles are bags of permissions":** `user_permission_overrides` (§2) lets an admin grant a single permission straight to a user, bypassing roles, for a one-off case that doesn't warrant creating or editing a role. It is a parallel table the `effective_permissions` view unions in — role resolution itself is untouched — and every grant/revoke is audited (`user.permission.grant` / `user.permission.revoke`) and cache-invalidated exactly like a role assignment. Prefer a role for anything recurring; reach for an override only for genuine one-offs.

---

## 2. Database Schema

**Migration file:** `mindforge/backend/db/migrations/001_baseline.sql`
**Down file:** `mindforge/backend/db/migrations/001_baseline.down.sql`

### `permissions`

Global table. No `org_id`. Permissions are a platform vocabulary — tenants cannot create new codes.

```sql
id          UUID  PRIMARY KEY
code        TEXT  UNIQUE          -- e.g. "courses.view"
name        TEXT                  -- human label
description TEXT
module      TEXT                  -- grouping: courses | assessments | practice | mentoring | content | admin
is_active   BOOLEAN DEFAULT true
created_at, updated_at TIMESTAMPTZ
```

Index: `idx_permissions_module ON permissions(module, is_active)`

### `roles`

```sql
id          UUID  PRIMARY KEY
org_id   UUID  REFERENCES organizations(id) ON DELETE CASCADE  -- NULL for system roles
name        TEXT
description TEXT
is_system   BOOLEAN DEFAULT false
is_editable BOOLEAN DEFAULT true
is_active   BOOLEAN DEFAULT true
created_at, updated_at TIMESTAMPTZ
```

**Key constraints:**
- `roles_system_org_biconditional CHECK`: `(is_system=true AND org_id IS NULL) OR (is_system=false AND org_id IS NOT NULL)` — these two states are the only valid combinations.
- `UNIQUE NULLS NOT DISTINCT (org_id, name)` — system roles share a global namespace; tenant roles share per-org namespace. (Requires PostgreSQL 15+.)

Index: `idx_roles_org_active ON roles(org_id, is_active)`

### `role_permissions`

```sql
role_id       UUID REFERENCES roles(id)       ON DELETE CASCADE
permission_id UUID REFERENCES permissions(id) ON DELETE RESTRICT
PRIMARY KEY (role_id, permission_id)
```

`ON DELETE RESTRICT` on `permission_id` means you cannot delete a permission that is actively assigned to any role.

### `user_roles`

```sql
user_id   UUID REFERENCES users(id)         ON DELETE CASCADE
role_id   UUID REFERENCES roles(id)         ON DELETE RESTRICT
org_id UUID REFERENCES organizations(id) ON DELETE CASCADE
PRIMARY KEY (user_id, role_id, org_id)
```

`org_id` is always set (never NULL). This is the **authoritative grant scope** — a system role assigned here only grants access within this tenant.

**Single source of access.** `user_roles` (plus `user_permission_overrides`) is the only input to permission resolution; `org_members.role` is a label. Every write of that label goes through one writer, `sysrole.Sync` (`backend/internal/authz/sysrole`), in the same transaction as the `org_members` insert/update: org create, org-invite join, member role change, password and social signup, `auth.FindOrCreateUserByEmail` (calendar invites), and batch-invitation accept. Mapping: `owner`/`admin` → `tenant_admin`, `instructor` → `instructor`, `mentor` → `mentor`, `learner` → `member`. On a label change it revokes only the role mapped from the old label (owner ↔ admin keeps `tenant_admin`) and never touches extra roles granted through the RBAC admin. Inserts that hit an existing membership (`ON CONFLICT DO NOTHING`) leave its roles alone. Removal deletes every `user_roles`/override row for the org in the removal transaction. Callers flush the Redis permission cache after commit. Migration `008_rbac_membership_backfill` granted the mapped role to existing active/suspended staff missing it and `member` to learners with no role at all; its rows are tracked in `rbac_backfill_008` so the down migration removes exactly those.

**Trigger:** `trg_user_role_org_scope` (function: `fn_check_user_role_org_scope`) fires BEFORE INSERT OR UPDATE. It rejects any attempt to assign a tenant-owned role under a different tenant's `org_id`. System roles (role's `org_id IS NULL`) pass unconditionally.

Indexes:
- `idx_user_roles_user_org ON user_roles(user_id, org_id)` — permission resolution
- `idx_user_roles_role ON user_roles(role_id)` — cache invalidation on role change

### `user_permission_overrides`

**Introduced by:** migration `026_add_user_permission_overrides.sql` (now folded into `001_baseline.sql` — migrations `002`–`027` were squashed 2026-07-30).

Direct per-user permission grants that bypass roles entirely — see the design-principle callout in §1 for why this exists.

```sql
user_id       UUID REFERENCES users(id)         ON DELETE CASCADE
org_id     UUID REFERENCES organizations(id) ON DELETE CASCADE
permission_id UUID REFERENCES permissions(id)   ON DELETE RESTRICT
granted_by    UUID REFERENCES users(id)         ON DELETE SET NULL  -- nullable
granted_at    TIMESTAMPTZ DEFAULT now()
PRIMARY KEY (user_id, org_id, permission_id)
```

No tenant-scope trigger (unlike `user_roles`): `permissions` has no `org_id` at all — it's a global vocabulary — so there's no tenant-mismatch case to guard against. The `effective_permissions` view (below) `UNION`s this table with the role-resolution join; nothing else in the resolution/cache layer changes.

Index: `idx_user_permission_overrides_user_tenant ON user_permission_overrides(user_id, org_id)`

### `effective_permissions` (view)

**Introduced by:** migration `009_staff_permission_codes.sql`.

The single definition of "user U holds code C in org O" — columns `(user_id, org_id, code)`:

```sql
SELECT ur.user_id, ur.org_id, p.code
FROM user_roles ur
JOIN roles r            ON r.id = ur.role_id AND r.is_active
JOIN role_permissions rp ON rp.role_id = r.id
JOIN permissions p      ON p.id = rp.permission_id AND p.is_active
JOIN org_members om     ON om.org_id = ur.org_id AND om.user_id = ur.user_id AND om.status = 'active'
UNION
SELECT upo.user_id, upo.org_id, p.code
FROM user_permission_overrides upo
JOIN permissions p  ON p.id = upo.permission_id AND p.is_active
JOIN org_members om ON om.org_id = upo.org_id AND om.user_id = upo.user_id AND om.status = 'active'
```

Every reader goes through it: `authz.Repo.GetEffectivePermissions` (per-user, behind the Redis cache), `authz.Repo.OrgPermissionHolders` / `Service.OrgPermissionHolders` (recipient lists: lab circuit-breaker and ops alerts → `admin.manage_org`; mentor escalations → `mentoring.claim_tickets` / `mentoring.assign_tickets`; ticket staff emails → the ticket kind's manage code), `courses.Repo.IsOrgStaff` (`courses.edit`), and `auth`'s MFA-mandatory check (`admin.manage_org` or `admin.manage_roles` in any org — `auth` cannot import `authz`, so it queries the view directly). Never re-join `user_roles → role_permissions` by hand: those copies skipped overrides, `is_active` and suspended memberships.

### `audit_log`

```sql
id          UUID  PRIMARY KEY
org_id   UUID  REFERENCES organizations(id) ON DELETE SET NULL
actor_id    UUID  REFERENCES users(id)         ON DELETE SET NULL
action      TEXT          -- e.g. "role.create", "user.role.assign"
entity_type TEXT          -- "role" | "user"
entity_id   TEXT          -- UUID as string
diff        JSONB         -- {"before": {...}, "after": {...}}
created_at  TIMESTAMPTZ
```

Indexes:
- `idx_audit_log_tenant_created ON audit_log(org_id, created_at DESC)` — fast pagination
- `idx_audit_log_entity ON audit_log(entity_type, entity_id)` — look up history for one entity

---

## 3. Seed Data — Permissions & System Roles

**Migration file:** `mindforge/backend/db/migrations/001_baseline.sql`
**Down file:** `mindforge/backend/db/migrations/001_baseline.down.sql`

All inserts use `ON CONFLICT DO NOTHING` — safe to re-run.

### Permission Catalogue

The count below drifts every time a permission is added — treat it as a snapshot, not a contract. For the exhaustive, current list, grep `INSERT INTO public.permissions` across `backend/db/migrations/*.sql` (55 codes from `001_baseline.sql`, +4 in 009, −2 in 010, which deletes the dead `content.interview_board` / `content.load_test`: 57 as of 2026-10-17). `content.sheets`, `content.diary`, `content.captures`, `content.learning_journal`, `projects.create`, `projects.oversee` are also live codes (see the matrix below).

| Module | Code | Name |
|---|---|---|
| courses | `courses.view` | View Courses |
| courses | `courses.enroll` | Enroll in Courses |
| courses | `courses.create` | Create Courses |
| courses | `courses.edit` | Edit Courses |
| courses | `courses.publish` | Publish Courses |
| courses | `courses.delete` | Delete Courses |
| courses | `courses.view_analytics` | Course Analytics (enforced via `authz.RequirePermission` on `/api/courses/{id}/analytics*` and `/api/analytics/*`; see [analytics.md](analytics.md)) |
| assessments | `assessments.take` | Take Assessments |
| assessments | `assessments.view_assigned` | View Assigned Tests |
| assessments | `assessments.create` | Create Assessments |
| assessments | `assessments.edit` | Edit Assessments |
| assessments | `assessments.publish` | Publish Assessments |
| assessments | `assessments.delete` | Delete Assessments |
| assessments | `assessments.view_results` | View Results |
| assessments | `assessments.manage_questions` | Manage Question Bank |
| assessments | `assessments.manage_batches` | Manage Batches |
| practice | `practice.use` | Use AI Practice |
| mentoring | `mentoring.chat` | Mentor Chat |
| mentoring | `mentoring.manage_batches` | Manage Mentor Batches |
| mentoring | `mentoring.view_students` | View Student Progress |
| mentoring | `mentoring.assign_tickets` | Assign Mentor Tickets |
| mentoring | `mentoring.manage_reports` | Manage Mentor Reports |
| mentoring | `mentoring.verify_mentors` | Verify Mentors |
| mentoring | `mentoring.manage_session_booking` | Manage Session Booking |
| mentoring | `mentoring.view_tickets` | View Mentor Tickets |
| content | `content.wiki` | Wiki |
| content | `content.system_design` | System Design |
| content | `content.sheets` | Sheet Tracker |
| content | `content.srs` | Review Cards |
| content | `content.certificates` | Certificates |
| content | `content.interview_exp` | Interview Experiences |
| admin | `admin.view_members` | View Members |
| admin | `admin.manage_members` | Manage Members |
| admin | `admin.manage_roles` | Manage Roles |
| admin | `admin.manage_permissions` | Manage Permissions |
| admin | `admin.view_audit_log` | View Audit Log |
| admin | `admin.manage_org` | Manage Organisation |
| payments | `payments.manage_coupons` | Manage Coupons |
| payments | `payments.manage_refunds` | Issue Refunds |
| calendar | `calendar.events.manage` | Manage Calendar Events |
| labs | `labauthor.compose` | Compose Lab Recipes (block library, recipes, validation, AI ticket drafts; instructor + tenant_admin, migration 047) |
| labs | `labauthor.manage_blocks` | Manage Lab Text Blocks (org-owned ticket/hints/rubric/preset blocks; instructor + tenant_admin, migration 047) |
| projects | `projects.view` | View Projects |
| projects | `projects.manage` | Manage Projects |
| support | `support.manage` | Manage Support Tickets |
| moderation | `content.moderate` | Moderate Content Reports (also: delete any wiki space/page/comment/template — tenant_admin only) |
| messaging | `messaging.moderate` | Moderate Messaging — resolve/pin/promote/delete any batch message, reorder FAQs, read every batch conversation (instructor, mentor, tenant_admin; migration 009) |
| content | `wiki.manage_spaces` | Manage Wiki Content — read every course space, see drafts, create pages and templates, edit own pages (instructor, mentor, tenant_admin; migration 009) |
| content | `wiki.create_spaces` | Create Wiki Spaces (instructor, tenant_admin; migration 009) |
| mentoring | `mentoring.claim_tickets` | Claim Mentor Tickets — self-claim from the queue; holders also receive mentor escalation emails (mentor only; migration 009) |
| features | `features.revision_digest`, `features.what_now` | Beta-flagged tools — seeded as permission rows but currently gated through the separate org/user feature-flag system (`frontend/CLAUDE.md`'s Feature Flags section), not granted to any role via `role_permissions`. Not a bug; just a different gating mechanism sharing this table. |

### System Roles (fixed UUIDs — never change these)

| UUID | Name | Description |
|---|---|---|
| `11111111-1111-1111-1111-000000000001` | `viewer` | Read-only access to published content |
| `11111111-1111-1111-1111-000000000002` | `member` | Standard learner — courses, practice, tools |
| `11111111-1111-1111-1111-000000000003` | `instructor` | Course and assessment author |
| `11111111-1111-1111-1111-000000000004` | `mentor` | Mentoring and batch supervision |
| `11111111-1111-1111-1111-000000000005` | `tenant_admin` | Full organisation administration |
| `11111111-1111-1111-1111-000000000006` | `support_agent` | Support ticket queue — view, reply, triage, and get notified |

### System Role → Permissions

Snapshot as of migration `010_role_matrix_cleanup.sql` (2026-10-17). The source of truth is the golden file `backend/internal/authz/testdata/role_matrix.golden.json`, checked by `TestSystemRoleMatrix_Golden` against a fully migrated database: any migration that changes a system-role grant fails that test until the golden (regenerate with `UPDATE_GOLDEN=1 go test -run TestSystemRoleMatrix_Golden ./internal/authz`) and this section are updated.

Learner codes = `practice.use`, `content.srs`, `content.sheets`, `content.learning_journal`, `content.diary`, `content.captures`, `content.interview_exp`, `content.certificates`.

**viewer (1):** `courses.view`. (`projects.view` removed in 010.)

**member (16):** `courses.view`, `courses.enroll`, `assessments.take`, `assessments.view_assigned`, `mentoring.chat`, `content.wiki`, `content.system_design`, `projects.view`, plus all learner codes.

**instructor:** all member codes, plus `courses.create/edit/publish/delete/view_analytics`, `assessments.create/edit/publish/delete/view_results/manage_questions/manage_batches`, `admin.view_members`, `mentoring.assign_tickets`, `mentoring.verify_mentors`, `mentoring.manage_session_booking`, `mentoring.view_tickets`, `labauthor.compose`, `labauthor.manage_blocks`, `projects.create`, `projects.manage`, `messaging.moderate`, `wiki.manage_spaces`, `wiki.create_spaces`.

**mentor:** all member codes, plus `assessments.view_results`, `mentoring.manage_batches`, `mentoring.view_students`, `mentoring.view_tickets`, `mentoring.claim_tickets`, `messaging.moderate`, `wiki.manage_spaces`, `admin.view_members`, `projects.create`. Does **not** include `support.manage` — see `docs/support-ticket-rbac-decision.md` (support ticket access moved to the dedicated `support_agent` role). Holds none of the assessment/batch authoring codes, so assessment results routes scope a mentor to the batches they mentor (scoping is lifted only by `assessments.manage_batches`).

**support_agent (1):** `support.manage` only — view the support ticket queue, reply, triage (category/priority/status), and receive ticket email notifications.

**tenant_admin:** every code except the learner codes and `mentoring.claim_tickets` — i.e. all `admin.*`, `payments.*` (`payments.manage_coupons` is tenant_admin-only by default; the RBAC admin UI can grant it to instructor at runtime), `support.manage`, `content.moderate`, `calendar.events.manage`, `projects.view/create/manage/oversee`, the instructor and mentor staff codes, and `courses.view`, `courses.enroll`, `assessments.take`, `assessments.view_assigned`, `mentoring.chat`, `content.wiki`, `content.system_design`. Migration 010 removed the learner codes: an owner/admin who also learns holds the `member` role alongside `tenant_admin` (010 backfilled it for every owner/admin with learner activity in the org, tracked in `rbac_backfill_010`). Staff flows that used to ride on `practice.use` now accept the authoring code instead: starting a lab session and the lab catalog (`/api/labs/{id}/sessions`, `/api/labs/catalog`) require `practice.use` **or** `courses.edit`. `courses.enroll` is kept (no route enforces it; enrolling to preview a course is an admin action).

`features.revision_digest` and `features.what_now` are granted to no system role (feature-flag gated, see the catalogue).

---

## 4. Backend Go Engine

**Package:** `github.com/mindforge/backend/internal/authz`
**Directory:** `mindforge/backend/internal/authz/`

### Files

| File | Purpose |
|---|---|
| `types.go` | All structs: `Permission`, `Role`, `AuditEntry`, `UserRoleAssignment`, request/param types |
| `repo.go` | `Repo` — permission resolution query + role assignment lookup |
| `cache.go` | `Cache` — Redis get/set/invalidate with pub/sub |
| `service.go` | `Service` — cache-aside composition, `Has*Permission` helpers, `InvalidateForRoleChange` |
| `middleware.go` | `RequirePermission`, `RequireAnyPermission` Chi middleware constructors |
| `admin_repo.go` | `AdminRepo` — full CRUD for permissions, roles, role-permissions, user-roles |
| `audit_repo.go` | `AuditRepo` — `Write` and `List` for the audit log |
| `admin_service.go` | `AdminService` — wraps `AdminRepo` with audit writes and cache invalidation |
| `handler.go` | `Handler` — wires all deps; helpers `getClaims`, `decodeJSON`, `queryInt/String/BoolPtr` |
| `handler_me.go` | `HandleGetMyPermissions` — current user's own permission list |
| `handler_admin.go` | 13 admin handler functions |
| `routes.go` | `RegisterRoutes` — mounts all routes onto a Chi router |
| `service_test.go` | 13 unit tests using stub types |

### Key Types (`types.go`)

```go
type Permission struct {
    ID, Code, Name, Description, Module string
    IsActive                            bool
    CreatedAt, UpdatedAt                time.Time
}

type Role struct {
    ID          string
    TenantID    *string   // nil for system roles
    Name        string
    Description string
    IsSystem    bool
    IsEditable  bool
    IsActive    bool
    CreatedAt, UpdatedAt time.Time
}

type AuditEntry struct {
    ID         string
    TenantID   *string
    ActorID    *string
    Action     string    // e.g. "role.create"
    EntityType string    // "role" | "user"
    EntityID   string
    Diff       json.RawMessage
    CreatedAt  time.Time
}
```

### Permission Resolution (`repo.go` → `service.go`)

`SELECT code FROM effective_permissions WHERE user_id = $1 AND org_id = $2` — the view (§2) applies the role/override union and the active-role, active-permission and active-membership filters.

Returns `[]string{}` (not nil) when the user has no permissions.

`Repo.OrgPermissionHolders(ctx, orgID, code) []userID` (exposed as `Service.OrgPermissionHolders`, uncached) answers the reverse question for recipient lists. Background job handlers that only hold a pool call `authz.NewRepo(pool).OrgPermissionHolders` — `Repo` is stateless over the pool.

### Cache (`cache.go`)

```
Redis key:  rbac:perms:{tenantID}:{userID}
TTL:        5 minutes
Value:      JSON array of permission code strings

On invalidate:
  1. DEL rbac:perms:{tenantID}:{userID}
  2. PUBLISH rbac:invalidate "{tenantID}:{userID}"
```

`Service.GetEffectivePermissions` flow:
1. `Cache.Get` — returns codes on hit; nil on miss; logs but continues on Redis error
2. On miss: `Repo.GetEffectivePermissions` from DB
3. `Cache.Set` — back-fills cache; Redis write failure is logged, not returned

### Middleware (`middleware.go`)

```go
// Require ALL codes — 401 if unauthenticated, 403 if any code missing
RequirePermission(svc *Service, codes ...string) func(http.Handler) http.Handler

// Require AT LEAST ONE code — 401 if unauthenticated, 403 if none held
RequireAnyPermission(svc *Service, codes ...string) func(http.Handler) http.Handler

// Require code in the org RequireOrgMember resolved — and only there
RequireOrgCtxPermission(svc *Service, code string) func(http.Handler) http.Handler
```

Claims are read from context via `auth.GetClaims(r.Context())`. `RequirePermission`/`RequireAnyPermission` check `claims.OrgID`; when `middleware.RequireOrgMember` ran earlier in the chain and resolved a **different** org (URL `{id}` or `X-Org-Id`), the codes must hold there too — handlers behind these guards write with `claims.OrgID` but may read the resolved org, so an admin of org A cannot act on org B where they hold less. `RequireOrgCtxPermission` is for route groups whose handlers act only on the resolved org (`/api/orgs/{id}/...` settings, members, invites, audit log, per-member feature flags): it checks that org alone, so a user may administer any org they administer regardless of which org their token is currently switched to.

For a check that changes what a handler returns rather than gating the route (drafts view, mentor scoping, wiki `Access`), call `svc.HasPermission(ctx, claims.UserID, claims.OrgID, code)` in the handler; never compare `claims.OrgRole` or `org_members.role`.

### Wiring into Router (`mindforge/backend/internal/api/router.go`)

```go
authzHandler := authz.New(pool, rdb)
authzHandler.RegisterRoutes(r)  // inside the protected group
```

`authz.New(pool, rdb)` builds the full dependency graph internally:
`Repo` + `Cache` → `Service` → `AdminRepo` + `AuditRepo` + `AdminService` → `Handler`

### AdminService mutations (`admin_service.go`)

Every mutation follows this pattern:
1. Validate tenant ownership / system-role protection
2. `adminRepo.*` — DB write inside a transaction (with `SELECT FOR UPDATE` on the role row)
3. `auditRepo.Write` — append audit entry (best-effort, failure not returned)
4. `svc.InvalidateForRoleChange` or `svc.InvalidateUser` — bust Redis cache

Audit action codes written:

| Method | Action written |
|---|---|
| `CreateRole` | `role.create` |
| `UpdateRole` | `role.update` |
| `DisableRole` | `role.disable` |
| `SetRolePermissions` | `role.permissions.set` |
| `AssignRole` | `user.role.assign` |
| `RevokeRole` | `user.role.revoke` |

---

## 5. API Endpoints

All routes require the standard `RequireAuth` + `RequireCSRF` middlewares applied by the router. The per-route permission guards listed below are additional.

### Public (to authenticated user)

| Method | Path | Guard | Handler |
|---|---|---|---|
| GET | `/api/me/permissions` | auth only | `HandleGetMyPermissions` |

**Response:**
```json
{ "data": { "permissions": ["courses.view", "practice.use", "..."] } }
```

### Admin RBAC

Base path: `/api/admin/rbac/`

#### Permission Catalogue

| Method | Path | Required permission (any) |
|---|---|---|
| GET | `/api/admin/rbac/permissions` | `admin.manage_roles` OR `admin.manage_permissions` OR `admin.view_audit_log` OR `admin.view_members` |

Query params: `module`, `active` (bool), `limit`, `offset`

#### Roles

| Method | Path | Required permission |
|---|---|---|
| GET | `/api/admin/rbac/roles` | `admin.manage_roles` OR `admin.manage_permissions` |
| POST | `/api/admin/rbac/roles` | `admin.manage_roles` (all) |
| GET | `/api/admin/rbac/roles/{roleID}` | `admin.manage_roles` OR `admin.manage_permissions` |
| PUT | `/api/admin/rbac/roles/{roleID}` | `admin.manage_roles` (all) |
| DELETE | `/api/admin/rbac/roles/{roleID}` | `admin.manage_roles` (all) — soft-disable |
| GET | `/api/admin/rbac/roles/{roleID}/permissions` | `admin.manage_roles` OR `admin.manage_permissions` |
| PUT | `/api/admin/rbac/roles/{roleID}/permissions` | `admin.manage_permissions` (all) |

#### User-Role Management

| Method | Path | Required permission |
|---|---|---|
| GET | `/api/admin/rbac/users/{userID}/roles` | `admin.manage_members` OR `admin.view_members` |
| POST | `/api/admin/rbac/users/{userID}/roles` | `admin.manage_members` (all) |
| DELETE | `/api/admin/rbac/users/{userID}/roles/{roleID}` | `admin.manage_members` (all) |
| GET | `/api/admin/rbac/users/{userID}/permissions` | `admin.manage_members` OR `admin.view_members` |

#### User-Permission Overrides

Direct per-user grants that bypass roles (§1, §2). The write guard is deliberately stricter than plain role assignment — granting skips the curation a role provides, so **both** codes are required, not just `admin.manage_members`.

| Method | Path | Required permission |
|---|---|---|
| GET | `/api/admin/rbac/users/{userID}/permission-overrides` | `admin.manage_members` OR `admin.view_members` |
| POST | `/api/admin/rbac/users/{userID}/permission-overrides` | `admin.manage_members` AND `admin.manage_permissions` (all) |
| DELETE | `/api/admin/rbac/users/{userID}/permission-overrides/{permissionID}` | `admin.manage_members` AND `admin.manage_permissions` (all) |

POST body: `{ "permission_id": "<uuid>" }`

#### Audit Log

| Method | Path | Required permission |
|---|---|---|
| GET | `/api/admin/rbac/audit` | `admin.view_audit_log` (all) |

Query params: `entity_type`, `entity_id`, `limit`, `offset`

This is the single audit-log endpoint (org-scoped to the token's org): `/org/settings/audit-log` and the Audit tab on `/users/[id]` both read it. The older `GET /api/orgs/{id}/audit-logs` (cursor pagination) was removed; `/admin/rbac/audit` has no page of its own.

Response: `{entries, total}`; each entry is `{id, org_id, org_name, actor_id, actor_name, actor_email, action, entity_type, entity_id, diff, ip_address, created_at}`. `org_name` joins `organizations`; `ip_address` is `host(audit_logs.ip_address)`, set by the orgs domain's audit writer (member/invite/settings actions) and `null` for RBAC-admin writes, which do not record it. `audit_logs` has no user-agent column, so none is returned.

#### Other permission-gated reads outside `/api/admin/rbac`

| Method | Path | Rule |
|---|---|---|
| GET | `/api/profile/user/{userID}` | Self always. Anyone else: `admin.manage_members` in the caller's token org (owner and admin both hold it through `tenant_admin`), and the target must be an active member of that org, else 404. Instructor/mentor/learner get 403, as before. Resolved by the handler through `authz.Service.HasPermission` and passed to `profile.Service.GetUserProfile` as a bool. |
| GET | `/api/assessments/grading-queue?limit=10` (1-50) | `assessments.view_results`. Callers without `assessments.manage_batches` (mentors) see only attempts by members of batches they mentor. → `{total, limit, items[] {attempt_id, assessment_id, assessment_title, user_id, user_name, status, submitted_at, ungraded_answers}}`, oldest first. See [learning.md](learning.md#api-endpoints). |
| GET | `/api/interview/review-queue?limit=50&offset=0` | `assessments.view_results`. Same mentor scope as the grading queue: callers without `assessments.manage_batches` see only flagged attempts by members of batches they mentor (none if they mentor no batch). |
| GET | `/api/analytics/courses?mine=true` | `courses.view_analytics`. `mine=true` limits the org course summary to courses the caller created (`courses.creator_id`). → `{courses, total, limit, offset, mine}`. See [analytics.md](analytics.md#api). |
| GET | `/api/content-reports/counts` | `content.moderate` → `{counts {pending, reviewing, removed, dismissed}, open}` (`open` = pending + reviewing). |
| GET | `/api/admin/labs/usage?days=30&student_limit=50` | `admin.manage_org` (existing endpoint; the dashboard reuses it) → `{window_days, org, by_course[], by_student[]}`. See [labs.md](labs.md). |

#### MCP (AI Connector) tools

`POST /mcp` tools enforce the same permission codes as their REST equivalents: every tool declares `Permission` beside its registration, and one gate checks the caller's effective permissions in the token's org on `tools/call` and filters `tools/list`. The full tool → code table is in [ai-connector.md](ai-connector.md#permission-gate-rbac).

### Response envelope

All responses use the standard MindForge envelope:
```json
{ "data": { ... } }        // success
{ "error": "message" }     // failure
```

---

## 6. Frontend Infrastructure

### Permission Codes (`mindforge/frontend/lib/auth/permission-codes.ts`)

Typed constants mirroring the DB seed. Import and use these — never write raw strings.

```ts
import { PERMISSIONS } from "@/lib/auth/permission-codes"

PERMISSIONS.COURSES.VIEW             // "courses.view"
PERMISSIONS.ADMIN.MANAGE_ROLES       // "admin.manage_roles"
PERMISSIONS.ASSESSMENTS.TAKE         // "assessments.take"
// etc.
```

### Server Permission Fetch (`mindforge/frontend/lib/server/permissions.ts`)

Server-only helper. Reads the `access_token` cookie and calls `/api/me/permissions`. Returns `[]` on any failure — safe to call unconditionally.

```ts
import { getMyPermissions } from "@/lib/server/permissions"
const perms: string[] = await getMyPermissions()
```

Called once in `app/layout.tsx` alongside `getFeatureConfig()` and passed to `PermissionProvider`. Individual server components that need to gate access call it themselves.

### Client Permission Context (`mindforge/frontend/lib/auth/permissions.tsx`)

`"use client"` — provides the permission set to the entire client tree.

```tsx
// Wired in app/layout.tsx:
<PermissionProvider permissions={permissions}>
  {children}
</PermissionProvider>

// Hooks (use in any client component):
const perms = usePermissions()          // ReadonlySet<string>
const can   = useHasPermission(code)    // boolean
const canAny = useHasAnyPermission([codes])   // boolean
const canAll = useHasAllPermissions([codes])  // boolean
```

### `<Can>` Component (`mindforge/frontend/components/auth/can.tsx`)

Client component for conditional rendering.

```tsx
// Require one specific permission
<Can permission={PERMISSIONS.ADMIN.MANAGE_ROLES}>
  <EditButton />
</Can>

// Require any one of a list
<Can anyOf={[PERMISSIONS.ADMIN.MANAGE_ROLES, PERMISSIONS.ADMIN.MANAGE_PERMISSIONS]}>
  <AdminPanel />
</Can>

// With fallback
<Can permission={PERMISSIONS.COURSES.CREATE} fallback={<p>No access.</p>}>
  <CreateCourseButton />
</Can>
```

**CRITICAL — never pass `notFound()` as a `fallback` prop.** `notFound()` throws immediately when evaluated, so `fallback={notFound()}` will always throw a 404 regardless of permissions. For server components that should 404 on missing permission, use a server-side check at the top of the function:

```tsx
// CORRECT pattern in server components:
export default async function SomePage() {
  const myPerms = await getMyPermissions()
  if (!myPerms.includes(PERMISSIONS.ADMIN.MANAGE_ROLES)) {
    notFound()
  }
  // ... rest of page
}
```

### Next.js Proxy (`mindforge/frontend/proxy.ts`, formerly `middleware.ts`)

Redirects unauthenticated users from protected routes to `/login?next=<path>`. Checks for the `access_token` cookie. This is a UX guard — the actual authorization happens on the backend.

Deny-by-default: everything is treated as protected except an explicit public allowlist (auth pages, marketing/legal pages, etc. — read the file for the current list). This is stricter than an older version of this doc implied by listing protected *prefixes* instead — don't infer that a path outside some remembered prefix list is unprotected.

---

## 7. Admin UI Pages

All under route group `app/(app)/` — transparent to URL routing, so URLs are `/admin/rbac/...`.

| URL | File | Permission required |
|---|---|---|
| `/admin/rbac/permissions` | `app/(app)/admin/rbac/permissions/page.tsx` | `admin.manage_roles` OR `admin.manage_permissions` |
| `/admin/rbac/roles` | `app/(app)/admin/rbac/roles/page.tsx` (role creation via `create-role-dialog.tsx`) | `admin.manage_roles` |
| `/admin/rbac/roles/[id]` | `app/(app)/admin/rbac/roles/[id]/page.tsx` (client-gated) + a sibling `layout.tsx` doing the real server-side `notFound()` check | `admin.manage_permissions` |
| `/users` | `app/(app)/users/page.tsx` | `admin.view_members` |
| `/org/settings/**` (members, domains, authentication, integrations, jobs, invites) | `app/org/settings/**/page.tsx` | `admin.manage_org` |
| `/org/settings/audit-log` | `app/org/settings/audit-log/page.tsx` — the single audit-log UI (offset pagination, actor name) over `GET /api/admin/rbac/audit` | `admin.view_audit_log` |

`app/(app)/users/[userId]/page.tsx` and `app/(app)/admin/rbac/roles/new/page.tsx`, previously listed here, do not exist in the current tree — role creation happens inline on `/admin/rbac/roles` via `create-role-dialog.tsx`, and there is no dedicated per-user admin page today.

### Layout

`app/(app)/layout.tsx` — app shell with `<Sidebar nav={MAIN_NAV_GROUPS} />`. Admin pages render inside this shell.

### Page types

- **Server components** (`permissions/page.tsx`, `roles/page.tsx`, all of `org/settings/**`): fetch data server-side with cookie forwarding; check permissions at the top via `getMyPermissions()` before any data fetch.
- **Client components** (`roles/[id]/page.tsx`): fetch from `process.env.NEXT_PUBLIC_API_URL` with `credentials: "include"`. Never call `fetch('/api/...')` — there is no Next.js API proxy; Go backend runs on a different port. Pair a client-gated page like this with a server-side `layout.tsx` doing the actual `notFound()` check — a client-only `useHasPermission()` hides controls but never stops the page from rendering for someone without access.

```ts
// Correct pattern in client components:
const API = process.env.NEXT_PUBLIC_API_URL ?? ""
await fetch(`${API}/api/admin/rbac/...`, { credentials: "include" })
```

---

## 8. Navigation & Sidebar

### Route Constants (`mindforge/frontend/lib/routes.ts`)

RBAC admin routes:
```ts
ROUTES.ADMIN_RBAC_ROLES        // "/admin/rbac/roles"
ROUTES.ADMIN_RBAC_PERMISSIONS  // "/admin/rbac/permissions"
```

### Nav Catalogue (`mindforge/frontend/lib/nav.ts`)

`ALL_NAV_ITEMS` — flat record of every nav item, keyed by name. Each entry carries an optional `requiredPermission` code. This is the single place to define a nav item.

`MAIN_NAV_GROUPS` — the sidebar: (unlabelled) Dashboard, Calendar, Help & Support · **Learn** (Learn hub, Mentors) · **Teach** (Instructor hub, Batches) · **Mentoring** (Overview, Ticket Queue) · **Support** (Support Queue) · **Administration**. The Platform group is appended for `platform_role === "super_admin"` in `sidebar-nav-content.tsx` (a separate axis from RBAC). `LEARN_HUB_GROUPS` (`/learn`) and `TEACHING_HUB_GROUPS` (`/teach`) back the two hub pages; no href appears twice within one surface (tested).

Item gating fields:
- `requiredPermission: string | string[]` — any-of.
- `hideForPermission: string | string[]` — hidden if the user holds ANY (Mentors, the learner directory, is hidden for `mentoring.view_tickets`, `mentoring.manage_batches`, `admin.manage_roles`, so instructors, mentors and admins don't see it).
- `hub: () => NavGroup[]` — the Learn entry is visible only if at least one Learn-hub item is visible (derived, no copied permission list).
- An item with neither field must carry a `// public` comment. Only Dashboard and Help & Support are public.

All filtering is the pure `filterNavGroups(groups, perms, terminology)`; `useVisibleNavGroups` just feeds it `usePermissions()` and `useTerminology()` (Batches -> Classes etc. is applied there). Role-by-role expectations live in `lib/nav.test.ts` (fixtures copied from `backend/internal/authz/testdata/role_matrix.golden.json`); run `vitest run` from `frontend/`.

Shared any-of code sets (`ACCESS` in `lib/auth/permission-codes.ts`: `LABS`, `CALENDAR`, `PRACTICE`, `TEACH_HUB`) are used by both the nav item and the page's server guard (`requireAnyPermission` in `lib/server/permissions.ts`, 404 on miss) so they cannot disagree. Guarded pages: labs catalog, roadmap list, saved highlights, algorithm visualizer, calendar, library, support queue. Sub-routes such as `/roadmap/discover` (public view) are intentionally unguarded.

Visibility by system role:

| Role | Sidebar |
|---|---|
| viewer | Dashboard, Help & Support, Learn (My Courses only) |
| member | + Calendar, Mentors; full Learn hub (Labs, Roadmap, Workspaces, ...) |
| instructor | + Instructor hub (incl. Ticket Queue, Library, Lab library), Batches, Users; no Mentors, no Mentoring group |
| mentor | + Mentoring (Overview, Ticket Queue), Users; no Mentors, no Instructor hub |
| tenant_admin | Calendar, Instructor, Batches, Mentoring, Support Queue, Administration; Learn shows only Courses/Assessments/Wiki/Workspaces/Labs (courses.edit), no Mentors |
| support_agent | Dashboard, Help & Support, Support Queue |

### Personas and dashboards (`frontend/lib/auth/personas.ts`)

`/dashboard` renders a persona-specific view, derived from permission codes only. Each persona has a marker permission: `admin` = `admin.manage_org`, `teach` = `courses.create`, `mentor` = `mentoring.manage_batches`, `support` = `support.manage`, `learn` = `practice.use`. `availablePersonas(perms)` lists the ones a user holds; `resolvePersona(perms, preferred?)` returns the optional `mf_persona` cookie value if it is available to the user, else the highest by order admin > teach > mentor > support > learn, else `viewer` (courses section only). `support` redirects to the support queue. The cookie is only a preference; it never grants anything, since the marker permission is re-checked on every render.

Dashboard widgets are each gated by the permission their endpoint needs: grading queue (`assessments.view_results`, teach + mentor), My courses (`courses.view_analytics`, `mine=true`; org-wide list only with `admin.manage_org`), open reports (`content.moderate`), lab sessions/compute hours (`admin.manage_org`), all admin.

### Sidebar (`mindforge/frontend/components/layout/sidebar-nav-content.tsx`)

Shared by the desktop sidebar and the mobile drawer. It calls `useVisibleNavGroups()` (permission filtering, hub rule, terminology, empty groups dropped) and wraps items with a `feature` field in `<AccessGate>` (feature-flag gating on top of permission gating).

---

## 9. Cache Lifecycle

```
Request arrives
    │
    ▼
Redis GET rbac:perms:{tenantID}:{userID}
    │
    ├─ HIT  → return codes immediately (5-min TTL)
    │
    └─ MISS → PostgreSQL JOIN query
                │
                └─ Redis SET rbac:perms:{tenantID}:{userID} (5 min TTL)
                    └─ return codes

Role mutation (create/update/disable/set-permissions)
    │
    └─ For every user holding the role:
            Redis DEL rbac:perms:{tenantID}:{userID}
            Redis PUBLISH rbac:invalidate "{tenantID}:{userID}"

User-role assignment / revoke
    │
    └─ Redis DEL rbac:perms:{tenantID}:{userID}  (target user only)
       Redis PUBLISH rbac:invalidate "{tenantID}:{userID}"
```

Redis write failures are logged via `slog.Warn` and do not fail the request. The DB result is always returned. This means a Redis outage degrades to full-DB-read mode — correct but slower.

The pub/sub channel `rbac:invalidate` exists for future L1 in-process cache support. Current implementation only uses Redis as the single cache layer.

---

## 10. Multi-Tenant Scoping Rules

1. **System roles** (`is_system=true`, `org_id IS NULL`) are global templates. They can be assigned to any user in any tenant. The `user_roles.org_id` on that assignment is the scope of the grant.

2. **Tenant-owned roles** (`is_system=false`, `org_id=<orgID>`) can only be assigned to users within the same org. The DB trigger `trg_user_role_org_scope` enforces this — no application-level code can bypass it.

3. Permission resolution always scopes to `user_roles.org_id = ?`. A user with the `instructor` system role in Org A has no permissions in Org B, even if they are a member there without any role assignment.

4. Permission guards check `claims.OrgID` and, when `RequireOrgMember` resolved another org, that org too (§4 Middleware). Admin API routes read `claims.OrgID` from the JWT to determine the caller's tenant. All queries filter by this value. Looking up another org's roles returns 404, identical to a genuinely missing role, preventing existence probing.

5. Disabling a role (`is_active=false`) is a soft delete. Hard deleting a role is blocked by `ON DELETE RESTRICT` on `user_roles.role_id` — you must revoke all user assignments first.

---

## 11. How To — Recipes for Common Changes

### Add a new permission code

1. Add a row to the consolidated schema: `mindforge/backend/db/migrations/001_baseline.sql`
   ```sql
   INSERT INTO permissions (code, name, description, module) VALUES
     ('content.new_tool', 'New Tool', 'Access the new tool', 'content')
   ON CONFLICT (code) DO NOTHING;
   ```
2. Add the constant to: `mindforge/frontend/lib/auth/permission-codes.ts`
   ```ts
   CONTENT: { ..., NEW_TOOL: "content.new_tool" }
   ```
3. Add it to any system role's permission list in the seed (if applicable) and add an `ON CONFLICT DO NOTHING` insert block.
4. Run the migration (via Docker). No application code changes needed — the new code is immediately available for middleware and nav guards.

### Add a new system role

1. Pick a new stable UUID and add to `001_baseline.sql`:
   ```sql
   INSERT INTO roles (id, name, description, is_system, is_editable, org_id) VALUES
     ('<new-uuid>', 'reviewer', 'Content reviewer role', true, false, NULL)
   ON CONFLICT (id) DO NOTHING;
   ```
2. Add a `role_permissions` insert block for this role in the same file.
3. No frontend or backend code changes needed.

### Protect a new Go API route

1. Pick the permission code that names the action (add one in a new migration if none fits — grant it to every system role that should keep access, then add the constant to `permission-codes.ts`). Never gate on `org_members.role`; the label only drives ownership (`owner`-only actions such as org activation) and the `OrgRoleRank` grant-ceiling rules.
2. Take `*authz.Service` in the package's `RegisterRoutes` (router.go passes `authzHandler.Service()`).
3. Guard the route:

```go
// Require ALL codes:
r.With(authz.RequirePermission(perms, "courses.publish")).
    Post("/api/courses/{courseID}/publish", h.PublishCourse)

// Require ANY one code:
r.With(authz.RequireAnyPermission(perms, "courses.edit", "mentoring.view_students")).
    Get("/api/courses/{courseID}/progress", h.GetAllProgress)

// Under /api/orgs/{id} (RequireOrgMember first) — check the {id} org only:
r.With(authz.RequireOrgCtxPermission(perms, "admin.manage_members")).
    Get("/members", h.handleListMembers)
```

4. Add a row to `internal/api/rbac_routes_db_test.go` asserting which system roles may call it.

Import: `"github.com/mindforge/backend/internal/authz"`.

### Gate a frontend server page

```tsx
// app/some-feature/page.tsx
import { notFound } from "next/navigation"
import { getMyPermissions } from "@/lib/server/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"

export default async function SomeFeaturePage() {
  const myPerms = await getMyPermissions()
  if (!myPerms.includes(PERMISSIONS.COURSES.CREATE)) {
    notFound()
  }
  // ... data fetch and render
}
```

### Gate a UI element in a client component

```tsx
import { useHasPermission } from "@/lib/auth/permissions"
import { PERMISSIONS } from "@/lib/auth/permission-codes"
import { Can } from "@/components/auth/can"

function MyComponent() {
  const canCreate = useHasPermission(PERMISSIONS.COURSES.CREATE)

  return (
    <div>
      {canCreate && <CreateButton />}

      <Can permission={PERMISSIONS.COURSES.EDIT}>
        <EditPanel />
      </Can>
    </div>
  )
}
```

### Add a new nav item that requires a permission

1. Add the item to `ALL_NAV_ITEMS` in `mindforge/frontend/lib/nav.ts`:
   ```ts
   new_tool: {
     label:              "New Tool",
     href:               ROUTES.NEW_TOOL,
     icon:               SomeIcon,
     requiredPermission: "content.new_tool",
     feature:            FEATURES.NEW_TOOL,  // only if also feature-gated
     mode:               "badge",
   },
   ```
2. Add `ALL_NAV_ITEMS.new_tool` to the appropriate group in `MAIN_NAV_GROUPS`.
3. Add the route constant to `mindforge/frontend/lib/routes.ts`.
4. The sidebar will automatically show/hide the item based on the user's permissions.

### Grant a permission directly to a user

For a genuine one-off exception that doesn't warrant a whole role — prefer a role for anything recurring (§1).

```
POST /api/admin/rbac/users/{userID}/permission-overrides
{ "permission_id": "<uuid>" }
```
Requires both `admin.manage_members` and `admin.manage_permissions`. Audits `user.permission.grant` and invalidates the user's permission cache — the grant is reflected in `GET /api/me/permissions` / `GET /api/admin/rbac/users/{userID}/permissions` immediately, no TTL wait. Revoke with `DELETE .../permission-overrides/{permissionID}`.

Frontend: `<ManageRolesDialog>`'s "Custom permissions" section (`app/(app)/users/user-permission-overrides.tsx`), gated on both `PERMISSIONS.ADMIN.MANAGE_MEMBERS` and `PERMISSIONS.ADMIN.MANAGE_PERMISSIONS`.

### Invalidate a user's permission cache manually

```go
// From any Go handler that has access to the authz.Service:
if err := svc.InvalidateUser(ctx, userID, tenantID); err != nil {
    slog.Warn("failed to invalidate permission cache", "error", err)
}
```

### Audit a specific entity's history

Use the API (the org audit page `/org/settings/audit-log` lists everything, unfiltered):

```
GET /api/admin/rbac/audit?entity_type=role&entity_id=<uuid>&limit=25
```

---

## Environment Variables

| Variable | Used by | Purpose |
|---|---|---|
| `BACKEND_URL` | Next.js server components | Internal URL for server→Go calls (not exposed to browser) |
| `NEXT_PUBLIC_API_URL` | Next.js client components | Public URL for browser→Go calls (must include CORS origin) |
| `REDIS_URL` | Go backend | Redis connection for permission cache |

---

## Known Constraints

- **`UNIQUE NULLS NOT DISTINCT`** requires PostgreSQL 15+. The dev Docker Compose uses PG16, so this is fine. Do not downgrade the DB version.
- **System role UUIDs are immutable.** The seed file uses `ON CONFLICT (id) DO NOTHING`. Changing a UUID in the seed file after initial migration has no effect and will create a duplicate. To change a system role, update the existing row directly.
- **`ON DELETE RESTRICT` on `user_roles.role_id`** means you cannot hard-delete a role that has current assignments. Use the disable flow (`DELETE /api/admin/rbac/roles/{id}` → sets `is_active=false`).
- **No permission inheritance or hierarchy.** Permissions are flat — a role either has a code or it doesn't. There is no concept of "inherits from another role." Compose permission sets explicitly in the seed or via the admin UI.
- **`practice.use` gates labs catalog / session start, roadmaps and highlights.** Every system role except `viewer` and `support_agent` holds it today. Phase 3 removes it from `tenant_admin`, so admins who also learn will need `member` as an extra role.
- **`ON DELETE RESTRICT` on `user_permission_overrides.permission_id`** (same as `role_permissions.permission_id`) means a permission cannot be hard-deleted while it is directly granted to any user.

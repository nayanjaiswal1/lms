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

---

## 2. Database Schema

**Migration file:** `mindforge/backend/db/migrations/001_schema.sql`
**Down file:** `mindforge/backend/db/migrations/001_schema.down.sql`

### `permissions`

Global table. No `tenant_id`. Permissions are a platform vocabulary — tenants cannot create new codes.

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
tenant_id   UUID  REFERENCES organizations(id) ON DELETE CASCADE  -- NULL for system roles
name        TEXT
description TEXT
is_system   BOOLEAN DEFAULT false
is_editable BOOLEAN DEFAULT true
is_active   BOOLEAN DEFAULT true
created_at, updated_at TIMESTAMPTZ
```

**Key constraints:**
- `roles_system_tenant_biconditional CHECK`: `(is_system=true AND tenant_id IS NULL) OR (is_system=false AND tenant_id IS NOT NULL)` — these two states are the only valid combinations.
- `UNIQUE NULLS NOT DISTINCT (tenant_id, name)` — system roles share a global namespace; tenant roles share per-org namespace. (Requires PostgreSQL 15+.)

Index: `idx_roles_tenant_active ON roles(tenant_id, is_active)`

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
tenant_id UUID REFERENCES organizations(id) ON DELETE CASCADE
PRIMARY KEY (user_id, role_id, tenant_id)
```

`tenant_id` is always set (never NULL). This is the **authoritative grant scope** — a system role assigned here only grants access within this tenant.

**Trigger:** `trg_user_role_tenant_scope` (function: `fn_check_user_role_tenant_scope`) fires BEFORE INSERT OR UPDATE. It rejects any attempt to assign a tenant-owned role under a different tenant's `tenant_id`. System roles (role's `tenant_id IS NULL`) pass unconditionally.

Indexes:
- `idx_user_roles_user_tenant ON user_roles(user_id, tenant_id)` — permission resolution
- `idx_user_roles_role ON user_roles(role_id)` — cache invalidation on role change

### `audit_log`

```sql
id          UUID  PRIMARY KEY
tenant_id   UUID  REFERENCES organizations(id) ON DELETE SET NULL
actor_id    UUID  REFERENCES users(id)         ON DELETE SET NULL
action      TEXT          -- e.g. "role.create", "user.role.assign"
entity_type TEXT          -- "role" | "user"
entity_id   TEXT          -- UUID as string
diff        JSONB         -- {"before": {...}, "after": {...}}
created_at  TIMESTAMPTZ
```

Indexes:
- `idx_audit_log_tenant_created ON audit_log(tenant_id, created_at DESC)` — fast pagination
- `idx_audit_log_entity ON audit_log(entity_type, entity_id)` — look up history for one entity

---

## 3. Seed Data — Permissions & System Roles

**Migration file:** `mindforge/backend/db/migrations/001_schema.sql`
**Down file:** `mindforge/backend/db/migrations/001_schema.down.sql`

All inserts use `ON CONFLICT DO NOTHING` — safe to re-run.

### Permission Catalogue (33 codes)

| Module | Code | Name |
|---|---|---|
| courses | `courses.view` | View Courses |
| courses | `courses.enroll` | Enroll in Courses |
| courses | `courses.create` | Create Courses |
| courses | `courses.edit` | Edit Courses |
| courses | `courses.publish` | Publish Courses |
| courses | `courses.delete` | Delete Courses |
| courses | `courses.view_analytics` | Course Analytics |
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
| content | `content.wiki` | Wiki |
| content | `content.system_design` | System Design |
| content | `content.interview_board` | Interview Board |
| content | `content.load_test` | Load Test |
| content | `content.sheets` | Sheet Tracker |
| content | `content.srs` | Review Cards |
| content | `content.certificates` | Certificates |
| admin | `admin.view_members` | View Members |
| admin | `admin.manage_members` | Manage Members |
| admin | `admin.manage_roles` | Manage Roles |
| admin | `admin.manage_permissions` | Manage Permissions |
| admin | `admin.view_audit_log` | View Audit Log |
| admin | `admin.manage_org` | Manage Organisation |

### System Roles (fixed UUIDs — never change these)

| UUID | Name | Description |
|---|---|---|
| `11111111-1111-1111-1111-000000000001` | `viewer` | Read-only access to published content |
| `11111111-1111-1111-1111-000000000002` | `member` | Standard learner — courses, practice, tools |
| `11111111-1111-1111-1111-000000000003` | `instructor` | Course and assessment author |
| `11111111-1111-1111-1111-000000000004` | `mentor` | Mentoring and batch supervision |
| `11111111-1111-1111-1111-000000000005` | `tenant_admin` | Full organisation administration |

### System Role → Permissions

**viewer:** `courses.view`

**member (13):** `courses.view`, `courses.enroll`, `assessments.take`, `assessments.view_assigned`, `practice.use`, `mentoring.chat`, `content.wiki`, `content.system_design`, `content.interview_board`, `content.load_test`, `content.sheets`, `content.srs`, `content.certificates`

**instructor (25):** all member permissions + `courses.create/edit/publish/delete/view_analytics`, `assessments.create/edit/publish/delete/view_results/manage_questions/manage_batches`, `admin.view_members`

**mentor (17):** all member permissions + `assessments.view_results`, `mentoring.manage_batches`, `mentoring.view_students`, `admin.view_members`

**tenant_admin:** all 33 permissions

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

Single JOIN query:

```sql
SELECT DISTINCT p.code
FROM user_roles ur
JOIN roles r       ON r.id = ur.role_id       AND r.is_active = true
JOIN role_permissions rp ON rp.role_id = r.id
JOIN permissions p ON p.id = rp.permission_id AND p.is_active = true
WHERE ur.user_id = $1 AND ur.tenant_id = $2
```

Returns `[]string{}` (not nil) when the user has no permissions.

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
```

Claims are read from context via `auth.GetClaims(r.Context())`. The tenant scope comes from `claims.OrgID`.

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

#### Audit Log

| Method | Path | Required permission |
|---|---|---|
| GET | `/api/admin/rbac/audit` | `admin.view_audit_log` (all) |

Query params: `entity_type`, `entity_id`, `limit`, `offset`

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

### Next.js Edge Middleware (`mindforge/frontend/middleware.ts`)

Redirects unauthenticated users from protected routes to `/login?next=<path>`. Checks for the `access_token` cookie. This is a UX guard — the actual authorization happens on the backend.

Protected path prefixes: `/dashboard`, `/courses`, `/practice`, `/assessments`, `/mentor`, `/settings`, `/instructor`, `/admin`

---

## 7. Admin UI Pages

All under route group `app/(app)/` — transparent to URL routing, so URLs are `/admin/rbac/...`.

| URL | File | Permission required |
|---|---|---|
| `/admin/rbac/permissions` | `app/(app)/admin/rbac/permissions/page.tsx` | `admin.manage_roles` OR `admin.manage_permissions` |
| `/admin/rbac/roles` | `app/(app)/admin/rbac/roles/page.tsx` | `admin.manage_roles` |
| `/admin/rbac/roles/new` | `app/(app)/admin/rbac/roles/new/page.tsx` | `admin.manage_roles` |
| `/admin/rbac/roles/[id]` | `app/(app)/admin/rbac/roles/[id]/page.tsx` | `admin.manage_permissions` (edit) |
| `/admin/rbac/users/[userId]` | `app/(app)/admin/rbac/users/[userId]/page.tsx` | `admin.manage_members` OR `admin.view_members` |
| `/admin/rbac/audit` | `app/(app)/admin/rbac/audit/page.tsx` | `admin.view_audit_log` |

### Layout

`app/(app)/layout.tsx` — app shell with `<Sidebar nav={MAIN_NAV_GROUPS} />`. Admin pages render inside this shell.

### Page types

- **Server components** (`permissions/page.tsx`, `roles/page.tsx`, `audit/page.tsx`): fetch data server-side with cookie forwarding; check permissions at the top via `getMyPermissions()` before any data fetch.
- **Client components** (`roles/[id]/page.tsx`, `users/[userId]/page.tsx`, `roles/new/page.tsx`): fetch from `process.env.NEXT_PUBLIC_API_URL` with `credentials: "include"`. Never call `fetch('/api/...')` — there is no Next.js API proxy; Go backend runs on a different port.

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
ROUTES.ADMIN_RBAC_AUDIT        // "/admin/rbac/audit"
```

### Nav Catalogue (`mindforge/frontend/lib/nav.ts`)

`ALL_NAV_ITEMS` — flat record of every nav item, keyed by name. Each entry carries an optional `requiredPermission` code. This is the single place to define a nav item.

`MAIN_NAV_GROUPS` — the grouped structure passed to `<Sidebar>`. Four groups:

| Group label | Items (key names in ALL_NAV_ITEMS) |
|---|---|
| *(none)* | dashboard, courses, practice, assessments, flashcards, sheet_tracker, mentor_chat, certificates, wiki, system_design, interview_board, load_test |
| Teach | instructor_dashboard, instructor_courses, instructor_assessments, question_bank, batches |
| Mentor | mentor_dashboard, mentor_messages, mentor_batches |
| Admin | admin_rbac |

### Sidebar (`mindforge/frontend/components/layout/sidebar.tsx`)

`"use client"` component. Accepts `nav: NavGroup[]` and:
1. Calls `usePermissions()` to get the current user's permission set
2. Filters each group's items — only items with no `requiredPermission`, or whose code is in the permission set, survive
3. Drops groups that become empty after filtering
4. Wraps items that have a `feature` field in `<AccessGate>` (feature-flag gating on top of permission gating)

A student sees only the top group. An instructor additionally sees Teach. A tenant_admin sees all four groups including Admin.

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

1. **System roles** (`is_system=true`, `tenant_id IS NULL`) are global templates. They can be assigned to any user in any tenant. The `user_roles.tenant_id` on that assignment is the scope of the grant.

2. **Tenant-owned roles** (`is_system=false`, `tenant_id=<orgID>`) can only be assigned to users within the same org. The DB trigger `trg_user_role_tenant_scope` enforces this — no application-level code can bypass it.

3. Permission resolution always scopes to `user_roles.tenant_id = ?`. A user with the `instructor` system role in Org A has no permissions in Org B, even if they are a member there without any role assignment.

4. Admin API routes read `claims.OrgID` from the JWT to determine the caller's tenant. All queries filter by this value. Looking up another org's roles returns 404, identical to a genuinely missing role, preventing existence probing.

5. Disabling a role (`is_active=false`) is a soft delete. Hard deleting a role is blocked by `ON DELETE RESTRICT` on `user_roles.role_id` — you must revoke all user assignments first.

---

## 11. How To — Recipes for Common Changes

### Add a new permission code

1. Add a row to the consolidated schema: `mindforge/backend/db/migrations/001_schema.sql`
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

1. Pick a new stable UUID and add to `001_schema.sql`:
   ```sql
   INSERT INTO roles (id, name, description, is_system, is_editable, tenant_id) VALUES
     ('<new-uuid>', 'reviewer', 'Content reviewer role', true, false, NULL)
   ON CONFLICT (id) DO NOTHING;
   ```
2. Add a `role_permissions` insert block for this role in the same file.
3. No frontend or backend code changes needed.

### Protect a new Go API route

```go
// Require ALL codes:
r.With(RequirePermission(h.svc, "courses.create", "courses.publish")).
    Post("/api/courses/{id}/publish", h.HandlePublish)

// Require ANY one code:
r.With(RequireAnyPermission(h.svc, "admin.manage_roles", "admin.manage_permissions")).
    Get("/api/admin/roles", h.HandleListRoles)
```

Import: `"github.com/mindforge/backend/internal/authz"` — then use `authz.RequirePermission` or `authz.RequireAnyPermission`.

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

### Invalidate a user's permission cache manually

```go
// From any Go handler that has access to the authz.Service:
if err := svc.InvalidateUser(ctx, userID, tenantID); err != nil {
    slog.Warn("failed to invalidate permission cache", "error", err)
}
```

### Audit a specific entity's history

Query the audit log page at `/admin/rbac/audit?entity_type=role&entity_id=<role-uuid>`, or via the API:

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

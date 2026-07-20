---
kind: lesson
type: system_design
id_key: interview-prep-45/day-06-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 6 — Multi-tenant SaaS Architecture"
position: 6
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

## Why interviewers ask this

Multi-tenancy is less about a single system and more about a cross-cutting architectural decision that touches the data layer, auth, billing, and ops all at once. It's a favorite at companies building B2B SaaS (exactly like MindForge itself) because it tests whether you can reason about isolation guarantees, cost efficiency, and blast radius simultaneously — trade-offs that don't have a universally "correct" answer.

## Requirements

### Functional
- Each tenant (customer organization) has isolated data — one tenant must never see another's records.
- Per-tenant billing based on usage (seats, API calls, storage).
- Tenant admins can manage their own users/roles (RBAC scoped to their tenant).
- Support tenant-specific customization (branding, feature flags, custom fields).

### Non-functional
- **Security/isolation** — a bug or bad query must not leak cross-tenant data; this is the #1 SaaS incident category.
- **Performance** — one noisy/high-volume tenant must not degrade others (noisy-neighbor problem).
- Operational simplicity — schema migrations, backups, and scaling should work the same way regardless of tenant count.
- Ability to onboard a new tenant quickly (ideally self-serve, seconds not days).

### Clarifying questions to ask (not pitch) before designing
A strong candidate spends the first few minutes extracting constraints instead of jumping straight to a diagram:
- **Scale:** tenant count and growth projection — 10 tenants vs. 500+ leads to different models.
- **Data residency / compliance:** does any tenant's data need to stay in a specific region or meet a regulatory bar? This alone can force Silo/Bridge regardless of scale.
- **Tenant mix:** will large enterprise tenants and small self-serve tenants coexist? That's the hybrid signal from the tenancy-model discussion below.
- **Migration path:** is this a green-field design, or does an existing single-tenant system need a big-bang vs. gradual migration? (Bridge — separate schema — is often the easiest incremental step from a single-tenant starting point.)

## Tenancy models

### 1. Shared database, shared schema (row-level isolation)
Every table has a `tenant_id` column; all tenants' rows live in the same tables. Application code (or DB row-level security) filters every query by `tenant_id`.

- **Pros:** cheapest to run (one DB, high resource utilization), simplest to operate (one schema to migrate), easiest to add new tenants (just insert a row).
- **Cons:** isolation depends entirely on every query correctly filtering by `tenant_id` — a single missed `WHERE tenant_id = ?` is a cross-tenant data leak. Noisy-neighbor risk is highest (one tenant's heavy query load shares the same DB/indexes as everyone else).
- **Mitigation:** enforce isolation at the DB layer, not just app code — Postgres **Row-Level Security (RLS)** policies tied to a session variable (`SET app.tenant_id = '...'`) make leakage a DB-level guarantee instead of a code-review hope.

### 2. Shared database, separate schema per tenant
One database instance, but each tenant gets its own schema (namespace) — `tenant_123.users`, `tenant_456.users`.

- **Pros:** stronger isolation than row-level (a schema-scoped connection literally cannot see another tenant's tables), still shares DB infrastructure cost.
- **Cons:** migrations must run once per schema (N tenants = N migration runs), connection pooling gets more complex (need per-schema search_path), doesn't scale cleanly past a few thousand tenants (schema count becomes a management burden).

### 3. Separate database per tenant
Each tenant gets a fully independent database (potentially on separate DB instances for the largest tenants).

- **Pros:** strongest isolation (a query literally cannot reach another tenant's data — no shared connection, no shared instance for a dedicated DB), easiest to give one tenant a custom backup/restore or compliance posture (e.g. a healthcare tenant needing HIPAA-specific handling), natural noisy-neighbor isolation.
- **Cons:** most expensive (idle capacity per tenant), most operational overhead (migrations must run across every tenant DB — needs tooling), harder to do cross-tenant analytics/aggregation.

**Interview-favored answer:** most SaaS products start with **shared DB, shared schema + `tenant_id` + Row-Level Security**, because it's cheapest and simplest, and offer **dedicated database** as a premium/enterprise tier for customers who need stronger isolation guarantees (common ask from enterprise/compliance-sensitive customers) — a **hybrid model**, not a single global choice.

These three options are often named directly in interviews as **Pool** (shared schema, this is model 1 above), **Bridge** (separate schema per tenant, model 2), and **Silo** (separate database per tenant, model 3) — same trade-offs, different vocabulary, worth recognizing both namings.

**Decision heuristic to say out loud:** ask "if tenant A's data leaked into tenant B's response, is that ever acceptable?" A hard no (finance, health, education data) pulls you toward Silo/Bridge; an unlikely/low-stakes leak pulls you toward Pool with strong RLS. Then narrow further:
- **Compliance/regulatory requirements** push toward Silo/Bridge.
- **Many small tenants** push toward Pool — per-tenant DB overhead is unaffordable at that volume.
- **Few large enterprise tenants with noisy-neighbor risk** push toward Silo/Bridge.
- **Mixed tiers** (freemium + enterprise) is the hybrid signal from above: pool the small tenants, dedicate schema/DB for the large ones.
- **Onboarding speed**: Pool is instant (insert a row); Silo needs provisioning automation.
- **Backup/restore granularity**: Silo makes a single-tenant restore trivial; Pool makes it painful (a restore touches everyone).
- **Connection pool limits**: many separate per-tenant databases can exhaust infra connection limits — this is often what kills a pure Silo approach at scale before compliance does.

## Capacity / scale considerations

- Assume 10,000 tenants, average 50 users each = 500,000 total users.
- With shared-schema, one well-indexed table (`tenant_id` as the leading column in every composite index) can hold all tenants' rows — a table with 100M rows partitioned/indexed by `tenant_id` performs fine as long as query patterns always filter by it first.
- **Table partitioning by `tenant_id` hash or range** becomes worth it once a single table crosses tens of millions of rows, so that large tenants' data and small tenants' data don't compete for the same index pages/cache.
- For the largest 1% of tenants (by volume), consider **tenant sharding**: route their traffic to a dedicated shard/DB while the long tail of small tenants stays on the shared pool — this is the same pattern Slack and Shopify use in practice.

## Data model

```
tenants
  id            bigint PK
  name          varchar
  plan          enum(free, pro, enterprise)
  created_at    timestamp

users
  id            bigint PK
  tenant_id     bigint INDEX (leading column in composite indexes)
  email         varchar
  role          varchar

-- every tenant-scoped table follows this shape:
resources
  id            bigint PK
  tenant_id     bigint INDEX
  ...
  UNIQUE (tenant_id, some_natural_key)   -- uniqueness is scoped per tenant, not global
```

Postgres RLS example (row-level isolation enforced by the DB, not trusted to app code):

```sql
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON resources
  USING (tenant_id = current_setting('app.tenant_id')::bigint);

-- every connection, set once per request:
SET app.tenant_id = '123';
```

## High-level architecture

```
Client --> API Gateway --> Auth Middleware (resolves tenant_id from JWT/subdomain)
                                    |
                                    v
                          Application Servers (stateless)
                                    |
                    SET app.tenant_id = X  (per-request, before any query)
                                    |
                                    v
                     Shared DB (RLS-enforced) <--- for most tenants
                                    |
                     Dedicated DB  <--- for enterprise/compliance tenants (routed separately)
```

Tenant resolution typically comes from the subdomain (`acme.mindforge.com`), a custom domain mapping, or a claim embedded in the auth token — resolved once at the edge/middleware layer and threaded through every downstream call, never re-derived per query.

## Component deep dives

### RBAC for multi-tenant access

- Roles are **scoped to a tenant** — `(tenant_id, user_id, role)` — a user can be an admin in one org and a regular member in another (common for consultants/contractors working across multiple customer orgs).
- Global "platform admin" roles (your own support/ops staff) are a separate, explicitly audited role type that bypasses normal tenant scoping — every access via this role should be logged, since it's the highest-risk isolation bypass by design.
- Roles are typically **multi-level within a tenant** too — system admin → org admin → user → sub-user — not just a flat admin/member split; model the hierarchy, not just the boundary.
- Decide **static roles vs. tenant-defined custom roles**: a fixed role enum (admin/member/viewer) is simpler to reason about and ships faster; letting each tenant define its own roles/permission matrix is a common enterprise ask but pushes you toward a permissions-table model (roles map to sets of permission codes) rather than hardcoded role checks in application code.

### Reusable modules across tenants

- Separate the **tenant-agnostic core** (business logic/engine) from **tenant-specific configuration** (branding, custom rules, validation standards) — a plugin/config-driven core scales to N tenants; a codebase forked per customer does not.
- This is the same instinct as the tenancy-model decision one level up: keep the shared logic shared, and push what genuinely varies per tenant into data (config rows, JSONB, flags) rather than code branches.

### Tenant-specific customization

- **Branding/config:** store as a `tenant_settings` JSONB blob keyed by `tenant_id` — flexible, no schema migration needed per new setting.
- **Custom fields:** either an EAV (entity-attribute-value) side table, or a JSONB column on the base entity (`resources.custom_fields jsonb`) — JSONB is usually the pragmatic choice unless you need to query/index arbitrary custom fields at scale, in which case a dedicated schema-per-tenant or a search index (Elasticsearch) becomes worth the complexity.
- **Feature flags per tenant:** a `tenant_features` table or a flag service (LaunchDarkly-style) keyed by `tenant_id` lets you roll out features to specific tenants (e.g. beta/pilot customers before general availability) without a deploy — the flag system needs to be tenant-aware from the start, not bolted on as a global on/off switch later.
- **Cross-tenant aggregation** (e.g. a parent org viewing data across several child tenants) needs to be an explicit, separately-permissioned capability — never a side effect of a query that's merely missing a `tenant_id` filter.

### Tenant resolution in the application layer (framework-level implementation)

Whatever framework you use, the same pattern shows up under different names — this is worth naming explicitly in an interview because it's where isolation bugs actually happen:

1. **Resolve the tenant early**, at the edge — subdomain, custom domain, or a claim in the auth token (JWT) — never re-derive it deeper in the call stack.
2. **Attach it to request-scoped context**, not a global/module-level variable. In Django this is a piece of custom middleware that resolves the tenant and stores it somewhere request-scoped (e.g. `contextvars.ContextVar`, the Python async-safe equivalent of a thread-local) rather than on `request` alone if background tasks/async code also need it. FastAPI does the same via a dependency that resolves tenant from the request and either returns it directly for injection or sets it on a `ContextVar` for code that can't easily receive it as a parameter.
3. **Every DB session picks it up from there** — for Pool, that means every query is filtered/scoped by the resolved `tenant_id` (ideally backstopped by Postgres RLS, per the isolation guarantee above, not trusted to application code alone); for Bridge, the connection's schema/search_path is switched based on the resolved tenant before any query runs.
4. **Clear the context after the request finishes**, in a `finally`/middleware teardown — pooled workers (Gunicorn/Uvicorn workers reused across requests, thread pools) can leak a stale tenant into the next unrelated request if this step is skipped. This is the same bug class as forgetting to reset thread-local state in any pooled-worker framework, whatever language it's written in.

### Data migration across tenants

- Onboarding: create the `tenants` row, seed default settings/roles — should be a single fast transaction, not a slow provisioning job, if using shared schema.
- Offboarding/export (GDPR-style "give me my data" or customer churn): with shared schema, this means a `SELECT ... WHERE tenant_id = ?` export across every table — maintain a canonical list of tenant-scoped tables so this stays complete as the schema grows.
- Tier migration (moving a tenant from shared DB to dedicated DB as they grow into an enterprise plan): requires an online migration tool that copies rows for that `tenant_id`, cuts over traffic, and verifies row counts match before decommissioning the old copy — non-trivial, budget real engineering time for this path if you offer it.

## Scaling & trade-offs

- **Isolation guarantee is a spectrum**, not binary: RLS-enforced shared schema is "good enough" isolation for most B2B SaaS; dedicated DB is what you sell as a premium/compliance SKU.
- **Noisy neighbor mitigation** even within shared schema: per-tenant query timeouts, connection pool limits, and rate limiting at the API gateway keyed by `tenant_id` (same rate-limiter pattern as Day 2) prevent one tenant's traffic spike from starving others.
- **Backups/DR:** shared schema means one backup covers everyone (simple, but a restore affects all tenants); dedicated DB means per-tenant backup/restore granularity (useful if one enterprise customer needs point-in-time recovery without touching others).
- **Regulatory/data-residency constraints shape the isolation model, not just cost:** a tenant in a regulated vertical (health, finance, education) or a specific region often comes with legal requirements — data must stay hosted in-region, or the vendor is jointly liable for breaches — that can force Silo/Bridge for that tenant regardless of what the rest of the platform uses, and typically also requires per-tenant audit logging of data access. Worth naming as one concrete example if the interviewer asks "when would you *not* use shared schema even at small scale?"

## Likely follow-up questions — with answers

**Q: How do you guarantee a bug in application code can never leak one tenant's data to another?**
A: Don't rely solely on every developer remembering `WHERE tenant_id = ?` in every query. Enforce isolation at the database layer with Row-Level Security policies tied to a session variable set once per request — even a forgotten `WHERE` clause is still constrained by the DB itself.

**Q: A single large enterprise tenant is generating 10x the query load of everyone else on the shared database — what do you do?**
A: Identify it via per-tenant query metrics, then migrate that tenant to a dedicated database/shard using an online migration (copy rows for that `tenant_id`, verify, cut over). Offer dedicated infrastructure as a paid tier for tenants that outgrow the shared pool, rather than letting them degrade everyone else.

**Q: How would you support a tenant that needs custom fields on every entity without a schema migration each time?**
A: A `custom_fields jsonb` column on the base tables lets tenants define arbitrary key-value fields without a DDL change. If they need those fields to be efficiently queryable/filterable at scale, add a GIN index on the JSONB column, or move that tenant to a search index (Elasticsearch) for that use case specifically.

## Key takeaways
- Multi-tenancy isolation is a spectrum: shared schema + `tenant_id` (cheapest) → separate schema (stronger) → dedicated DB (strongest, most expensive) — most SaaS products offer a hybrid, not a single tier.
- Enforce tenant isolation at the database layer (Row-Level Security) — never trust application code alone to filter every query correctly.
- RBAC roles are scoped per `(tenant_id, user_id)`, not globally, except for a separately-audited platform-admin role.
- Noisy-neighbor protection (per-tenant rate limits, query timeouts, connection pool caps) matters even inside a shared database.
- Plan tenant tier migration (shared -> dedicated) as a real engineering feature, not an afterthought, if you offer it as a premium SKU.

## Today's checklist
- [ ] Define functional requirements: isolation, billing per tenant
- [ ] Define non-functional requirements: security, performance
- [ ] Design tenancy models: shared database, separate schema, separate database
- [ ] Design RBAC for multi-tenant access
- [ ] Discuss tenant-specific customization
- [ ] Handle data migration across tenants

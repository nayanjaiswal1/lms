---
kind: lesson
type: system_design
id_key: interview-prep-45/day-06-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Multi-tenant SaaS Architecture"
position: 7
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

Multi-tenancy means one system serves many customers (tenants), each believing they have the product to themselves. Picture an apartment building: every tenant has their own locked unit, but they share the same plumbing, elevators, and foundation. Get the isolation wrong and one tenant can see another's data, which is the single biggest incident category in B2B SaaS. This question is less "draw a diagram" and more "reason about isolation, cost, and blast radius at the same time."

## Requirements

**Functional requirements**
- Each tenant's data is isolated; one tenant must never see another's records.
- Per-tenant billing based on usage: seats, API calls, storage.
- Tenant admins manage their own users and roles, scoped only to their own tenant.
- Tenant-specific customization: branding, feature flags, custom fields.

**Non-functional requirements**
- Security and isolation: a bug or a bad query must never leak data across tenants.
- Performance: one noisy, high-volume tenant must not slow down everyone else (the "noisy neighbor" problem).
- Operational simplicity: migrations, backups, and scaling should work the same way no matter how many tenants exist.
- Fast onboarding: adding a new tenant should take seconds, not days.

Before you design anything, ask a few clarifying questions: how many tenants, and how fast is that number growing? Does any tenant's data need to stay in a specific region for compliance? Will tiny self-serve tenants and huge enterprise tenants coexist? Is this greenfield, or does an existing single-tenant system need to migrate? The answers change which model below is right.

## The three tenancy models

**Pool: shared database, shared schema.** Every table has a `tenant_id` column, and every tenant's rows live in the same tables. Cheapest to run, simplest to operate, and the fastest to onboard a new tenant (just insert a row). The risk: isolation depends entirely on every query remembering to filter by `tenant_id`. Miss one `WHERE tenant_id = ?` and you have a cross-tenant leak.

**Bridge: shared database, separate schema per tenant.** One database instance, but each tenant gets its own schema namespace, like `tenant_123.users` versus `tenant_456.users`. Stronger isolation than Pool, since a schema-scoped connection literally cannot see another tenant's tables, but migrations now have to run once per schema, and schema count becomes a real management burden past a few thousand tenants.

**Silo: separate database per tenant.** Each tenant gets a fully independent database, sometimes even a dedicated instance for the biggest ones. This is the strongest isolation: a query physically cannot reach another tenant's data. It's also the most expensive, since idle capacity is paid per tenant, and migrations must run across every tenant database.

> **Remember:** Pool is cheap and fast to onboard, Silo is expensive but bulletproof, Bridge sits in between. Most real SaaS products use a hybrid: Pool for most tenants, Silo as a premium tier for the ones who need it.

```knowledge-check
{ "questions": [
    { "id": "system-design-saas-tenancy-q1", "type": "mcq", "prompt": "What is the main risk of the Pool model (shared database, shared schema, tenant_id column)?", "options": [
        {"id": "a", "text": "It is too expensive to run for most companies"},
        {"id": "b", "text": "Isolation depends on every query correctly filtering by tenant_id, so one missed filter is a cross-tenant data leak"},
        {"id": "c", "text": "It cannot support more than 100 tenants"},
        {"id": "d", "text": "It requires a separate database per tenant"}
    ], "correct": "b", "explanation": "Because every tenant's rows sit in the same tables, correctness depends on application code remembering the tenant_id filter every single time, which is exactly why database-level enforcement matters." }
] }
```

**How to decide.** Ask yourself: if tenant A's data leaked into tenant B's response, would that ever be acceptable? A hard no, common in finance, health, or education, pulls you toward Silo or Bridge. A low-stakes, unlikely leak allows Pool with strong safeguards. Then narrow further: compliance and data-residency rules push toward Silo/Bridge; many small tenants push toward Pool, since per-tenant overhead becomes unaffordable at volume; a handful of large enterprise tenants with real noisy-neighbor risk push toward Silo/Bridge; a mix of tiny and huge tenants is the classic hybrid signal, pool the small ones, dedicate a schema or database for the large ones.

## Estimates

Assume 10,000 tenants averaging 50 users each, 500,000 users total. In a shared schema, one well-indexed table, with `tenant_id` as the leading column of every composite index, comfortably holds 100 million rows as long as every query filters by tenant first. Once a single table crosses tens of millions of rows, partition it by `tenant_id` hash or range, so a large tenant's data and a small tenant's data don't fight over the same index pages. For the largest 1% of tenants by volume, route them to a dedicated shard while the long tail of small tenants stays in the shared pool. Slack and Shopify both run this pattern in production.

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

Never trust isolation to application code alone. Enforce it at the database layer with Postgres Row-Level Security:

```sql
ALTER TABLE resources ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON resources
  USING (tenant_id = current_setting('app.tenant_id')::bigint);

-- every connection, set once per request:
SET app.tenant_id = '123';
```

With this policy in place, even a developer who forgets the `WHERE tenant_id = ?` clause still can't read another tenant's rows. The database enforces it regardless of what the application code does.

## High-level design

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

Tenant identity usually comes from the subdomain (`acme.mindforge.com`), a custom domain mapping, or a claim in the auth token. Resolve it once, at the edge, and carry it through every downstream call. Never re-derive it deeper in the request.

## Deep dives

### How does the application layer keep tenant identity straight, request after request?

The same pattern shows up under different names in every framework, and it's worth naming explicitly since this is exactly where isolation bugs happen in practice:

1. **Resolve the tenant early**, at the edge: subdomain, custom domain, or a JWT claim.
2. **Attach it to request-scoped context**, not a global variable. In Django this is middleware storing it somewhere request-scoped; in FastAPI it's a dependency that resolves the tenant per request.
3. **Every database session picks it up from there.** For Pool, every query is filtered by the resolved `tenant_id`, backstopped by Row-Level Security. For Bridge, the connection's schema is switched to that tenant's schema before any query runs.
4. **Clear the context when the request finishes**, in a teardown step. A pooled worker reused across requests, common in Gunicorn or Uvicorn, can leak a stale tenant into the next unrelated request if this step is skipped. That's the same bug class as forgetting to reset thread-local state in any pooled-worker framework.

> **Remember:** the isolation bug that actually happens in production isn't a missing WHERE clause, it's a stale tenant ID left over from a reused worker. Always clear context in a teardown step.

```knowledge-check
{ "questions": [
    { "id": "system-design-saas-context-q1", "type": "mcq", "prompt": "What real bug can happen if a pooled worker (reused across requests) never clears the resolved tenant_id after a request finishes?", "options": [
        {"id": "a", "text": "Nothing, workers are always isolated per request automatically"},
        {"id": "b", "text": "A stale tenant_id can leak into the next unrelated request handled by that same worker"},
        {"id": "c", "text": "The database connection pool will run out of connections"},
        {"id": "d", "text": "The server will crash immediately"}
    ], "correct": "b", "explanation": "Because pooled workers are reused, tenant context set on one request can silently carry over to the next if it isn't cleared in a teardown step, causing a real cross-tenant bug." }
] }
```

### How does RBAC work when roles are per-tenant?

Roles are scoped to a tenant: `(tenant_id, user_id, role)`. The same person can be an admin in one organization and a regular member in another, common for a contractor working across multiple customer accounts. Within a tenant, roles are usually multi-level (system admin, org admin, user, sub-user), not just a flat admin-or-member split.

Your own internal support staff need a separate, explicitly audited "platform admin" role that bypasses normal tenant scoping. Every access through that role should be logged, since it's the highest-risk isolation bypass by design.

### How do you support per-tenant customization without a schema migration every time?

Store branding and settings as a `tenant_settings` JSONB blob keyed by `tenant_id`, so a new setting never needs a migration. For custom fields on a business entity, a `custom_fields jsonb` column on the base table is usually the pragmatic choice; add a GIN index if a tenant needs those fields to be efficiently searchable, or move that tenant to a dedicated search index if the volume justifies it. Feature flags per tenant work the same way: a `tenant_features` table, or a flag service, lets you roll a feature out to specific tenants without a deploy.

Keep the underlying business logic tenant-agnostic and push what actually varies into data: config rows, JSONB, flags. A codebase forked per customer does not scale; a config-driven core does.

## Trade-offs and follow-up questions

Isolation is a spectrum, not a binary choice: an RLS-enforced shared schema is good enough for most B2B SaaS, and a dedicated database is what you sell as a premium or compliance tier. Even within a shared schema, mitigate noisy neighbors with per-tenant query timeouts, connection pool limits, and rate limiting at the gateway keyed by `tenant_id`. Backups follow the same split: shared schema means one backup covers everyone, simple, but a restore touches every tenant; a dedicated database gives one tenant its own backup and restore granularity.

A regulated tenant, health, finance, or education, or one bound to a specific region, can force Silo or Bridge for that single tenant regardless of what the rest of the platform uses, and usually also needs per-tenant audit logging. That's worth naming if asked "when would you not use shared schema even at small scale?"

**Q: How do you guarantee a bug in application code can never leak one tenant's data to another?**
A: Don't rely on every developer remembering the `WHERE tenant_id = ?` clause. Enforce isolation at the database layer with Row-Level Security tied to a session variable set once per request, so even a forgotten filter is still constrained by the database.

**Q: A single large enterprise tenant is generating 10x the query load of everyone else. What do you do?**
A: Spot it through per-tenant query metrics, then migrate that tenant to a dedicated database with an online migration: copy their rows, verify counts match, cut over traffic. Offer dedicated infrastructure as a paid tier for tenants that outgrow the shared pool.

**Q: How would you support custom fields per tenant without a migration every time?**
A: A `custom_fields jsonb` column on the base tables. Add a GIN index if it needs to be efficiently queryable, or move that tenant to a search index if the volume justifies the extra complexity.

```knowledge-check
{ "questions": [
    { "id": "system-design-saas-tradeoffs-q1", "type": "mcq", "prompt": "Why would a regulated tenant (health, finance) sometimes force a Silo model even if the rest of the platform uses Pool?", "options": [
        {"id": "a", "text": "Regulated tenants always pay more, so they get a nicer database"},
        {"id": "b", "text": "Legal or data-residency requirements can mandate stronger isolation and audit logging for that specific tenant"},
        {"id": "c", "text": "Pool cannot technically support regulated industries at all"},
        {"id": "d", "text": "This never actually happens in practice"}
    ], "correct": "b", "explanation": "Compliance obligations are a real constraint that can override the platform's default tenancy model for one specific tenant, regardless of scale." }
] }
```

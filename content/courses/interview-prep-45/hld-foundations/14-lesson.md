---
kind: lesson
id_key: interview-prep-45/hld-14-observability-security
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Observability, Security, and Cost"
position: 14
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Three topics that rarely get their own question but are asked as follow-ups in almost every design: "how would you know this is broken?", "how do you keep this secure?", and "what does this cost?". Two sentences on each, delivered unprompted at the end of a design, is one of the cheapest ways to look like someone who has run a system rather than only drawn one.

## The three pillars, and the metrics that matter

**Metrics** — cheap numeric time series, good for alerting and dashboards. **Logs** — expensive, high-cardinality, good for a specific incident. **Traces** — one request's path across services, good for "where did the 900 ms go?". Metrics tell you *that* something is wrong; traces tell you *where*; logs tell you *why*.

Two mnemonics cover almost every dashboard you will ever need:

- **RED — for request-driven services**: **R**ate (requests/sec), **E**rrors (failures/sec or %), **D**uration (latency distribution).
- **USE — for resources** (CPU, disk, pool, queue): **U**tilisation, **S**aturation (queue depth, wait time), **E**rrors.

**Percentiles, not averages.** An average latency of 100 ms is compatible with 5% of users waiting 3 seconds. Track p50, p95, p99, and p99.9, and remember the arithmetic that makes tails matter: if a page makes 10 backend calls, the chance of at least one hitting the p99 is about 1 − 0.99¹⁰ ≈ **10%**. Tail latency is the median experience of a page.

Never average percentiles across hosts — that number means nothing. Aggregate from histograms.

**Correlation is the piece candidates miss.** A trace/request id generated at the edge, propagated through every service (W3C `traceparent`), and stamped on every log line is what lets you go from an alert to the exact request in under a minute. Say "I'd propagate a trace id and include it in every log line and error response" — it is small, concrete, and rarely mentioned.

**Alert on symptoms, not causes.** Page on "checkout error rate above 1% for 5 minutes" (a user-visible SLO breach), not on "CPU above 80%" (which may be entirely fine). Every page needs a runbook and a human action; anything else is a dashboard, and an alert nobody acts on trains people to ignore alerts.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-14-observability-q1", "type": "mcq",
      "prompt": "A page makes 10 backend calls, each with a p99 latency of 500 ms. Roughly what fraction of page loads will contain at least one p99-slow call?",
      "options": [
        {"id":"a","text":"About 1%, the same as a single call"},
        {"id":"b","text":"About 10% — 1 − 0.99¹⁰ — which is why tail latency, not average latency, defines the user experience of a fan-out page"},
        {"id":"c","text":"About 0.1%, since the calls are independent"},
        {"id":"d","text":"100%, because latencies add up"}
      ],
      "correct": "b",
      "explanation": "Tail amplification: with fan-out, the probability of hitting the tail at least once grows with the number of calls. It is the standard argument for hedged requests, tighter timeouts, and reducing fan-out." }
] }
```

## Security in a design interview

You will not be asked to design a security system, but you are expected to place the right controls on the diagram.

**Authentication vs authorization.** AuthN = who you are; AuthZ = what you may do. Say both words, in the right places.

| Mechanism | Shape | Trade-off |
|---|---|---|
| Session cookie + server store | Server holds session state | Revocation is instant; needs a shared session store |
| **JWT** (signed, stateless) | Claims carried by the client | No lookup per request; **revocation is hard** — mitigate with short expiry + refresh tokens |
| OAuth 2.0 / OIDC | Delegated auth, third-party identity | Standard for "sign in with…" and third-party API access |
| API keys | Long-lived shared secret | Simple for partners; must be rotatable and scoped |
| mTLS | Both sides present certificates | The service-to-service standard inside a mesh |

The JWT trade-off is a favourite: stateless verification is why they scale, and it is exactly why you cannot revoke one before it expires. The standard answer is short-lived access tokens (5–15 minutes) plus a refresh token that *is* checked against a revocation list.

**Authorization models**: RBAC (roles → permissions) covers most systems; ABAC adds attribute-based rules ("owner of the resource, during business hours"); and for a multi-tenant system the essential rule is that **every query is scoped by tenant at the data layer**, not by a check in a controller someone can forget. A row-level policy or a mandatory `WHERE org_id = ?` in a shared repository is the design answer.

**The list to run over your own diagram:**

- **Transport**: TLS everywhere, including service-to-service (mTLS in a mesh). No plaintext internal hops.
- **At rest**: disk/database encryption, and field-level encryption for the sensitive columns; keys in a KMS with rotation, never in code or environment variables committed anywhere.
- **Secrets**: a secret manager, short-lived credentials, rotation. This is where "no hardcoded fallback" is a security control, not a style rule.
- **Input validation at the boundary**, parameterised queries always (SQL injection), output encoding (XSS), and CSRF protection for cookie-authenticated browsers.
- **SSRF**: any feature that fetches a user-supplied URL must resolve and check the destination against a denylist of internal ranges — the classic path to cloud metadata credentials.
- **Rate limiting and quotas** per identity: security control as much as a capacity one.
- **PII**: know where it lives, minimise it, encrypt it, set a retention period, and be able to delete it on request (GDPR/DPDP). Data residency may force geographic partitioning.
- **Audit log**: who did what to which resource, when — append-only, separate from application logs.
- **Least privilege**: each service gets its own credentials, scoped to its own tables/buckets. A compromised recommendation service must not be able to read the payments table.

**Defence in depth** is the framing to use: WAF and DDoS protection at the edge, auth at the gateway, authorization in the service, constraints in the database. No single layer is the whole answer.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-14-security-q1", "type": "mcq",
      "prompt": "What is the main operational drawback of stateless JWTs, and the standard mitigation?",
      "options": [
        {"id":"a","text":"They are too large to send in headers; mitigate by compressing them"},
        {"id":"b","text":"They cannot be revoked before expiry, since verification requires no server lookup; mitigate with short-lived access tokens plus a refresh token that is checked against a revocation store"},
        {"id":"c","text":"They cannot carry user identity; mitigate by adding a session cookie"},
        {"id":"d","text":"They require a database read on every request; mitigate with caching"}
      ],
      "correct": "b",
      "explanation": "The property that makes JWTs scale — no server-side lookup — is exactly what makes revocation impossible. Short expiry bounds the damage window; the refresh token is the stateful piece you can actually revoke." }
] }
```

## Cost, and the deployment story

**Cost is a design constraint**, and mentioning it is a differentiator because so few candidates do.

Rough order of magnitude, useful for reasoning rather than quoting:

| Resource | Relative cost | Design implication |
|---|---|---|
| Compute (on-demand VM) | Baseline | Autoscale; use spot/preemptible for batch and workers |
| Object storage (S3 standard) | ~1/20th of block storage per GB | Blobs never belong in the database |
| Cold/archive storage | ~1/5th of standard | Lifecycle policies for old data |
| Managed database | Several × raw compute | Worth it; but don't run five kinds |
| **Cross-region / internet egress** | **The line item that surprises people** | CDN offload; keep chatty traffic inside one region |
| Logs and metrics retention | Grows silently, often 10%+ of the bill | Sample, aggregate, set retention |

Four decisions that dominate the bill: **where the bytes are stored** (object storage plus a CDN instead of a database and your own servers), **how much data crosses a network boundary** (egress and cross-AZ), **how long you retain** (raw data downsampled and lifecycled), and **how much headroom you keep idle** (autoscaling, spot capacity, right-sizing).

A sentence that lands well: *"Serving 75 Gbps from our origin would dominate the bill, so the CDN isn't only a latency decision — it's the cost decision."*

**Deployment and change**, the last third of the operational story:

- **Blue-green**: two full environments, flip traffic, roll back instantly. Costs double capacity during the switch.
- **Canary**: 1% → 10% → 100%, watching SLIs, with automatic rollback. The default for most systems.
- **Rolling**: replace instances gradually; needs connection draining and both versions being compatible simultaneously.
- **Feature flags**: decouple deploy from release, so you can turn a subsystem off without a rebuild — and so a bad feature is a config change to fix, not a redeploy.
- **Backward-compatible migrations**: expand → migrate → contract. Add the new column and dual-write, backfill, switch reads, then drop the old column in a later release. Never a single migration that both adds and removes.

**Multi-tenancy**, since it shapes every SaaS design: shared database with a `tenant_id` on every row (cheapest, needs airtight scoping), schema per tenant (middle ground, migration overhead grows with tenant count), or database per tenant (strongest isolation, heaviest operations). The usual answer is shared-with-`tenant_id`, plus dedicated databases for the few enterprise customers who need isolation — which is also the hot-shard fix from the sharding lesson.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-14-cost-q1", "type": "mcq",
      "prompt": "You need to add a NOT NULL column to a large table used by a running service. What is the safe sequence?",
      "options": [
        {"id":"a","text":"One migration that adds the column as NOT NULL with a default, during peak hours"},
        {"id":"b","text":"Expand → migrate → contract: add the column nullable, deploy code that writes both old and new, backfill in batches, switch reads to the new column, then make it NOT NULL and drop the old one in a later release"},
        {"id":"c","text":"Take the service offline for the duration of the migration"},
        {"id":"d","text":"Create a new table and copy everything in a single transaction"}
      ],
      "correct": "b",
      "explanation": "Old and new code run simultaneously during any rollout, so every migration step must be compatible with both. Expand–migrate–contract keeps each individual deploy reversible, which is the property that makes rollbacks safe." }
] }
```

## Key takeaways

**The recall card:**

```
Observability: metrics (that) → traces (where) → logs (why)
  RED for services: Rate, Errors, Duration.   USE for resources: Utilisation, Saturation, Errors
  p50/p95/p99/p99.9 — never averages, never averaged percentiles
  Fan-out amplifies tails: 10 calls at p99=1% ⇒ ~10% of pages hit it
  Propagate a trace id into every log line and error response
  Alert on symptoms (SLO breach) with a runbook — not on CPU

Security: authN ≠ authZ · JWT scales but can't be revoked (short TTL + refresh)
  TLS in transit + mTLS internally · encryption at rest + KMS · secrets manager
  Validate at the boundary · parameterised queries · CSRF · SSRF denylist
  Tenant scoping at the DATA layer, not the controller · least privilege per service
  PII: minimise, encrypt, retain briefly, be able to delete · audit log, append-only

Cost: egress and retention are the surprises · blobs → object storage + CDN
      autoscale + spot for batch · sample logs · lifecycle old data

Deploy: canary with auto-rollback (default) · blue-green (instant rollback, 2× cost)
        feature flags decouple deploy from release
        migrations: EXPAND → MIGRATE → CONTRACT, never both at once
Multi-tenant: shared + tenant_id (default) · schema per tenant · DB per tenant (isolation)
```

- **Close every design with two sentences on observability.** "I'd alert on the checkout SLO with RED metrics per service, and propagate a trace id so a page maps to a single request trace" costs 10 seconds and reads as operational maturity.
- **Security belongs on the diagram**, not in a separate speech: TLS on the arrows, auth at the gateway, tenant scoping in the data layer, secrets in a manager.
- **Naming the cost driver is a senior move** — usually egress, storage tier, or retention, rarely CPU.
- **Migrations and deploys are part of the design.** Expand–migrate–contract and canary-with-rollback show you have thought past the first launch.

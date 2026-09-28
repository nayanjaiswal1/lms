---
kind: lesson
id_key: interview-prep-45/hld-14-observability-security
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Observability, Security, and Cost"
position: 14
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Three topics rarely get their own dedicated question in a design interview, but they show up as follow-ups in almost every single one: "how would you know this is broken?", "how do you keep this secure?", and "what does this actually cost?" Adding two sentences on each of these, without being asked, at the end of your design, is one of the cheapest ways to sound like someone who has actually run a real system, not just someone who's drawn one.

## The three pillars, and the metrics that matter

Picture a hospital. A heart-rate monitor's beeping alarm is a metric: cheap, instant, and it tells you *something* is wrong right now. An X-ray is a trace: it shows *where* the problem actually is. The patient's full case file is a log: it tells you *why*, in detail, after everything's already happened. **Metrics** are cheap, simple numeric measurements over time, good for dashboards and alerts. **Logs** are more expensive and detailed, and good for digging into one specific incident. **Traces** follow one single request's path across every service it touches, and answer "where did those 900 milliseconds actually go?"

Two short phrases cover almost every dashboard you'll ever need to build.

- **RED, for request-driven services**: **R**ate, meaning requests per second; **E**rrors, meaning failures per second or as a percentage; **D**uration, meaning the spread of how long requests take.
- **USE, for a specific resource** like CPU, disk, a connection pool, or a queue: **U**tilisation, how busy it is; **S**aturation, how deep its queue or wait time is; **E**rrors, how often it fails.

**Look at percentiles, not averages.** An average response time of 100 milliseconds is perfectly compatible with 5% of users waiting a full 3 seconds. Track the 50th, 95th, 99th, and 99.9th percentiles, usually written p50, p95, p99, and p99.9. Here's the arithmetic that makes the slowest requests, called the tail, matter so much: if loading one page makes 10 separate backend calls, the chance that at least one of those calls hits its own worst 1% of cases is about `1 − 0.99¹⁰`, which works out to roughly **10%**. In other words, tail latency, not average latency, is what most users actually experience on a page that fans out to many services.

Never average percentiles taken from different servers together; that combined number means nothing meaningful. Instead, combine the raw distributions (called histograms) first, then calculate the percentile from that.

**The piece most people forget is tying it all together.** Generate a single trace or request ID right at the edge of your system, pass it along through every single service the request touches, using a shared standard like W3C's `traceparent` header, and stamp that same ID onto every log line. That's what lets you go from a single alert straight to the exact request that caused it, in under a minute. Saying "I'd propagate a trace ID and include it in every log line and error response" is small, concrete, and something surprisingly few people actually mention.

**Alert on symptoms, not on underlying causes.** Page someone when "the checkout error rate is above 1% for 5 minutes," since that's a real, user-visible problem, not when "CPU usage is above 80%," which might be completely fine on its own. Every page that wakes someone up should come with a clear runbook and a real action they can take; anything short of that belongs on a dashboard instead, since an alert that nobody ever acts on just trains everyone to start ignoring alerts.

> **Remember:** metrics say something is wrong, traces say where, logs say why. A page needs a tag connecting all three, or you're guessing which request the alarm was even about.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-14-observability-q1", "type": "mcq",
      "prompt": "A page makes 10 backend calls, each with a p99 latency of 500 milliseconds, meaning 1% of calls are that slow or slower. Roughly what fraction of page loads will include at least one of these slow calls?",
      "options": [
        {"id":"a","text":"About 1%, the same as for a single call"},
        {"id":"b","text":"About 10%, calculated as 1 minus 0.99 raised to the 10th power, which is exactly why tail latency, not average latency, defines what users actually experience on a page that fans out to many calls"},
        {"id":"c","text":"About 0.1%, since the calls are independent of each other"},
        {"id":"d","text":"100%, because the latencies simply add together"}
      ],
      "correct": "b",
      "explanation": "This effect is called tail amplification: when a page fans out to many calls, the probability of hitting a slow tail at least once grows with the number of calls made. It's the standard reason behind hedged requests, tighter timeouts, and simply reducing how many calls one page makes." }
] }
```

## Security in a design interview

You won't be asked to design a whole security system from scratch, but you are expected to place the right kinds of controls onto your own diagram.

Picture a concert venue. A ticket scanner checking your ID at the main gate answers the question "who are you?" A completely separate check at the door of the VIP lounge answers a different question: "are you actually allowed in here?" Those are two distinct jobs, and mixing them up is a common way real systems end up getting breached.

**Authentication versus authorization.** Authentication, often shortened to AuthN, means confirming who you are. Authorization, shortened to AuthZ, means deciding what you're allowed to do. Use both words, in the right places, when you describe your design.

| Mechanism | How it works | Trade-off |
|---|---|---|
| Session cookie plus a server-side store | The server itself holds onto the session state | Revoking access is instant, but you need a shared store for sessions across servers |
| **JWT**, short for JSON Web Token (signed, and stateless) | The client itself carries its own claims about who it is | No lookup needed on each request, but **revoking one before it expires is genuinely hard**; mitigated with a short expiry plus a separate refresh token |
| OAuth 2.0 / OIDC | Lets a third party handle identity on your behalf | The standard approach for "sign in with Google" style flows, and for third-party API access |
| API keys | A long-lived secret shared with a partner | Simple to hand out, but it must be possible to rotate and scope them |
| mTLS, short for mutual TLS | Both sides present a certificate to prove who they are | The usual standard for service-to-service calls inside a mesh |

The JWT trade-off comes up often: the very thing that makes them scale so well, needing no lookup on the server at all, is exactly what makes revoking one before it expires so hard. The standard answer is to use short-lived access tokens, lasting 5 to 15 minutes, alongside a separate refresh token that genuinely *is* checked against a list of revoked tokens.

**A few common models for authorization.** RBAC, short for role-based access control, meaning roles map to permissions, covers most systems well enough. ABAC, short for attribute-based access control, adds rules based on attributes, like "the owner of this resource, and only during business hours." For any system serving multiple separate customers, called multi-tenant, the essential rule is that **every single query is scoped to the correct tenant at the data layer itself**, not by a check placed inside a controller that someone could easily forget to add. A row-level security policy, or a mandatory `WHERE org_id = ?` clause baked into a shared repository layer, is the right kind of design answer here.

**Here's a checklist worth running over your own diagram.**

- **In transit**: use encryption everywhere, including between your own services, using mTLS inside a mesh. No internal connection should ever be sent in plain text.
- **At rest**: encrypt the disk and the database, and add extra field-level encryption for especially sensitive columns; keep encryption keys in a dedicated key management service with rotation, never in code or in an environment variable that gets committed anywhere.
- **Secrets**: use a proper secret manager, short-lived credentials, and rotation. This is exactly where "never hardcode a fallback secret" becomes a real security control, not just a style preference.
- **Validate every input at the boundary**, always use parameterised queries to prevent SQL injection, encode output to prevent cross-site scripting, and add CSRF protection for any browser using cookie-based login.
- **SSRF**, short for server-side request forgery: any feature that fetches a URL supplied by a user must resolve that address and check it against a list of blocked internal ranges. This is the classic path attackers use to reach a cloud provider's internal credential service.
- **Rate limiting and quotas per identity** are a security control just as much as a capacity one.
- **PII**, personally identifiable information: know exactly where it lives, collect as little of it as you can, encrypt it, set a retention period, and be able to delete it on request, as laws like GDPR or India's DPDP require. Legal rules about where data may live can force you to partition data by geography.
- **An audit log**: a separate, append-only record of who did what to which resource, and when, kept apart from your regular application logs.
- **Least privilege**: give each service its own credentials, scoped only to the specific tables or storage buckets it actually needs. A compromised recommendation service should never be able to read your payments table.

**"Defence in depth" is the framing to use here**: a web application firewall and DDoS protection at the edge, authentication at the gateway, authorization inside each service, and constraints enforced by the database itself. No single one of these layers is ever the whole answer on its own.

> **Remember:** authentication answers "who are you," authorization answers "what can you do." A JWT scales beautifully because there's no lookup, but that's also exactly why revoking one before it expires is hard.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-14-security-q1", "type": "mcq",
      "prompt": "What is the main operational drawback of stateless JWTs, and what is the standard way to soften it?",
      "options": [
        {"id":"a","text":"They are too large to fit in a request header; fix it by compressing them"},
        {"id":"b","text":"They cannot be revoked before they expire, since checking one requires no lookup on the server at all; soften this with short-lived access tokens plus a refresh token that is checked against a revocation list"},
        {"id":"c","text":"They cannot carry a user's identity at all; fix it by adding a session cookie alongside it"},
        {"id":"d","text":"They require a database read on every single request; fix it with caching"}
      ],
      "correct": "b",
      "explanation": "The exact property that makes JWTs scale so well, needing no server-side lookup, is also exactly what makes revoking one before it expires impossible. A short expiry time limits how long the damage window can last, and the refresh token is the one stateful piece that can actually be revoked." }
] }
```

## Cost, and the deployment story

Picture a family choosing between cooking every meal at home or ordering delivery every single night. Delivery is convenient, but the delivery fee, the cost of physically moving food across the city, is the surprise cost that quietly adds up, not the price of the food itself. In cloud systems, moving data across a network boundary, called egress, is exactly that delivery fee, and it's the line item on the bill that catches people off guard.

**Cost is a real design constraint**, and simply mentioning it sets you apart, because so few people actually do.

**Here is a rough sense of relative cost, useful for reasoning about trade-offs, not for quoting exact numbers:**

| Resource | Relative cost | What it implies for your design |
|---|---|---|
| Compute (an on-demand virtual machine) | The baseline | Scale it automatically; use cheaper, interruptible capacity for batch jobs and background workers |
| Object storage | Roughly a twentieth of the cost of block storage, per gigabyte | Large files should never live directly inside your database |
| Cold or archive storage | Roughly a fifth of the cost of standard storage | Set up policies to automatically move old data there |
| A managed database | Several times the cost of raw compute | Usually worth it, but don't end up running five different kinds at once |
| **Cross-region or internet egress** | **The line item that most often surprises people** | Offload it to a CDN; keep chatty, frequent traffic inside a single region |
| Storing logs and metrics | Grows quietly over time, often more than 10% of the total bill | Sample it, aggregate it, and set a clear retention period |

Four decisions dominate almost every cloud bill: **where your bytes physically live** (object storage plus a CDN, instead of a database and your own servers), **how much data crosses a network boundary** (egress, and traffic between availability zones), **how long you keep data around** (shrinking and expiring old data on a schedule), and **how much spare capacity you keep sitting idle** (autoscaling, cheaper interruptible capacity, and right-sizing your servers).

A sentence that lands well in an interview: *"Serving 75 gigabits per second directly from our own servers would dominate the bill entirely, so choosing a CDN isn't only about latency; it's also the cost decision."*

**Deployment and change management make up the final third of running a real system.**

- **Blue-green deployment**: run two full, separate environments, and simply flip traffic between them, which allows an instant rollback. It costs double the capacity for the duration of the switch.
- **Canary deployment**: gradually shift traffic from 1%, to 10%, to everyone, watching your metrics the whole way, with an automatic rollback if something looks wrong. This is the default choice for most systems.
- **Rolling deployment**: replace servers gradually, one at a time. This needs connections to drain properly, and both the old and new versions of your code need to work correctly side by side for a while.
- **Feature flags**: separate the act of deploying code from the act of releasing a feature to users, so you can turn a broken part of the system off with a simple configuration change instead of a full new deploy.
- **Backward-compatible database migrations**: follow the pattern of expand, then migrate, then contract. Add a new column that allows empty values, write to both the old and new column at once, backfill existing data in batches, switch reads over to the new column, and only then, in a later release, remove the old column. Never combine adding something and removing something in one single migration.

**Multi-tenancy shapes nearly every software-as-a-service design, and there are three common approaches.** A shared database with a `tenant_id` column on every row is the cheapest, but needs airtight, careful scoping everywhere. A separate schema per tenant is a middle ground, though the overhead of running migrations grows as you add more tenants. A completely separate database per tenant gives the strongest isolation, at the heaviest operational cost. The usual answer most systems land on is a shared database with `tenant_id`, plus dedicated, separate databases reserved for the few large enterprise customers who genuinely need full isolation, which is also the standard fix for a hot-shard problem covered in an earlier lesson.

> **Remember:** moving bytes across a network boundary, called egress, is usually the cost surprise, not compute. A CDN is a cost decision just as much as it is a speed decision.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-14-cost-q1", "type": "mcq",
      "prompt": "You need to add a required column, one that cannot be empty, to a large table used by a service that's currently running. What is the safe sequence of steps?",
      "options": [
        {"id":"a","text":"Run one single migration that adds the column as required, with a default value, during peak traffic hours"},
        {"id":"b","text":"Expand, then migrate, then contract: add the column allowing empty values first, deploy code that writes to both the old and new columns, backfill existing data in batches, switch reads over to the new column, and only then make it required and drop the old column in a later release"},
        {"id":"c","text":"Take the whole service offline for the entire duration of the migration"},
        {"id":"d","text":"Create a brand new table and copy everything over inside a single transaction"}
      ],
      "correct": "b",
      "explanation": "Both the old and new versions of your code run side by side during any rollout, so every single step of a migration has to remain compatible with both of them at once. Following expand, then migrate, then contract keeps every individual deploy safely reversible, which is exactly the property that makes rollbacks actually safe to do." }
] }
```

## Quick recap

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

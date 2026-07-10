# Learning Notes

Running notes from architecture discussions — the reasoning behind decisions, not just the decisions themselves.

---

## ID Generation: UUID vs Snowflake vs ULID vs KSUID (2026-07-05)

### The options

| Scheme | Size | Ordered? | Needs coordination? | Notes |
|---|---|---|---|---|
| **UUID v4** | 128-bit | No — random | No | Non-enumerable, native Postgres `uuid` type. Random insert order causes index page-splits on high-write tables. |
| **UUID v7** | 128-bit | Yes — ms timestamp prefix | No | Same `uuid` column type as v4, just a different generator. Time-sortable, still non-enumerable. |
| **Snowflake ID** | 64-bit int | Yes — ms timestamp + worker/sequence bits | **Yes** — needs a unique worker ID per generating process | Solves "many writers minting IDs without hitting a shared DB." Sequential → guessable. |
| **ULID** | 128-bit | Yes — ms timestamp + random tail | No | Same idea as UUIDv7; needs encoding to fit a native `uuid` column. |
| **KSUID** | 160-bit | Yes — second-precision timestamp + random tail | No | Bigger than UUID, coarser precision, no native Postgres type (stored as `text`). |

### Where MindForge landed ([[project-id-column-convention]] in memory, decided 2026-07-01)

- **UUID `DEFAULT gen_random_uuid()`** — externally addressable entities (users, orgs, courses, assessments). Needs enumeration resistance for public URLs/shareable links.
- **`BIGINT GENERATED ALWAYS AS IDENTITY`** — internal, append-only, high-volume tables never looked up by client-supplied id (`attempt_events`, `audit_logs`, `xp_events`, `lab_usage_events`, `job_runs`). Compact, naturally time-ordered by insertion, zero coordination needed because Postgres is the single serializing writer.
- **Composite PK, no surrogate id** — pure junction tables (`batch_members`, `batch_mentors`, `batch_courses`, `role_permissions`, `user_roles`).

### Why not Snowflake

Snowflake exists to solve a specific problem: multiple independent writers minting globally-unique IDs *without* a round trip to a shared DB — Twitter's original scale problem. MindForge doesn't have that problem:

1. **Every write already round-trips through a single Postgres cluster.** Postgres itself is the serializing writer. `BIGINT IDENTITY` already gives a monotonic, collision-free, compact ID for free — no coordinator needed.
2. **Snowflake needs worker-ID coordination across replicas.** `docs/infrastructure.md` already documents Redis-backed rate limiting specifically because backend state has to be shared "across all replicas." Snowflake would need the same kind of coordination for worker-ID leasing — either brittle static config per replica (breaks on autoscale/redeploy) or a Redis/etcd leader-election scheme. That's new infra and a new failure mode (ID generation stalls if the coordinator is unreachable) for a problem that doesn't exist yet.
3. **Clock-rollback handling is a pure availability cost.** NTP corrections or VM migrations can move the clock backward; Snowflake generators must detect and stall. No such failure mode exists today.
4. **Sequential IDs are the wrong shape for externally-facing tables.** Snowflake IDs are dense and ordered — `id+1` is a valid guess. That's exactly the enumeration risk UUID was chosen to avoid for users/orgs/courses/assessments.

**When Snowflake would actually make sense:** sharded Postgres (or any multi-master datastore) with no single sequence authority — i.e., once a single Postgres cluster genuinely can't keep up. That's a decision to make with real throughput numbers in hand, not preemptively.

### "We can just get the datacenter/machine ID" undersells the complication

Reading a machine ID is easy. *Guaranteeing it's unique among every process alive right now* is not — and that guarantee is the entire value Snowflake claims to provide. Where the "just hardcode it" approach actually breaks:

1. **Rolling deploys overlap.** A static `WORKER_ID` per replica (e.g., 0, 1) isn't atomic across a deploy — the outgoing and incoming container are briefly alive together with the same ID, both minting IDs. Collision window on every single deploy.
2. **Autoscaling/restarts don't remember assignments.** A crashed replica restarting, or scaling 2→4 replicas, needs something that knows what's *currently* alive so it doesn't reissue a taken ID. A static env-var mapping can't know that — only a live lease/registry (claim slot, TTL, renew, only reclaimable after expiry) can. That registry **is** the coordination service being avoided in the first place.
3. **IP-hash / hostname shortcuts aren't stable.** Container IPs recycle fast; plain Docker Compose `--scale` doesn't give stable hostnames the way a Kubernetes StatefulSet ordinal does. These shortcuts are probabilistic, not a guarantee — and Snowflake's whole pitch is a guarantee.
4. **The honest caveat:** with exactly one backend instance, forever, hardcoding `worker_id=0` is genuinely fine. The trap is that it's an *undocumented, invisible contract* — nothing stops a later change (e.g., scaling for the Redis-backed rate limiter already anticipated in `docs/infrastructure.md`) from silently violating it. The failure mode isn't a crash, it's two different rows in two different tables quietly sharing an ID, surfacing only when a join returns the wrong record.

Postgres's sequence generator doesn't have this problem by construction — there's exactly one writer doing the counting (Postgres itself), not N independent processes each guessing their own slice of the ID space.

### The broader principle: "build it scalable" ≠ "pre-wire future infra"

"Scalable" means *not building a wall you can't get past later* — not *pre-building every mechanism a bigger system might eventually need*.

- A **wall** = something that requires a rewrite to change later (e.g., baking tenant_id out of the schema).
- A **future optimization** = swapping the *implementation* behind a stable interface.

ID generation is the second kind. Moving UUID v4 → UUID v7, or a single Postgres sequence → a sharded ID scheme, changes only the generator function — the column type (`uuid` or `bigint`) and every piece of code that treats IDs as opaque values stay untouched. That seam is what makes the current design already scalable: the future change, if it's ever needed, stays small and isolated.

Adopting Snowflake now would front-load real, ongoing costs (coordination infra, a new incident class, sequential/enumerable IDs on public tables) for a benefit that only materializes if MindForge ever outgrows a single Postgres cluster — a threshold nowhere close to being hit, and one best decided with actual data when it happens.

**Verdict:** keep UUID v4 (or v7 later, if insert-order locality becomes a measured problem) for external-facing tables, `BIGINT IDENTITY` for internal logs, composite PK for junctions. No Snowflake.

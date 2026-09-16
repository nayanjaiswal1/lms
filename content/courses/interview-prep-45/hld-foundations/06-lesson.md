---
kind: lesson
id_key: interview-prep-45/hld-06-caching
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Caching and CDNs"
position: 6
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Caching is the cheapest order-of-magnitude you will ever buy, and the most common source of subtle production bugs. In interviews it comes up twice: once when you add Redis to the diagram, and again fifteen minutes later when the interviewer asks "so how does the cache get invalidated?" — which is the question that separates people who have run a cache from people who have drawn one.

## Where caches live

There is not "a cache" — there is a stack of them, and naming the layer you mean is half the answer.

| Layer | Example | Typical TTL | Invalidation |
|---|---|---|---|
| Client / browser | `Cache-Control: max-age`, service worker | minutes–days | Content-hashed URLs |
| CDN / edge | CloudFront, Cloudflare, Fastly | minutes–days | Purge API, hashed URLs |
| Reverse proxy | nginx / Varnish page cache | seconds–minutes | TTL, purge |
| Application (in-process) | local LRU map, Caffeine | seconds | TTL only — per-node, can't be purged coherently |
| Distributed cache | Redis, Memcached | minutes–hours | Explicit delete on write |
| Database | Postgres buffer pool, query plan cache | — | Automatic |
| Materialised view / precomputed | timeline in Redis, rollup table | until recomputed | Recompute on event |

Two rules of placement:

1. **Cache as close to the user as the data's freshness requirement allows.** A product image can sit in a browser for a year (content-hashed filename); a stock price cannot sit anywhere for more than a second.
2. **In-process caches cannot be invalidated coherently.** With 20 app instances you have 20 independent copies and no way to purge them all reliably. Use them only for data where bounded staleness (a short TTL) is genuinely acceptable — feature flags, config, reference data.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-layers-q1", "type": "mcq",
      "prompt": "Why is an in-process (per-instance) cache a poor fit for data that must be invalidated the instant it changes?",
      "options": [
        {"id":"a","text":"In-process caches are too slow"},
        {"id":"b","text":"Every instance holds its own independent copy, so there is no single place to purge — you would need to reliably broadcast an invalidation to every node, and any node that missed it serves stale data"},
        {"id":"c","text":"In-process caches cannot store objects, only strings"},
        {"id":"d","text":"They consume database connections"}
      ],
      "correct": "b",
      "explanation": "Coherent invalidation needs a single authority. That is exactly what a shared Redis gives you and a per-node map does not — a per-node map is only safe when a short TTL's worth of staleness is acceptable." }
] }
```

## The four caching patterns

**Cache-aside (lazy loading)** — the default, and what you should say unless there's a reason not to. The application owns the cache.

```python
def get_user(user_id):
    key = f"user:{user_id}"
    cached = redis.get(key)
    if cached is not None:
        return json.loads(cached)          # hit

    user = db.query("SELECT * FROM users WHERE id = %s", user_id)  # miss
    if user is not None:
        redis.setex(key, 300, json.dumps(user))                    # populate with a TTL
    return user

def update_user(user_id, changes):
    db.update("users", user_id, changes)
    redis.delete(f"user:{user_id}")        # invalidate, don't rewrite — see below
```

Only requested data is cached, and a cache outage degrades to slow rather than broken. The costs: every miss pays DB latency, and there is a window between the DB write and the cache delete where a concurrent reader can repopulate the old value.

**Write-through** — write to cache and database together, synchronously. The cache is never stale; every write pays both latencies, and you cache data nobody may ever read.

**Write-behind (write-back)** — write to cache, acknowledge, flush to the database asynchronously in batches. Very fast writes, excellent for high-volume counters and metrics; you can lose data if the cache dies before the flush. Only acceptable when the data is not critical or is reconstructible.

**Refresh-ahead** — proactively refresh hot keys before their TTL expires, so users never hit the miss. Great for a small set of predictably-hot keys; wasteful if you guess wrong.

| Pattern | Read latency | Write latency | Staleness | Data-loss risk |
|---|---|---|---|---|
| Cache-aside | Fast on hit, slow on miss | DB only | Small window | None |
| Write-through | Always fast | DB + cache | None | None |
| Write-behind | Always fast | Cache only | None in cache | **Yes** |
| Refresh-ahead | Always fast | DB only | Bounded | None |

**Invalidate, don't update.** On a write, delete the key rather than writing the new value into it. Two concurrent writers that each update the cache can interleave so the cache ends up holding the *older* value permanently; a delete makes the next read repopulate from the source of truth. If you need to close even the delete's race window, use **delayed double delete**: delete, write the DB, then delete again a few hundred milliseconds later.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-patterns-q1", "type": "mcq",
      "prompt": "On updating a row, why is `redis.delete(key)` generally safer than `redis.set(key, newValue)`?",
      "options": [
        {"id":"a","text":"Delete is faster than set"},
        {"id":"b","text":"Two concurrent writers' set operations can interleave so the older value lands last and stays cached indefinitely; a delete forces the next read to repopulate from the source of truth"},
        {"id":"c","text":"Redis does not support set on existing keys"},
        {"id":"d","text":"Delete frees memory, which is always preferable"}
      ],
      "correct": "b",
      "explanation": "Writer A reads v1, writer B writes v2 and sets the cache, then A's delayed set writes v1 — the cache now permanently disagrees with the database. Deleting removes the possibility: worst case is an extra miss." }
] }
```

## Eviction, TTLs, and hit rate

**Eviction policies** — what to drop when memory is full:

| Policy | Drops | Best for |
|---|---|---|
| **LRU** | Least recently used | General purpose — the default |
| **LFU** | Least frequently used | Stable hot sets; resists a scan flushing your hot keys |
| FIFO | Oldest inserted | Rarely right |
| Random | A random key | Surprisingly decent, very cheap |
| TTL-only (`volatile-*`) | Only keys with an expiry | When some keys must never be evicted |

Redis's `allkeys-lru` and `allkeys-lfu` are the two you will name in practice. LFU's advantage: one big analytical scan touching a million cold keys does not evict your hot set, because recency alone doesn't promote them.

**TTLs do two jobs**: they bound staleness, and they are your safety net for invalidation bugs. Always set one, even when you also delete explicitly. A cache with no TTL and one missed invalidation is a permanently wrong answer.

**Add jitter to TTLs.** If 10,000 keys are populated in the same second with the same 300 s TTL, they all expire in the same second and the resulting stampede hits your database at once. Use `300 + random(0, 60)`.

**Hit rate is the number that matters.** A cache at 50% hit rate is doing very little; 95%+ is where the order-of-magnitude lives. Track hits, misses, evictions, and memory used — a rising eviction rate means the working set no longer fits and the hit rate is about to collapse.

Sizing rule of thumb: the classic 80/20 shape means caching the hot 20% of keys gets you ~80% of requests. Estimate the working-set bytes, not the total-data bytes.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-eviction-q1", "type": "mcq",
      "prompt": "A nightly batch job scans every user record. Under which eviction policy is it LEAST likely to flush the hot keys real users depend on?",
      "options": [
        {"id":"a","text":"LRU — the scanned keys become the most recently used and push out the hot set"},
        {"id":"b","text":"LFU — the scanned keys are each touched once, so they never accumulate enough frequency to displace genuinely hot keys"},
        {"id":"c","text":"FIFO"},
        {"id":"d","text":"No eviction policy at all"}
      ],
      "correct": "b",
      "explanation": "This is the classic scan-resistance argument for LFU. Under LRU a single sequential scan promotes a million cold keys to \"most recent\" and evicts the working set, so the next morning starts at a near-zero hit rate." }
] }
```

## The three failure modes: stampede, penetration, avalanche

Naming these unprompted is a strong senior signal.

**1. Cache stampede (thundering herd).** A hot key expires; 5,000 concurrent requests all miss and all query the database for the same row. The database falls over.

Fixes, in order of preference:
- **Request coalescing / single-flight**: the first miss acquires a short lock (`SET key:lock nx ex 5`); everyone else waits briefly and re-reads the cache.
- **Probabilistic early expiry**: each reader recomputes with a probability that rises as the TTL approaches, so exactly one tends to refresh early.
- **Serve stale while revalidating**: return the expired value immediately and refresh in the background — the standard CDN behaviour (`stale-while-revalidate`).

**2. Cache penetration.** Requests for keys that do not exist in the database at all (often malicious, e.g. `GET /users/999999999` in a loop). Every request misses the cache *and* misses the database.

Fixes: **cache the negative result** (`user:999 → NULL`, short TTL), and/or put a **Bloom filter** of existing keys in front — a Bloom filter can say "definitely not present" cheaply, which is exactly the question being abused.

**3. Cache avalanche.** A large fraction of the cache expires or is lost at once (mass TTL expiry, or a Redis restart) and the full production load lands on the database cold.

Fixes: **TTL jitter**, cache **warming** on startup before the node is marked ready, a replicated/persistent cache tier so a restart is not a cold start, and a **circuit breaker** in front of the database so the stampede degrades to errors on some requests rather than a total collapse.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-failures-q1", "type": "mcq",
      "prompt": "An attacker repeatedly requests IDs that don't exist, so every request misses both cache and database. What is this called and what is the standard fix?",
      "options": [
        {"id":"a","text":"Cache stampede — fix with a lock so only one request refills"},
        {"id":"b","text":"Cache penetration — cache the negative result with a short TTL, and/or front the cache with a Bloom filter of existing keys"},
        {"id":"c","text":"Cache avalanche — fix with TTL jitter"},
        {"id":"d","text":"Cache invalidation — fix by deleting keys on write"}
      ],
      "correct": "b",
      "explanation": "Penetration is the miss-miss pattern for keys that legitimately do not exist. Caching NULL stops the repeat traffic; a Bloom filter answers \"definitely absent\" without touching the database at all." }
] }
```

## CDNs and edge caching

A CDN is a globally distributed cache for content, and for anything with a large static or semi-static payload it is *the* design, not an optimisation.

**How a request works**: DNS (or anycast) sends the user to the nearest edge PoP. On a hit, the edge serves it — 10–30 ms instead of 150 ms. On a miss, the edge fetches from a regional shield cache, then from your origin, caches it, and serves it. The shield tier exists so a cold object is fetched from your origin once, not once per PoP.

**Push vs pull**: pull CDNs fetch on first request (simple, self-maintaining, first user pays); push CDNs are pre-loaded by you (good for large files and predictable launches).

**The headers that control it:**

```
Cache-Control: public, max-age=31536000, immutable      # hashed asset: app.4f2b9c.js
Cache-Control: public, max-age=60, stale-while-revalidate=300   # HTML/API: fresh-ish, never a stampede
Cache-Control: private, no-store                        # per-user or sensitive
ETag: "a1b2c3"        →  client sends If-None-Match  →  304 Not Modified (no body)
Vary: Accept-Encoding, Accept-Language                  # each variant is a separate cache entry
```

**Invalidation at the edge** is the hard part, and the answer is almost always **content-hashed URLs**: `app.4f2b9c.js` is immutable and cacheable for a year, and deploying a new build simply produces a new URL. Purge APIs exist but are slower, rate-limited, and eventually consistent across PoPs — use them for exceptions, not as your strategy.

Be careful with `Vary`: varying on a high-cardinality header (like `User-Agent` verbatim) multiplies cache entries and destroys the hit rate.

**Beyond static files**: edge caching of API GETs with short TTLs, edge compute for personalisation and A/B assignment, signed URLs for private media (so the CDN carries the bytes and your origin only mints permissions), and origin-shielding to protect a small origin from a large audience.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-cdn-q1", "type": "mcq",
      "prompt": "What is the most reliable way to make a JavaScript bundle cacheable for a year at the CDN while still shipping updates instantly?",
      "options": [
        {"id":"a","text":"Use a 1-year max-age and call the purge API on every deploy"},
        {"id":"b","text":"Put a content hash in the filename (app.4f2b9c.js) and serve it immutable — a new build produces a new URL, so there is nothing to invalidate"},
        {"id":"c","text":"Set a 60-second max-age so updates propagate quickly"},
        {"id":"d","text":"Disable CDN caching for JavaScript"}
      ],
      "correct": "b",
      "explanation": "Content-hashed URLs turn invalidation into a naming problem, which is always more reliable than a distributed purge. Purges are eventually consistent across PoPs and rate-limited; hashed names are instant and global by construction." }
] }
```

## Key takeaways

**The recall card:**

```
Patterns : cache-aside (default) · write-through (fresh) · write-behind (fast, lossy)
           · refresh-ahead (hot keys)
Rule     : on write, DELETE the key — never update it
TTL      : always set one (safety net) + add jitter (avoid synchronised expiry)
Eviction : LRU default · LFU when scans would flush the hot set
Failures : stampede (lock / stale-while-revalidate) · penetration (cache NULL / Bloom)
           · avalanche (jitter + warming + circuit breaker)
Metrics  : hit rate, eviction rate, memory used, p99 latency
CDN      : hashed immutable URLs > purge API; stale-while-revalidate for HTML/API;
           signed URLs for private media; origin shield for small origins
```

- **The interviewer's real question is invalidation.** Have "delete on write, TTL as a safety net, hashed URLs at the edge" ready before they ask.
- **Caching trades freshness for latency and cost — name the staleness you are accepting.** "A 60-second TTL means a user can see a like count one minute out of date, which is fine here" is the sentence that earns the point.
- **The three failure modes are the depth question.** Stampede, penetration, avalanche — say the name and the fix.
- **A cache is not a database.** Anything that must survive a restart needs a durable store behind it; write-behind is the only pattern that risks losing data, and only use it where loss is tolerable.

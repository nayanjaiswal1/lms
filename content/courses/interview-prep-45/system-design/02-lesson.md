---
kind: lesson
type: system_design
id_key: interview-prep-45/day-02-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 2 — Rate Limiter (api gateway style)"
position: 2
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

## Why interviewers ask this

Rate limiting is where interviewers probe whether you understand the difference between a textbook algorithm and a production system: does it work correctly under concurrent requests, does it survive a restart, does it work when you have 50 API gateway instances instead of one? It's also a concept-heavy question — expect to compare 3-4 algorithms and justify a pick, not just draw boxes.

## The problem

A rate limiter caps how many requests a client (per user, API key, or IP) can make in a time window, protecting backend services from abuse, runaway retries, and cost blowouts. It typically sits at the API gateway / edge, before requests reach application servers.

## Requirements

### Functional
- Limit requests per identity (user ID, API key, or IP) to N requests per time window.
- Return `429 Too Many Requests` with a `Retry-After` header when the limit is exceeded.
- Support different limits per tier (free vs paid API plans).

### Non-functional
- **Accuracy vs performance trade-off** — perfectly precise limiting requires coordination (costs latency); approximate limiting is faster but allows some burst-over.
- Low added latency (the limiter check itself should be single-digit milliseconds).
- Must work correctly across a fleet of stateless gateway instances (distributed, not per-instance).
- Should fail open or closed predictably if the counter store is unavailable (usually fail open for availability, fail closed for security-critical endpoints).

## The five classic algorithms

### 1. Fixed window counter
Divide time into fixed windows (e.g. 1-minute buckets aligned to the clock). Increment a counter per window; reject once it exceeds the limit.
- **Mental model:** a whiteboard tally, erased at the start of each window.
- **Pros:** trivial to implement, O(1) memory per key.
- **Cons:** boundary burst problem — a client can send N requests at 0:59 and another N at 1:00, getting 2N requests in 2 seconds around the window edge.

### 2. Sliding window log
Store a timestamp for every request in a sorted set (e.g. Redis ZSET); on each request, drop timestamps older than `now - window`, count what's left, and allow/reject.
- **Mental model:** keeping every receipt, then on each check throwing away the ones older than the window and counting what's left.
- **Pros:** perfectly accurate, no boundary burst.
- **Cons:** memory grows with request volume (must store every timestamp), more expensive per-check (O(log n) or a range scan).

### 3. Sliding window counter (approximation)
Combine the previous window's count with the current window's count, weighted by how far into the current window we are:
`estimated_count = current_window_count + previous_window_count × (1 - elapsed_fraction_of_current_window)`
- **Mental model:** two overlapping buckets — last window and this one — blended by how much of the previous window still overlaps with now.
- **Pros:** near-accurate, O(1) memory (two counters per key), cheap to compute.
- **Cons:** an approximation, not exact — acceptable for almost all real-world use cases. This is the industry-favored answer (used by Cloudflare, Stripe-style gateways) because it balances accuracy and cost.

### 4. Token bucket
Each client has a bucket that holds up to `capacity` tokens, refilled at `rate` tokens/sec. Each request consumes one token; reject if the bucket is empty.
- **Mental model:** a prepaid wallet — spend a credit per request, credits recharge over time.
- **Pros:** naturally allows bursts up to bucket capacity while enforcing a long-term average rate — matches how APIs actually want to behave ("burst is fine, sustained abuse isn't").
- **Cons:** slightly more state to track (tokens + last-refill timestamp) than a fixed counter.

### 5. Leaky bucket
Requests enter a FIFO queue (the "bucket") and are processed ("leak out") at a constant rate; if the queue is full, new requests are dropped.
- **Mental model:** a queue draining at constant speed — tracks how backed up you are, not how much credit is left.
- **Pros:** smooths bursty traffic into a constant outflow rate — useful when you want to protect a downstream system that can't handle spikes at all.
- **Cons:** legitimate bursts get delayed/queued rather than allowed, which can hurt UX for spiky-but-legitimate clients.

> Token bucket and leaky bucket are mirror images of the same idea — one grants credit that drains over time, the other drains a fixed-rate queue — running in opposite directions. If you can explain one, you can derive the other on the whiteboard.

**Interview-favored pick:** token bucket (or the sliding window counter) for API gateways, because bursts are normal client behavior (a page load fires 10 requests at once) and you want to allow that while still capping sustained abuse.

## Quick reference

| Algorithm | Tracks | Allows bursts | Memory | Best for |
|---|---|---|---|---|
| Fixed window | count + reset time | yes (at boundary) | O(1) | Simple counters |
| Sliding window log | every timestamp | no | O(n) | Precise enforcement |
| Sliding window counter | two window counts | partially | O(1) | Distributed systems |
| Token bucket | credits | yes | O(1) | API rate limiting |
| Leaky bucket | queue depth | no | O(1) | Traffic shaping |

## Where to store counters: Redis vs in-memory

| | In-memory (per instance) | Redis (shared) |
|---|---|---|
| Accuracy across a fleet | Wrong — each gateway instance has its own counter, so N instances effectively multiply the limit by N | Correct — one shared source of truth |
| Latency | Fastest (no network hop) | Extra ~1ms network round trip |
| Survives instance restart | No | Yes |
| Complexity | Simple | Needs a Redis cluster + eviction/TTL strategy |

**Answer:** in-memory only works if you pin a client to one gateway instance (sticky routing) — fragile and doesn't survive scaling events. For a real distributed API gateway, use Redis: store counters as `INCR key` with `EXPIRE`, or use a Lua script to make check-and-increment atomic in one round trip (avoids a race between two concurrent requests both reading "under limit" before either increments).

The exact Redis primitive follows the algorithm you picked:
- **Fixed window** → `INCR ratelimit:{key}:{window}`, with `EXPIRE` set only on the first increment of a window. The key self-cleans via TTL — no separate cleanup job.
- **Sliding window log** → `ZADD` the current timestamp into a per-key sorted set, `ZREMRANGEBYSCORE` to prune anything older than `now - window`, then `ZCARD` to get the count — wrap prune+count+add in one Lua script or `MULTI`/`EXEC` pipeline so nothing interleaves.
- **Sliding window counter** → two keys, one per window (`ratelimit:{key}:{window_n}` and `ratelimit:{key}:{window_n-1}`), each a plain `INCR`. On read, fetch both and apply the same weighted-average formula from above — cheap, and no Lua required for the read path.

```
-- Redis Lua script sketch for token bucket
local tokens = tonumber(redis.call('GET', KEYS[1]) or capacity)
local now = tonumber(ARGV[2])
-- refill based on elapsed time, then attempt to consume 1 token
if tokens >= 1 then
  redis.call('SET', KEYS[1], tokens - 1, 'EX', ttl)
  return 1  -- allowed
else
  return 0  -- rejected
end
```

## API / config sketch

```
Config per tier:
  { tier: "free", limit: 100, window_seconds: 60 }
  { tier: "pro",  limit: 10000, window_seconds: 60 }

Every incoming request:
  key = f"ratelimit:{user_id}:{current_window}"
  allowed = check_and_increment(key, limit)
  if not allowed:
    return 429, headers: { "Retry-After": seconds_until_reset }
```

## High-level architecture

```
Client --> API Gateway (stateless, N instances)
                 |
                 v
           Rate Limiter Middleware  <--->  Redis Cluster (counters, TTL per key)
                 |
                 v (if allowed)
           Backend Services
```

- The rate limiter is middleware, not a separate hop — it runs inline in the gateway request path, calling Redis synchronously before forwarding.
- Redis is the shared state store; use `EXPIRE`/TTL so keys self-clean and memory doesn't grow unbounded.

## Distributed rate limiting challenges

- **Race conditions:** two concurrent requests from the same client can both read "count = 9, limit = 10" before either writes, letting both through. Fix with an atomic Redis Lua script or `INCR` (atomic by nature) instead of read-then-write.
- **Redis as a single point of failure:** if Redis goes down, decide fail-open (allow all — risk overload) vs fail-closed (reject all — risk false 429s for legitimate users). Most production gateways fail open for availability and rely on downstream service-level protections (circuit breakers, autoscaling) as a backstop.
- **Clock skew across regions:** if gateway instances are geographically distributed, wall-clock-based windows can drift slightly; sliding window algorithms are more tolerant than fixed windows here.
- **Multi-region counters:** a global limit across regions needs either a single global Redis (adds cross-region latency) or per-region limits that sum to roughly the global target (eventual consistency, simpler, usually good enough).

## Scaling & trade-offs

- Redis Cluster shards counters by key hash — scales horizontally, but a single very hot key (one abusive client) still hits one shard; usually fine since it's a single client's traffic, not global traffic.
- Consider a local in-memory "fast reject" cache: if a client is already known to be way over limit, reject without even calling Redis, saving a network hop for the abuse case.
- Push rate-limit headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`) so well-behaved clients can self-throttle.

## Likely follow-up questions — with answers

**Q: How do you avoid a race condition when two requests arrive at nearly the same instant?**
A: Use an atomic operation — Redis `INCR` (atomic by design) or a Lua script that reads, checks, and writes in a single round trip so no other request can interleave.

**Q: What happens if Redis is temporarily unreachable?**
A: Decide and document the failure mode up front. Fail-open (let requests through) protects availability but risks abuse during the outage; fail-closed protects backends but causes false rate-limit errors for legitimate traffic. Most gateways fail open and lean on other safeguards (autoscaling, circuit breakers on backend services).

**Q: How would you rate-limit per-IP for anonymous users differently from per-API-key for authenticated ones?**
A: Use different key prefixes and different limit configs (`ratelimit:ip:{ip}` vs `ratelimit:key:{api_key}`), and typically apply the stricter IP-based limit first at the edge/CDN layer, with the more generous authenticated limit enforced deeper in the gateway.

## Key takeaways
- Token bucket (bursts allowed, average rate capped) is the go-to algorithm for API gateways; sliding window counter is the cheap-and-accurate alternative.
- Fixed window counters are simple but leak double the limit at window boundaries — always mention this trap.
- In-memory counters only work with sticky routing; a real distributed gateway needs a shared store like Redis.
- Atomicity (Lua script or `INCR`) is what prevents race conditions under concurrent requests — read-then-write is a bug.
- Decide and state your fail-open vs fail-closed policy for when the counter store is down — interviewers will ask.

## Today's checklist
- [ ] Define functional requirements: limit requests per user/IP
- [ ] Define non-functional requirements: accuracy vs performance trade-off
- [ ] Design algorithms: token bucket, leaky bucket, sliding window, fixed window
- [ ] Discuss where to store counters: Redis vs in-memory
- [ ] Handle distributed rate limiting challenges

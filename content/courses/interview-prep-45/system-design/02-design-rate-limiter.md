---
kind: lesson
type: system_design
id_key: interview-prep-45/day-02-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Rate Limiter"
position: 2
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

A rate limiter caps how many requests one client (a user, an API key, or an IP address) can make in a time window. It sits at the edge, before requests reach your backend, and protects you from abuse, runaway retries, and surprise cloud bills.

This question is less about drawing boxes and more about comparing algorithms and picking one with a reason. Interviewers use it to check whether you understand the difference between a textbook counter and something that survives 50 gateway instances running at once.

## Requirements

**Functional requirements**
- Limit requests per identity (user ID, API key, or IP) to N requests per time window.
- Return `429 Too Many Requests` with a `Retry-After` header when the limit is hit.
- Support different limits per plan (free vs. paid).

**Non-functional requirements**
- Accuracy costs latency: a perfectly precise limiter needs coordination between servers, which is slower. An approximate limiter is faster but may let a small burst through.
- The limiter check itself must add only single-digit milliseconds.
- It must work correctly across a fleet of stateless gateway instances, not just on one machine.
- It must fail in a predictable way if its counter store goes down. Usually fail open (let requests through) for availability, fail closed (reject) for security-critical endpoints.

> **Remember:** a rate limiter that only works correctly on one server is not a rate limiter, it's a demo. The real question is always "does this hold up across a fleet?"

```knowledge-check
{ "questions": [
    { "id": "system-design-rate-limiter-requirements-q1", "type": "mcq", "prompt": "Why is a rate limiter that only tracks counts in one server's memory a problem in production?", "options": [
        {"id": "a", "text": "It isn't a problem, in-memory counters are always correct"},
        {"id": "b", "text": "With N gateway instances each keeping its own counter, a client effectively gets N times the intended limit"},
        {"id": "c", "text": "In-memory counters are slower than a database"},
        {"id": "d", "text": "It only matters for very small companies"}
    ], "correct": "b", "explanation": "If a client's requests spread across 50 gateway instances and each one counts independently, the client can send 50 times the intended limit before any single instance notices." }
] }
```

## The five algorithms, and how to picture each one

**Fixed window counter.** Picture a whiteboard tally that gets erased every minute on the clock. Simple, O(1) memory, but a client can send N requests at 0:59 and another N at 1:00, getting 2N requests in two seconds right at the boundary.

**Sliding window log.** Picture keeping every receipt, then on each check throwing away receipts older than the window and counting what's left. Perfectly accurate, no boundary burst, but memory grows with request volume and each check costs more (you're storing every timestamp).

**Sliding window counter.** Picture two overlapping buckets: last window's count and this window's count, blended by how much of the previous window still overlaps "now."
`estimated_count = current_window_count + previous_window_count × (1 - elapsed_fraction_of_current_window)`
Near-accurate, O(1) memory, cheap to compute. This is the industry-favored answer (Cloudflare and Stripe-style gateways use it) because it balances accuracy and cost.

**Token bucket.** Picture a prepaid wallet. Every request spends one credit; credits refill at a steady rate up to a cap. This naturally allows a burst up to the bucket's size while still capping sustained abuse, which matches how real APIs behave: a page load firing 10 requests at once is fine, sustained hammering isn't.

**Leaky bucket.** Picture a queue draining at a constant speed. Requests join the back of the queue; if the queue is full, new ones are dropped. This smooths bursty traffic into a steady outflow, useful when the thing behind you can't handle spikes at all, but legitimate bursts get delayed instead of allowed.

Token bucket and leaky bucket are mirror images: one grants credit that drains over time, the other drains a fixed-rate queue in the opposite direction. If you can explain one, you can derive the other on a whiteboard.

| Algorithm | Tracks | Allows bursts | Memory | Best for |
|---|---|---|---|---|
| Fixed window | count + reset time | yes, at the boundary | O(1) | Simple counters |
| Sliding window log | every timestamp | no | O(n) | Precise enforcement |
| Sliding window counter | two window counts | partially | O(1) | Distributed systems |
| Token bucket | credits | yes | O(1) | API rate limiting |
| Leaky bucket | queue depth | no | O(1) | Traffic shaping |

**The interview-favored pick:** token bucket, or the sliding window counter, for API gateways. Bursts are normal client behavior, and you want to allow that while still capping sustained abuse.

> **Remember:** token bucket lets bursts through and caps the average; fixed window is simple but leaks double the limit at the boundary.

```knowledge-check
{ "questions": [
    { "id": "system-design-rate-limiter-algorithms-q1", "type": "mcq", "prompt": "What is the classic weakness of the fixed window counter algorithm?", "options": [
        {"id": "a", "text": "It uses too much memory to be practical"},
        {"id": "b", "text": "A client can send close to double the limit in a short window that straddles two counting periods"},
        {"id": "c", "text": "It cannot be implemented with Redis"},
        {"id": "d", "text": "It never allows any bursts at all"}
    ], "correct": "b", "explanation": "Sending N requests right before a window boundary and another N right after lets a client get 2N requests within a couple of seconds, even though each window individually stayed under the limit." }
] }
```

## Where to store counters: Redis vs. in-memory

| | In-memory (per instance) | Redis (shared) |
|---|---|---|
| Accuracy across a fleet | Wrong: N instances effectively multiply the limit by N | Correct: one shared source of truth |
| Latency | Fastest, no network hop | About 1ms extra for the round trip |
| Survives a restart | No | Yes |
| Complexity | Simple | Needs a Redis cluster plus a TTL/eviction plan |

In-memory only works if you pin a client to one gateway instance forever, which is fragile and breaks the moment you scale up or down. For a real distributed gateway, use Redis: `INCR key` with `EXPIRE`, or a Lua script so the check-and-increment happens in one atomic round trip. That avoids a race where two concurrent requests both see "under limit" before either one increments.

The Redis primitive follows the algorithm:
- **Fixed window:** `INCR ratelimit:{key}:{window}`, with `EXPIRE` set only on the first increment. The key self-cleans via TTL.
- **Sliding window log:** `ZADD` the timestamp into a sorted set, `ZREMRANGEBYSCORE` to drop anything older than `now - window`, then `ZCARD` to count. Wrap all three in one Lua script so nothing interleaves.
- **Sliding window counter:** two plain `INCR` keys, one per window. Read both, apply the weighted formula above. No Lua needed for reads.

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

## API

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

## High-level design

```
Client --> API Gateway (stateless, N instances)
                 |
                 v
           Rate Limiter Middleware  <--->  Redis Cluster (counters, TTL per key)
                 |
                 v (if allowed)
           Backend Services
```

The limiter is middleware, not a separate network hop. It runs inline in the gateway's request path, calls Redis synchronously before forwarding the request, and Redis is the one shared truth every gateway instance checks. TTLs on every key mean old counters clean themselves up.

## Deep dives

### What breaks when you go distributed?

- **Race conditions.** Two concurrent requests from the same client can both read "count = 9, limit = 10" before either writes, letting both through. Fix it with an atomic Redis operation (`INCR`, or a Lua script) instead of a separate read then write.
- **Redis as a single point of failure.** If Redis goes down, decide up front: fail open (allow everything, risk overload) or fail closed (reject everything, risk false 429s for real users). Most production gateways fail open and lean on other safeguards, like autoscaling and circuit breakers, as a backstop.
- **Clock skew across regions.** Wall-clock-based windows can drift slightly when gateway instances span regions. Sliding window algorithms tolerate this better than fixed windows.
- **Multi-region counters.** A true global limit across regions needs either one global Redis (adds cross-region latency) or per-region limits that roughly sum to the global target (simpler, eventually consistent, usually good enough).

```knowledge-check
{ "questions": [
    { "id": "system-design-rate-limiter-deepdive-q1", "type": "mcq", "prompt": "How do you avoid a race condition where two concurrent requests both pass a rate-limit check they shouldn't?", "options": [
        {"id": "a", "text": "Add a longer timeout to the request"},
        {"id": "b", "text": "Use an atomic operation, like Redis INCR or a Lua script, so the check and the increment happen in a single step"},
        {"id": "c", "text": "Increase the rate limit so it doesn't matter"},
        {"id": "d", "text": "Store the counter in each gateway's local memory instead"}
    ], "correct": "b", "explanation": "Reading a count and then writing it back in two separate steps leaves a window where two requests can both read the old value. An atomic increment closes that window." }
] }
```

## Trade-offs and follow-up questions

Sharding counters across a Redis Cluster scales horizontally, but one very abusive client still hammers a single shard. That's usually fine, since it's one client's traffic, not global traffic.

Add a local "fast reject" cache: if a client is already known to be far over the limit, reject it without even calling Redis, saving a network hop on the abuse case. Also return rate-limit headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`) so well-behaved clients can throttle themselves before hitting the wall.

**Q: How do you avoid a race condition when two requests arrive at nearly the same instant?**
A: Use an atomic operation: Redis `INCR` or a Lua script that reads, checks, and writes in one round trip, so nothing can interleave.

**Q: What happens if Redis is temporarily unreachable?**
A: Decide and document the failure mode up front. Fail-open protects availability but risks abuse during the outage; fail-closed protects backends but causes false rate-limit errors. Most gateways fail open and rely on other safeguards.

**Q: How would you rate-limit anonymous IP traffic differently from authenticated API-key traffic?**
A: Different key prefixes and different configs (`ratelimit:ip:{ip}` vs. `ratelimit:key:{api_key}`), typically with the stricter IP-based limit applied first at the edge, and the more generous authenticated limit enforced deeper in the gateway.

```knowledge-check
{ "questions": [
    { "id": "system-design-rate-limiter-tradeoffs-q1", "type": "mcq", "prompt": "Why do most production API gateways fail open rather than fail closed when the rate-limit store goes down?", "options": [
        {"id": "a", "text": "Failing open is always more secure"},
        {"id": "b", "text": "They prioritize availability, accepting some risk of abuse over rejecting all legitimate traffic"},
        {"id": "c", "text": "Failing closed is not technically possible"},
        {"id": "d", "text": "Redis never goes down in practice"}
    ], "correct": "b", "explanation": "For most APIs, a false 429 rejecting real users is worse than a short window of unmetered traffic, so gateways lean toward availability and use other safeguards as backup." }
] }
```

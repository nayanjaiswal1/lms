---
kind: lesson
id_key: interview-prep-45/hld-13-reliability
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Reliability, Resilience, and Rate Limiting"
position: 13
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Every design interview ends with some version of "what happens when this breaks?" Candidates who have only drawn happy paths stall here. Candidates who can name a failure, its blast radius, and the pattern that contains it finish strong. This lesson is that vocabulary — plus rate limiting, which is the one resilience mechanism you will be asked to implement in detail.

## Availability, SLOs, and the arithmetic of dependencies

**Availability is downtime per year, and you should know the ladder:**

| Availability | Downtime/year | Downtime/month | Typical of |
|---|---|---|---|
| 99% ("two nines") | 3.65 days | 7.2 hours | Internal tools |
| 99.9% | 8.8 hours | 43 minutes | Standard SaaS |
| 99.95% | 4.4 hours | 22 minutes | Paid business tier |
| 99.99% | 53 minutes | 4.3 minutes | Critical infrastructure |
| 99.999% | 5.3 minutes | 26 seconds | Telecom-grade, very expensive |

**SLI / SLO / SLA**, distinguished precisely because interviewers ask:

- **SLI** — the measurement: "proportion of requests served in <300 ms", "success rate of `POST /orders`".
- **SLO** — your internal target for that SLI: "99.9% of requests succeed, measured over 30 days".
- **SLA** — the contractual promise to customers, with penalties. Always looser than the SLO, so you find out before your customers do.
- **Error budget** — the inverse of the SLO. A 99.9% SLO grants 43 minutes of failure per month; that budget is *permission to ship*. Budget intact → ship features. Budget spent → freeze and fix reliability. This framing is a strong thing to bring up unprompted.

**Dependencies multiply, and this is the most useful arithmetic in the lesson.** Five services in a synchronous chain, each 99.9% available:

```
0.999^5 = 0.995  →  99.5% overall  →  3.6 hours of downtime per month
```

Adding a dependency to the critical path *lowers* availability. Three consequences to state:

1. **Redundancy in parallel raises it back**: two independent replicas each at 99% give `1 − 0.01² = 99.99%` — provided the failures are genuinely independent (same AZ, same deploy, same config bug: not independent).
2. **Make dependencies non-critical**: if the recommendation service is down and the page still renders without recommendations, it is not on your critical path.
3. **Count the chain out loud** when you draw it. "This request touches four services synchronously, so my availability ceiling is about 99.6% — I'd move the last two behind a queue."

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-availability-q1", "type": "mcq",
      "prompt": "A request synchronously calls four services, each 99.9% available. What is the approximate end-to-end availability, and what is the standard fix?",
      "options": [
        {"id":"a","text":"99.9% — the slowest dependency sets the number"},
        {"id":"b","text":"About 99.6%, because availabilities multiply along a synchronous chain; fix by removing non-essential calls from the critical path (async, cached, or degrade gracefully)"},
        {"id":"c","text":"99.99% — redundancy improves it"},
        {"id":"d","text":"100% if each service has retries"}
      ],
      "correct": "b",
      "explanation": "0.999⁴ ≈ 0.996. Every synchronous dependency is a multiplier, which is why the strongest reliability move is usually shortening the critical path rather than making each dependency slightly better." }
] }
```

## Timeouts, retries, and the patterns that stop cascades

**Timeouts.** Every network call needs one. A call with no timeout holds a thread, a connection, and a caller's request until something else gives up — this is how one slow dependency exhausts a whole fleet's thread pool.

Set the timeout from your **latency budget**, not from the dependency's average: if you must answer in 300 ms and you make two calls, they get roughly 100 ms each plus overhead. Propagate the remaining budget downstream (a deadline header) so a service does not start work its caller has already abandoned.

**Retries — the double-edged one.** Retries turn transient failures into successes and turn overload into an outage. Four rules:

1. **Exponential backoff with jitter.** `min(base × 2^attempt, cap) × random(0.5, 1.5)`. Without jitter, retries synchronise and arrive as a wave.
2. **Only retry idempotent operations**, or operations protected by an idempotency key.
3. **Only retry retryable failures.** Timeouts, 503, connection resets: yes. 400, 401, 422: never — it will fail identically forever.
4. **Use a retry budget**, not just a per-call limit: cap retries at, say, 10% of total requests. Otherwise a struggling dependency receives 3× its normal load exactly when it can least handle it — the classic **retry storm**.

**Circuit breaker.** Stop calling a dependency that is clearly failing, so you fail fast instead of exhausting resources waiting.

```
CLOSED  → calls pass through; count failures
        → failure rate exceeds threshold (e.g. 50% over 20 requests) ⇒ OPEN
OPEN    → reject immediately, no call made (fail fast, serve fallback)
        → after a cool-off (e.g. 30 s) ⇒ HALF-OPEN
HALF-OPEN → allow a few trial calls
        → they succeed ⇒ CLOSED     they fail ⇒ OPEN again
```

The benefit is mutual: the caller stops burning threads on doomed calls, and the failing service gets breathing room to recover instead of being hammered.

**Bulkhead.** Isolate resources so one failure cannot consume everything, named after a ship's watertight compartments: separate connection pools and thread pools per dependency, so a slow recommendation service cannot starve the checkout path of connections. Separate queues per tenant so one noisy customer cannot fill the shared one.

**Graceful degradation.** Decide *in advance* what a partial system still serves: search without personalisation, a product page without the review count, a feed from cache with a "may be stale" indicator. Naming the degraded mode is far stronger than "it returns an error".

**Load shedding.** When overloaded, reject some requests immediately — cheaply, and preferring low-value traffic — so the rest are served correctly. A system that serves 70% of traffic well beats one that serves 100% of traffic past its timeout. Prioritise: paying users over free, writes over analytics, interactive over batch.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-patterns-q1", "type": "mcq",
      "prompt": "A downstream service starts timing out. Callers retry three times each. What happens, and which pattern prevents it?",
      "options": [
        {"id":"a","text":"The retries succeed and hide the problem; no pattern needed"},
        {"id":"b","text":"Load on the struggling service triples exactly when it is weakest (a retry storm), and callers exhaust their thread pools waiting — a circuit breaker fails fast once the failure rate crosses a threshold, and a retry budget caps the amplification"},
        {"id":"c","text":"The load balancer routes around it automatically"},
        {"id":"d","text":"The database absorbs the extra load"}
      ],
      "correct": "b",
      "explanation": "Retries amplify load multiplicatively during exactly the window where the dependency needs less. Circuit breaking plus a retry budget plus backoff-with-jitter is the standard triple." }
] }
```

## Rate limiting: the four algorithms

Rate limiting protects you from abuse, from runaway clients, and from your own retry storms. Interviewers ask for the algorithms by name, so learn all four and their trade-offs.

**1. Fixed window.** Count requests per fixed interval; reset at the boundary.

```
key = f"rl:{user_id}:{int(time.time() // 60)}"    # one counter per minute
count = redis.incr(key)
if count == 1:
    redis.expire(key, 60)
allowed = count <= LIMIT
```
Trivial and cheap, one flaw: the **boundary burst** — 100 requests at 11:59:59 and 100 more at 12:00:00 is 200 in one second under a "100/minute" limit.

**2. Sliding window log.** Store a timestamp per request in a sorted set; drop entries older than the window; count what remains. Perfectly accurate, and memory grows with the request rate — expensive for high-volume limits.

```
now = time.time()
p = redis.pipeline()
p.zremrangebyscore(key, 0, now - WINDOW)
p.zadd(key, {str(uuid.uuid4()): now})
p.zcard(key)
p.expire(key, WINDOW)
allowed = p.execute()[2] <= LIMIT
```

**3. Sliding window counter.** Interpolate between the previous and current fixed windows: `count = prev_window_count × (overlap fraction) + current_count`. Approximates the sliding log with two integers — the usual production compromise, and what Cloudflare popularised.

**4. Token bucket.** A bucket holds up to `B` tokens and refills at `r` tokens/second; each request takes one. Empty bucket → reject (or queue). This is the one to reach for by default: it **allows controlled bursts** up to the bucket size while enforcing the average rate — which matches how real clients behave.

```python
def allow(bucket, rate, capacity, now):
    elapsed = now - bucket["last"]
    bucket["tokens"] = min(capacity, bucket["tokens"] + elapsed * rate)  # lazy refill
    bucket["last"] = now
    if bucket["tokens"] >= 1:
        bucket["tokens"] -= 1
        return True
    return False


# 5 requests/sec, burst of 5: the first 5 pass instantly, the 6th is rejected,
# and one more token is available half a second later.
bucket = {"tokens": 5.0, "last": 0.0}
assert [allow(bucket, 5, 5, 0.0) for _ in range(5)] == [True] * 5
assert allow(bucket, 5, 5, 0.0) is False          # burst exhausted
assert allow(bucket, 5, 5, 0.5) is True           # 0.5 s x 5/sec = 2.5 tokens refilled
print("token bucket ok, tokens left:", round(bucket["tokens"], 2))
```

**Leaky bucket** is the sibling: requests queue and drain at a constant rate, smoothing output completely — good for protecting a downstream that cannot burst at all, at the cost of added latency.

| Algorithm | Memory | Accuracy | Bursts | Verdict |
|---|---|---|---|---|
| Fixed window | O(1) | Boundary burst up to 2× | Uncontrolled at boundary | Simple internal limits |
| Sliding log | O(requests) | Exact | None | Low-volume, high-value limits |
| Sliding counter | O(1) | Very good | Smoothed | Good production default |
| **Token bucket** | O(1) | Good | **Controlled, up to B** | **The usual answer** |
| Leaky bucket | O(queue) | Exact output rate | None (queued) | Protecting a fragile downstream |

**Distributed rate limiting** adds the real difficulty. Per-node limits are wrong (10 nodes × 100/min = 1000/min), so counters live in Redis — which puts a network call on every request and makes Redis a dependency of your front door. The production compromise: **local token buckets with a share of the global budget**, periodically rebalanced against a central counter; approximate, fast, and it degrades to per-node limits if the central store is unreachable.

Always return the contract: `429` with `Retry-After`, plus `X-RateLimit-Limit/Remaining/Reset`. Rate limit by the right key — user id for authenticated traffic, API key for partners, IP only as a last resort (NAT and mobile carriers put thousands of users behind one address).

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-ratelimit-q1", "type": "mcq",
      "prompt": "Why is token bucket usually preferred over fixed-window counting for a public API?",
      "options": [
        {"id":"a","text":"It uses less memory than a fixed-window counter"},
        {"id":"b","text":"It enforces the average rate while allowing a controlled burst up to the bucket size, and it has no window-boundary spike where a client can send 2× the limit in an instant"},
        {"id":"c","text":"It requires no shared state in a distributed system"},
        {"id":"d","text":"It guarantees requests are never rejected"}
      ],
      "correct": "b",
      "explanation": "Fixed windows allow up to double the limit across a boundary and refuse all bursts inside a window. Token bucket's refill model matches real client behaviour: occasional bursts, bounded long-run average. Both are O(1) state." }
] }
```

## Failure modes, blast radius, and testing for failure

**Name the failure modes in your own design before you are asked.** The recurring list:

| Failure | Symptom | Containment |
|---|---|---|
| Single point of failure | One box, no redundancy | Replicate; multi-AZ; automatic failover |
| Cascading failure | One slow service takes everything down | Timeouts, circuit breakers, bulkheads, shedding |
| Retry storm | Load multiplies during degradation | Backoff + jitter, retry budgets |
| Thundering herd | Everything expires/reconnects at once | Jitter everywhere: TTLs, retries, cron, reconnects |
| Hot key / hot shard | One partition saturates | Cache it, salt it, isolate it |
| Poison message | One bad record blocks a partition | DLQ after N attempts |
| Unbounded queue | Latency climbs until the system dies | Bounded queues, backpressure, shedding |
| Correlated failure | "Independent" replicas share an AZ, config, or deploy | Spread across AZs; stagger deploys; separate config blast radius |
| Grey failure | Not down, just slow or wrong — health checks pass | Latency- and error-based SLIs, outlier ejection |
| Metastable failure | System stays broken after the trigger is gone | Shed load to break the feedback loop; drain queues before resuming |

**Blast radius** is the containment vocabulary: cell/shard architectures so one cell's failure affects 1/N of users, per-tenant isolation for large customers, staged rollouts (canary → 1% → 10% → 100%) with automatic rollback on SLI regression, and feature flags to disable a subsystem without a deploy.

**Recovery objectives**, in case they are asked by name: **RTO** is how long you may take to restore service; **RPO** is how much data you may lose. Async replication implies an RPO greater than zero — say the number.

**And prove it**: chaos experiments (kill an instance, add latency, sever an AZ) in a controlled window, game days, load tests to find the knee of the curve, and disaster-recovery drills that actually restore from backup. "A backup you have never restored is not a backup" is a fair line to use.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-failure-q1", "type": "mcq",
      "prompt": "Traffic returns to normal after a spike, but the system stays broken — queues are full, every request times out, retries keep it saturated. What is this, and what breaks the loop?",
      "options": [
        {"id":"a","text":"A cache stampede; add a lock"},
        {"id":"b","text":"A metastable failure — a self-sustaining feedback loop that outlives its trigger. Break it by shedding load hard, pausing retries, and draining the backlog before admitting traffic again"},
        {"id":"c","text":"A hot shard; re-partition the data"},
        {"id":"d","text":"A grey failure; replace the health check"}
      ],
      "correct": "b",
      "explanation": "Retry amplification plus a saturated queue keeps the system in the failed state even at normal load. Only reducing admitted work — shedding, pausing retries, draining — lets it fall back into the healthy regime; adding capacity often does not." }
] }
```

## Key takeaways

**The recall card:**

```
99.9% = 43 min/month · 99.99% = 4.3 min/month
Synchronous dependencies MULTIPLY: 0.999^5 ≈ 99.5%  → shorten the critical path
Parallel redundancy adds nines — only if failures are truly independent
SLI (measure) → SLO (target) → SLA (contract) → error budget = permission to ship

Every call: TIMEOUT (from your latency budget, propagate the deadline)
Retries: exponential backoff + JITTER, idempotent only, retryable only, retry BUDGET
Circuit breaker: CLOSED → OPEN (fail fast) → HALF-OPEN (trial) → CLOSED
Bulkhead: separate pools/queues per dependency and per tenant
Degrade gracefully (decide the reduced mode in advance) · shed load by priority

Rate limiting: fixed window (boundary burst) · sliding log (exact, costly)
               · sliding counter (good default) · TOKEN BUCKET (bursts + average) ·
               leaky bucket (smooth output). Distributed: local buckets + central budget.
               Always: 429 + Retry-After + X-RateLimit-* headers.

Failure vocabulary: SPOF · cascade · retry storm · thundering herd · hot shard ·
                    poison message · unbounded queue · correlated failure · grey ·
                    METASTABLE (survives its trigger — shed to escape)
Blast radius: cells, per-tenant isolation, canary + auto-rollback, feature flags
RTO = time to restore · RPO = data you may lose. Test it: chaos, game days, restore drills.
```

- **Availability arithmetic is the fastest way to justify an architectural change.** Count the synchronous hops and say the number.
- **Retries without jitter, budgets, and idempotency make outages worse, not better.**
- **Token bucket is the default rate-limiter answer**, and the distributed version (local buckets against a shared budget) is the follow-up they are hoping for.
- **Volunteer the failure modes.** Ending your design with "here's what breaks first, how I'd contain it, and how I'd know" is exactly the close a senior interview is looking for.

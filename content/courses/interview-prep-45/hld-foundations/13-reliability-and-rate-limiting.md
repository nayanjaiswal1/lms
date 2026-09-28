---
kind: lesson
id_key: interview-prep-45/hld-13-reliability
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Reliability, Resilience, and Rate Limiting"
position: 13
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Every design interview eventually ends with some version of the question "what happens when this breaks?" If you've only ever drawn the happy path, this is where you'll stall. If you can name a failure, describe how far its damage spreads, and name the pattern that contains it, this is where you'll finish strong. This lesson gives you that exact vocabulary, plus rate limiting, which is the one resilience mechanism you'll actually be asked to build out in detail.

## Availability, SLOs, and the arithmetic of dependencies

**Availability just means how much of the year a system is actually working, usually written as a percentage. Learn this ladder of numbers:**

| Availability | Downtime a year | Downtime a month | Typical of |
|---|---|---|---|
| 99% ("two nines") | 3.65 days | 7.2 hours | Internal tools |
| 99.9% | 8.8 hours | 43 minutes | Standard software-as-a-service |
| 99.95% | 4.4 hours | 22 minutes | A paid business tier |
| 99.99% | 53 minutes | 4.3 minutes | Critical infrastructure |
| 99.999% | 5.3 minutes | 26 seconds | Telecom-grade, and very expensive to achieve |

**Three closely related terms, worth telling apart precisely, since interviewers like to test this:**

- **An SLI**, short for service level indicator, is the actual measurement: "the fraction of requests answered in under 300 milliseconds," or "the success rate of creating an order."
- **An SLO**, short for service level objective, is your own internal target for that measurement: "99.9% of requests succeed, measured over the last 30 days."
- **An SLA**, short for service level agreement, is the contractual promise made to customers, usually with financial penalties attached. It's always set looser than your own internal SLO, so that you find out about a problem before your customers file a complaint about it.
- **An error budget** is simply the flip side of your SLO. A 99.9% SLO grants you 43 minutes of allowed failure a month, and that budget is really *permission to ship new features*. While the budget still has room left, you keep shipping. Once it's spent, you pause new features and focus entirely on reliability instead. Bringing up this framing yourself, unprompted, is a strong move.

**Dependencies multiply together, and this is genuinely the single most useful piece of arithmetic in this lesson.** Picture five padlocks in a row, each 99.9% reliable on its own; you only get through if every single one opens. Five services called one after another, each available 99.9% of the time, work out like this:

```
0.999^5 = 0.995  →  99.5% overall  →  3.6 hours of downtime per month
```

Adding one more dependency onto the critical path always *lowers* your overall availability, never raises it. Three things follow from this.

1. **Redundancy running in parallel can raise availability back up.** Two genuinely independent copies, each 99% available on its own, together give you `1 - 0.01² = 99.99%`, but only if their failures are truly independent from each other. Two servers in the same availability zone, running the same deploy, sharing the same misconfiguration, are not independent at all.
2. **Make some dependencies non-critical on purpose.** If the recommendation service is down but the page still renders fine without recommendations shown, it was never really on your critical path to begin with.
3. **Count the chain out loud as you draw it.** For example: "this request touches four services one after another, so my ceiling on availability here is roughly 99.6%. I'd move the last two of them behind a queue instead."

> **Remember:** picture five locks on one door, each 99.9% reliable; every extra lock in the chain multiplies together, so more calls in a row, one waiting on the next, means lower availability, not more safety.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-availability-q1", "type": "mcq",
      "prompt": "A request calls four services one after another, each 99.9% available on its own. What is the approximate end-to-end availability, and what is the standard fix?",
      "options": [
        {"id":"a","text":"99.9%, since the slowest dependency alone sets the overall number"},
        {"id":"b","text":"About 99.6%, because availabilities multiply together along a chain of calls; the fix is removing non-essential calls from the critical path, by making them asynchronous, cached, or by degrading gracefully instead"},
        {"id":"c","text":"99.99%, because redundancy always improves the overall number"},
        {"id":"d","text":"100%, as long as each service retries on failure"}
      ],
      "correct": "b",
      "explanation": "0.999 to the fourth power is about 0.996. Every dependency called one after another multiplies into the total, which is exactly why the strongest fix is usually shortening that chain of calls, rather than trying to make each individual link only slightly more reliable." }
] }
```

## Timeouts, retries, and the patterns that stop cascades

**Every single network call needs a timeout.** A call with no timeout holds onto a thread, a connection, and the entire caller's own request, until something else eventually gives up on its behalf. This is exactly how one slow dependency can drain an entire fleet's supply of available threads.

Set each timeout based on your **overall time budget for the whole request**, not based on the dependency's own average response time. If your whole request must answer within 300 milliseconds and you make two calls along the way, each one realistically gets about 100 milliseconds, once you account for overhead. Pass the remaining budget onward to the next service, often as a deadline header, so a service doesn't waste effort starting work its own caller has already given up waiting for.

**Retries are a genuinely double-edged tool.** They turn a brief, temporary failure into a quiet success, but they can also turn an overloaded service into a full outage. Follow four rules.

1. **Use exponential backoff with a bit of randomness added, called jitter.** For example: `min(base × 2^attempt, cap) × random(0.5, 1.5)`. Without that randomness, every client's retries fall into sync and arrive together as one big wave.
2. **Only retry an operation that's safe to repeat**, meaning it's naturally idempotent, or it's protected by an idempotency key, a concept covered in the earlier API lesson.
3. **Only retry failures that are actually worth retrying.** A timeout, a "503 overloaded" response, or a dropped connection are worth retrying. A "400 bad request," "401 unauthorized," or "422 invalid" response never is; it will fail in exactly the same way every single time.
4. **Set a retry budget, on top of a simple per-call limit.** Cap total retries at, say, 10% of all requests. Otherwise, a struggling dependency suddenly receives 3 times its normal load at the exact moment it can least handle it, a pattern called a **retry storm**.

**A circuit breaker** works like a fuse in your home's electrical panel. When a circuit draws too much current, the fuse trips instantly and cuts the power, rather than letting the wires overheat and potentially catch fire. A circuit breaker in software does the same thing: it stops calling a dependency that's clearly failing, so your own service fails fast instead of exhausting its resources waiting around.

```
CLOSED  → calls pass through; count failures
        → failure rate exceeds threshold (e.g. 50% over 20 requests) ⇒ OPEN
OPEN    → reject immediately, no call made (fail fast, serve fallback)
        → after a cool-off (e.g. 30 s) ⇒ HALF-OPEN
HALF-OPEN → allow a few trial calls
        → they succeed ⇒ CLOSED     they fail ⇒ OPEN again
```

The benefit runs both ways: the caller stops wasting threads on calls that are doomed to fail anyway, and the struggling service gets some breathing room to recover, instead of being hammered continuously.

**A bulkhead** isolates resources so that one failure can't consume everything else along with it, named after the watertight compartments built into a ship's hull. In practice, this means separate connection pools and separate thread pools for each dependency, so a slow recommendation service can't starve the checkout flow of the connections it needs, and separate queues per customer, so one especially noisy customer can't fill up a queue shared by everyone else.

**Graceful degradation** means deciding *ahead of time* what a partially broken system should still be able to offer: search results without personalisation, a product page without its review count, a feed pulled from cache with a small "may be out of date" note attached. Naming this reduced mode of operation clearly is a far stronger answer than simply saying "it would return an error."

**Load shedding** means, when the system is overloaded, immediately and cheaply rejecting some requests, favouring lower-value traffic first, so the rest can still be served correctly. A system that serves 70% of its traffic well beats one that tries to serve 100% of it and times out on all of it. Prioritise paying customers over free ones, writes over background analytics, and interactive requests over batch jobs.

> **Remember:** a circuit breaker trips like a household fuse: stop calling a failing dependency immediately instead of letting every caller wait and pile up.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-patterns-q1", "type": "mcq",
      "prompt": "A downstream service starts timing out. Every caller retries three times. What happens, and which pattern prevents it?",
      "options": [
        {"id":"a","text":"The retries succeed quietly and hide the problem, so no pattern is actually needed"},
        {"id":"b","text":"Load on the already-struggling service triples at the exact moment it's weakest (a retry storm), and every caller exhausts its own thread pool waiting for a reply; a circuit breaker fails fast once the failure rate crosses a threshold, and a retry budget caps how much the retries can amplify the load"},
        {"id":"c","text":"The load balancer automatically routes around the problem"},
        {"id":"d","text":"The database simply absorbs the extra load"}
      ],
      "correct": "b",
      "explanation": "Retries multiply the load on a struggling service during exactly the window it can least handle more traffic. Combining a circuit breaker, a retry budget, and backoff with jitter is the standard set of three fixes used together." }
] }
```

## Rate limiting: the four algorithms

Picture a water tank that drips in at a steady, constant rate, but can be drained through a tap in one quick burst, up to the tank's full size. That's exactly how a token bucket works, and it's the default answer among four different ways of controlling how fast requests get let through. Rate limiting protects a system from abuse, from clients that misbehave, and from its own retry storms. Interviewers often ask for these algorithms by name, so it's worth learning all four along with their trade-offs.

**1. Fixed window.** Count requests within a fixed block of time, and reset the counter the moment that block ends.

```
key = f"rl:{user_id}:{int(time.time() // 60)}"    # one counter per minute
count = redis.incr(key)
if count == 1:
    redis.expire(key, 60)
allowed = count <= LIMIT
```
This is trivial and cheap to implement, but it has one real flaw: a **burst right at the boundary**. A client that sends 100 requests in the very last second of one minute, and another 100 in the very first second of the next, has just sent 200 requests within a single second, even under a limit meant to be "100 per minute."

**2. Sliding window log.** Store a timestamp for every single request in a sorted structure, drop any entries older than your chosen time window, and count whatever's left. This is perfectly accurate, but its memory use grows with the number of requests, which gets expensive at high volume.

```
now = time.time()
p = redis.pipeline()
p.zremrangebyscore(key, 0, now - WINDOW)
p.zadd(key, {str(uuid.uuid4()): now})
p.zcard(key)
p.expire(key, WINDOW)
allowed = p.execute()[2] <= LIMIT
```

**3. Sliding window counter.** This estimates the exact log above using just two numbers, by blending the previous fixed window's count with the current one: `count = prev_window_count × (overlap fraction) + current_count`. It's the usual practical compromise chosen in production, and it's the approach Cloudflare made popular.

**4. Token bucket.** A bucket holds up to `B` tokens, and refills at a rate of `r` tokens every second; each request consumes one token, and an empty bucket means the request is rejected, or held until a token is free. This is the one to reach for by default, since it **allows a controlled burst** up to the bucket's size while still enforcing the average rate over time, which closely matches how real clients actually behave.

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

**Leaky bucket** is closely related: requests queue up and drain out at a perfectly constant rate, smoothing the output completely. This works well for protecting a fragile downstream service that can't handle any burst at all, at the cost of adding some delay.

| Algorithm | Memory used | Accuracy | Handling bursts | When to use it |
|---|---|---|---|---|
| Fixed window | Constant | Can let up to double the limit through at the boundary | Uncontrolled right at the boundary | Simple, internal limits |
| Sliding log | Grows with request volume | Exact | None allowed | Low-volume, high-value limits |
| Sliding counter | Constant | Very good | Smoothed out | A good default for production |
| **Token bucket** | Constant | Good | **Controlled, up to B** | **The usual answer** |
| Leaky bucket | Grows with the queue | Exact output rate | None, since requests just queue | Protecting a fragile downstream service |

**Rate limiting across many servers at once is where the real difficulty shows up.** Limiting per server independently is wrong; 10 servers each allowing 100 requests a minute adds up to 1,000 a minute in total, not 100. So counters usually live centrally in Redis, which means an extra network call on every single request, and makes Redis itself a dependency your entire front door now relies on. The usual practical compromise is **local token buckets, each holding a share of one global budget**, periodically rebalanced against a shared central counter; this is approximate and fast, and it simply falls back to per-server limits if the central store becomes unreachable.

Always return the standard contract to the client: a `429` status with a `Retry-After` header, plus `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers. Rate limit using the right key for the situation: user id for logged-in traffic, an API key for partners, and IP address only as a last resort, since mobile carriers and shared networks can put thousands of separate users behind a single IP address.

> **Remember:** a token bucket lets a client burst up to the bucket size while still capping the long-run average. A fixed window can let a client sneak through double the limit right at the boundary.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-ratelimit-q1", "type": "mcq",
      "prompt": "Why is a token bucket usually preferred over fixed-window counting for a public API?",
      "options": [
        {"id":"a","text":"It uses less memory than a fixed-window counter does"},
        {"id":"b","text":"It enforces the average rate over time while still allowing a controlled burst up to the bucket's size, and it has no boundary spike where a client could send double the limit in an instant"},
        {"id":"c","text":"It needs no shared state at all in a distributed system"},
        {"id":"d","text":"It guarantees that requests are never rejected"}
      ],
      "correct": "b",
      "explanation": "A fixed window can let through up to double its stated limit right at the boundary between two windows, and it refuses every burst that happens inside a single window. A token bucket's refill model matches how real clients actually behave: occasional bursts, with a bounded average over the long run. Both approaches use only a small, constant amount of state." }
] }
```

## Failure modes, blast radius, and testing for failure

**Name the ways your own design can fail before the interviewer has to ask you about them. Here's the recurring list:**

| Failure | What it looks like | How to contain it |
|---|---|---|
| Single point of failure | One box, with no backup at all | Replicate it, spread it across zones, add automatic failover |
| Cascading failure | One slow service ends up taking everything else down with it | Timeouts, circuit breakers, bulkheads, shedding load |
| Retry storm | Load multiplies right as the system is already struggling | Backoff plus jitter, and a retry budget |
| Thundering herd | Everything expires or reconnects at the exact same moment | Add jitter everywhere: to expiry times, retries, scheduled jobs, reconnect attempts |
| Hot key / hot shard | One partition takes far more traffic than the rest | Cache it, split it up, isolate it on its own |
| Poison message | One bad record blocks an entire partition behind it | Move it to a dead-letter queue after N attempts |
| Unbounded queue | Response times climb steadily until the whole system dies | Bounded queues, backpressure, shedding load |
| Correlated failure | Servers assumed to be "independent" actually share a zone, a config, or a deploy | Spread servers across zones, stagger deploys, keep configuration blast radius separate |
| Grey failure | Not fully down, just slow or subtly wrong, while health checks still pass | Base alerts on latency and error rate, not just up-or-down; eject outliers automatically |
| Metastable failure | The system stays broken even after whatever triggered it is long gone | Shed load hard to break the feedback loop; drain the backlog before letting traffic back in |

**Blast radius is the vocabulary for how far a failure's damage actually spreads**: a cell or shard-based design, so one cell failing only affects 1 out of N users; isolating a large customer on their own resources; rolling out changes gradually, from a small canary group up to 1%, then 10%, then everyone, with automatic rollback if key metrics regress; and feature flags, which let you turn off a broken part of the system without needing a whole new deploy.

**Two recovery targets are worth knowing by name, in case you're asked directly.** RTO, short for recovery time objective, is how long you're allowed to take to restore service. RPO, short for recovery point objective, is how much data you're allowed to lose. Asynchronous replication always implies an RPO greater than zero; say the actual number out loud when you propose it.

**And actually prove all of this works, rather than just assuming it does**: run chaos experiments, like deliberately killing an instance, adding artificial latency, or cutting off an entire availability zone, inside a controlled window; run scheduled "game days" that rehearse a failure; run load tests to find the exact point where performance falls off a cliff; and run disaster-recovery drills that genuinely restore from a real backup. "A backup you've never actually restored from is not really a backup" is a fair thing to say.

> **Remember:** naming the failure mode before you're asked, such as a hot key, a retry storm, or a metastable failure, is a strong signal that you've actually operated a system like this, and not only sketched one.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-13-failure-q1", "type": "mcq",
      "prompt": "Traffic returns to normal after a spike, but the system stays broken: queues remain full, every request times out, and ongoing retries keep it saturated. What is this called, and what breaks the loop?",
      "options": [
        {"id":"a","text":"A cache stampede; add a lock around the affected reads"},
        {"id":"b","text":"A metastable failure, a self-sustaining feedback loop that outlives whatever originally triggered it. Break it by shedding load aggressively, pausing retries, and draining the backlog before letting traffic back in"},
        {"id":"c","text":"A hot shard; re-partition the data"},
        {"id":"d","text":"A grey failure; replace the health check"}
      ],
      "correct": "b",
      "explanation": "Retries amplifying load, combined with an already-saturated queue, keeps the system stuck in its failed state even once traffic has returned to normal. Only reducing the work being admitted, through shedding, pausing retries, and draining, lets it fall back into a healthy state; simply adding more capacity often doesn't fix this on its own." }
] }
```

## Quick recap

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

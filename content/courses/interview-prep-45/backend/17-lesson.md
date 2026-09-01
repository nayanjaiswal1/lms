---
kind: lesson
id_key: interview-prep-45/day-17-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Distributed Systems Basics"
position: 17
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
The moment your backend runs on more than one machine, you inherit a new class of failures interviewers love to probe: what happens when the network drops a packet, or two nodes both think they're in charge? Today covers CAP theorem, a minimal distributed lock, retry with backoff, and the idempotency pattern that makes retries safe in the first place.

## CAP theorem and trade-offs

CAP says a distributed system can only guarantee two of three properties **during a network partition**:

- **Consistency**: every read sees the most recent write (or an error).
- **Availability**: every request gets a (non-error) response.
- **Partition tolerance**: the system keeps working despite dropped/delayed messages between nodes.

The catch interviewers check for: partitions *will* happen on any real network, so partition tolerance isn't optional. The real choice is **CP vs AP** when a partition is actually happening. A CP system (e.g. a Postgres primary with synchronous replication, etcd, Zookeeper) refuses writes it can't confirm are durable across nodes, sacrificing availability. An AP system (e.g. Cassandra in default config, DynamoDB) keeps answering requests on both sides of the partition and reconciles conflicts later, sacrificing strict consistency.

The question to ask is which failure mode fits the feature, not which system is "better" in the abstract. A payments ledger wants CP (better to reject a write than record two different balances). A social media like-counter wants AP (better to show a slightly stale count than go down).

## Eventual consistency

**What is eventual consistency?** A guarantee that if no new writes occur, all replicas will *eventually* converge to the same value, with no bound on how long "eventually" takes, though in practice it's milliseconds to seconds. It's what AP systems offer in place of strong consistency. Concretely: you write to replica A, a read hits replica B a moment later and gets the old value, but a read a bit after that gets the new value once replication catches up.

Read-your-own-writes is the common complaint about eventual consistency in interviews. A user posts a comment, refreshes, and doesn't see it because their read landed on a lagging replica. Standard fixes: route a user's reads to the primary (or the replica that served their last write) for a short window, or use session tokens that pin reads to a replica at least as fresh as the write.

## Distributed lock (minimal version)

A distributed lock coordinates access to a shared resource across processes/machines, for example ensuring only one worker runs a scheduled job at a time.

```python
import redis
import uuid
import time

r = redis.Redis(decode_responses=True)

def acquire_lock(resource: str, ttl_ms: int = 10_000) -> str | None:
    token = str(uuid.uuid4())
    # NX: only set if not already held. PX: auto-expire so a crashed
    # holder can't lock the resource forever.
    acquired = r.set(f"lock:{resource}", token, nx=True, px=ttl_ms)
    return token if acquired else None

def release_lock(resource: str, token: str) -> bool:
    # only release if we still hold it — a plain DEL could delete a lock
    # that expired and was re-acquired by someone else in the meantime
    script = """
    if redis.call('get', KEYS[1]) == ARGV[1] then
        return redis.call('del', KEYS[1])
    else
        return 0
    end
    """
    return bool(r.eval(script, 1, f"lock:{resource}", token))
```

Two details interviewers specifically probe:

1. **`SET NX PX` in one atomic command**: doing `EXISTS` then `SET` as two calls has a race window where two clients both see "not set" and both acquire the lock.
2. **Release via a Lua script that checks the token first**: without this, a slow client whose lock already expired (and got picked up by another client) would delete the *new* holder's lock on release.

This lock alone isn't safe against every failure. Redlock (Redis's own proposal for locking across multiple independent Redis nodes) and fencing tokens (a monotonically increasing number attached to each lock grant, so a downstream resource can reject a stale holder's writes even after that holder's lock has technically expired) go further into why TTL-based locks can still be unsafe under GC pauses or clock drift.

## Retry with exponential backoff

Naive immediate retries on a struggling downstream service make the problem worse (a thundering herd). Exponential backoff spaces retries out, and jitter prevents many clients from retrying in lockstep.

```python
import random
import time
from typing import Callable, TypeVar

T = TypeVar("T")

def retry_with_backoff(
    fn: Callable[[], T],
    max_attempts: int = 5,
    base_delay: float = 0.5,
    max_delay: float = 30.0,
) -> T:
    for attempt in range(max_attempts):
        try:
            return fn()
        except (ConnectionError, TimeoutError):
            if attempt == max_attempts - 1:
                raise
            # exponential growth capped at max_delay, plus full jitter
            delay = min(max_delay, base_delay * (2 ** attempt))
            delay = random.uniform(0, delay)
            time.sleep(delay)
    raise RuntimeError("unreachable")
```

"Full jitter" (`uniform(0, delay)` rather than a fixed exponential value) is the detail that separates a correct answer from a memorized one. AWS's own backoff writeup showed full jitter beats no-jitter and "equal jitter" backoff under contention because it decorrelates retry timing across many clients hitting the same failing service simultaneously.

## Idempotent API endpoint

**How do you handle network partitions?** For writes, the honest answer is "you can't always tell whether your write succeeded or the response was lost," so the client retries, and the server must make retries safe. That's idempotency: applying the same request N times has the same effect as applying it once.

```python
from django.db import transaction
from django.http import JsonResponse
import json

@transaction.atomic
def create_payment(request):
    body = json.loads(request.body)
    idempotency_key = request.headers.get("Idempotency-Key")
    if not idempotency_key:
        return JsonResponse({"error": "Idempotency-Key header required"}, status=400)

    existing = IdempotencyRecord.objects.select_for_update().filter(
        key=idempotency_key
    ).first()
    if existing:
        # same key seen before — return the original result, do not re-charge
        return JsonResponse(existing.response_body, status=existing.response_status)

    payment = Payment.objects.create(
        amount=body["amount"],
        account_id=body["account_id"],
    )
    response_body = {"payment_id": payment.id, "status": "created"}

    IdempotencyRecord.objects.create(
        key=idempotency_key,
        response_status=201,
        response_body=response_body,
    )
    return JsonResponse(response_body, status=201)
```

The idempotency key is generated client-side (once, before the first attempt) and sent on every retry of that logical request. The lookup-and-insert happens inside the same transaction as the actual write, so a crash between "create the payment" and "record the key" can't happen: either both commit or neither does. `POST` endpoints that mutate money, inventory, or anything non-repeatable should support this header; `PUT`/`DELETE` are naturally idempotent by HTTP semantics (though PUT is only idempotent if it's a full replace, not a partial increment).

All four topics in this lesson point at the same underlying lesson: a distributed system can't make the network reliable, so it has to make its own operations safe to repeat, safe to run twice, or safe to reject cleanly under a chosen trade-off. That's the thread an interviewer is really pulling on when they ask about CAP, locks, retries, or idempotency in the same conversation.

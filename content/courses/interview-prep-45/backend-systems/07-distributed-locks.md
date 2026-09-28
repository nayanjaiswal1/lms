---
kind: lesson
id_key: interview-prep-45/day-20-backend
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Distributed Locks"
position: 7
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

A distributed lock makes sure only one process at a time touches a shared resource, for example, only one worker runs a scheduled job at once, even though "the worker" might be running on five different machines. The basic Redis version (`SET key token NX PX ttl`, released with a token-checked script) looks solid, but it isn't safe under every failure mode. This lesson covers why, what Redlock proposes to fix it, and why even Redlock is a genuinely contested design. Martin Kleppmann and Redis's own creator publicly disagreed about it, and knowing both sides of that disagreement is what separates a strong answer here from a memorized one.

## Why a TTL alone doesn't make a lock safe

A lock's TTL (its expiry time) exists so a crashed holder doesn't lock the resource forever. But the TTL itself creates a new failure:

1. Client A acquires the lock, TTL 10 seconds.
2. Client A pauses for 15 seconds, a garbage-collection pause, a CPU steal in a shared VM, slow disk I/O, still believing it holds the lock.
3. The lock expires at 10 seconds. Client B acquires it and starts working on the protected resource.
4. Client A wakes up, finishes its work, and without a token check could release B's lock, or worse, both A and B now act on the resource the lock was supposed to serialize, at the same time.

The two things worth stating plainly in an interview: the release must be a script that checks a token, not a plain `DEL`, because check-then-delete without atomicity is a race condition; and the lock needs a TTL in the first place, so a crashed holder doesn't block everyone forever. But here is the deeper point those two details don't fully solve: **a lock's TTL is a guess about how long you'll hold it, and the process holding it has no way to know the guess was wrong until it's already too late.** No amount of "picking a better TTL" fixes this. It's a structural property of using a clock to coordinate mutual exclusion.

> **Remember:** a TTL protects against a holder that's gone. It does nothing for a holder that's merely paused past its TTL and still believes it's in charge.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedlocks-ttl-q1", "type": "mcq",
      "prompt": "A client holding a Redis lock pauses for a garbage-collection stop-the-world longer than the lock's TTL. What is the actual risk?",
      "options": [
        {"id":"a","text":"None, since Redis pauses the TTL countdown automatically during a client GC pause"},
        {"id":"b","text":"The lock expires while the paused client still believes it holds it; another client can then acquire it, and both can end up acting on the resource at once"},
        {"id":"c","text":"The paused client's connection is automatically terminated by Redis"},
        {"id":"d","text":"Redis extends the TTL automatically whenever a client is slow"}
      ],
      "correct": "b",
      "explanation": "A TTL is a timer Redis enforces regardless of what the holder is doing. A holder that pauses past it has no way to know the lock already expired, which opens a window where two clients both believe they're the sole holder." }
] }
```

## Lock with TTL and renewal

Renewal, a heartbeat that extends the TTL while work is ongoing, narrows the window above without closing it: the TTL now only expires if the holder is genuinely stuck, not merely slow to renew in time.

```python
import redis, threading, uuid

r = redis.Redis(decode_responses=True)

RELEASE_SCRIPT = """
if redis.call('get', KEYS[1]) == ARGV[1] then
    return redis.call('del', KEYS[1])
end
return 0
"""

RENEW_SCRIPT = """
if redis.call('get', KEYS[1]) == ARGV[1] then
    return redis.call('pexpire', KEYS[1], ARGV[2])
end
return 0
"""

class DistributedLock:
    def __init__(self, resource, ttl_ms=10_000):
        self.key, self.token, self.ttl_ms = f"lock:{resource}", str(uuid.uuid4()), ttl_ms
        self._stop_renewal = threading.Event()

    def acquire(self) -> bool:
        acquired = r.set(self.key, self.token, nx=True, px=self.ttl_ms)
        if acquired:
            self._start_renewal()
        return bool(acquired)

    def _start_renewal(self):
        def renew_loop():
            # renew at half the TTL, so one missed renewal still leaves time before real expiry
            while not self._stop_renewal.wait(self.ttl_ms / 2 / 1000):
                renewed = r.eval(RENEW_SCRIPT, 1, self.key, self.token, self.ttl_ms)
                if not renewed:
                    break   # someone else holds it now — stop pretending we do
        threading.Thread(target=renew_loop, daemon=True).start()

    def release(self):
        self._stop_renewal.set()
        r.eval(RELEASE_SCRIPT, 1, self.key, self.token)
```

This is the "watchdog" pattern: renew at half the TTL, so a single missed renewal doesn't cause an immediate expiry. Redis's own client library and Redlock's reference implementation both build this in under the hood.

> **Remember:** renewal narrows the failure window (it only fires if the holder is really stuck), it does not close it. A renewal thread can itself stall for the same reasons the original work could.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedlocks-renewal-q1", "type": "mcq",
      "prompt": "Why does the renewal loop renew the lock at half the TTL, rather than waiting until just before it expires?",
      "options": [
        {"id":"a","text":"Renewing more often just wastes Redis bandwidth for no benefit"},
        {"id":"b","text":"Renewing at half the TTL leaves a full half-TTL of buffer, so one missed or delayed renewal still doesn't let the lock expire before the next attempt"},
        {"id":"c","text":"Redis requires renewal to happen at exactly half the TTL"},
        {"id":"d","text":"It has no effect on safety, only on performance"}
      ],
      "correct": "b",
      "explanation": "Renewing right before expiry leaves no margin for a delayed renewal call. Renewing at the halfway point means even a missed cycle still has time before the lock would actually lapse." }
] }
```

## Redlock: quorum across independent instances

Redlock coordinates a lock across N independent Redis instances (separate masters, not replicas of each other, typically 5) so a single instance failing doesn't break the lock:

1. Record the current time.
2. Try to acquire the lock (the same `SET NX PX`) on all N instances, one at a time, using a short per-instance timeout so one down instance doesn't stall the whole attempt.
3. The lock counts as acquired only if it was acquired on a **majority** (N/2 + 1) of instances, **and** the total time spent acquiring is less than the TTL, since otherwise it may already be expiring on the earliest instances by the time you finish the last.
4. If acquired, the effective remaining validity is the TTL minus time spent acquiring, minus a small safety margin for clock drift.
5. If a majority wasn't reached, release the lock on every instance where it *was* acquired, and let the caller retry after a random delay.

```python
class Redlock:
    def __init__(self, nodes, ttl_ms=10_000):
        self.clients = [redis.Redis.from_url(url) for url in nodes]
        self.ttl_ms, self.quorum = ttl_ms, len(nodes) // 2 + 1

    def acquire(self, resource):
        token, start, acquired_count = str(uuid.uuid4()), time.monotonic(), 0
        for client in self.clients:
            try:
                if client.set(f"lock:{resource}", token, nx=True, px=self.ttl_ms):
                    acquired_count += 1
            except redis.RedisError:
                pass   # an unreachable node counts as a failed acquire, not a crash

        elapsed_ms = (time.monotonic() - start) * 1000
        validity_ms = self.ttl_ms - elapsed_ms - (self.ttl_ms * 0.01)   # 1% clock-drift margin
        if acquired_count >= self.quorum and validity_ms > 0:
            return token
        self._release_all(resource, token)
        return None
```

> **Remember:** Redlock's safety comes from quorum, a majority of independent instances agreeing, not from any single instance being trustworthy. A minority acquiring the lock is treated as a failure and cleaned up.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedlocks-redlock-q1", "type": "mcq",
      "prompt": "In Redlock with 5 nodes, a client successfully acquires the lock on 2 of them. What should happen?",
      "options": [
        {"id":"a","text":"Treat the lock as acquired, since 2 out of 5 is a reasonable majority"},
        {"id":"b","text":"Treat it as a failed acquisition, since 2 is below the quorum of 3, and release the lock on the 2 instances where it was set"},
        {"id":"c","text":"Wait indefinitely for the remaining 3 instances to respond"},
        {"id":"d","text":"Automatically extend the TTL on the 2 acquired instances"}
      ],
      "correct": "b",
      "explanation": "Redlock requires a majority, N/2 + 1, which for 5 nodes is 3. Acquiring only 2 is below quorum, so the correct behavior is to treat the attempt as failed and release the partial locks rather than proceed as if you held it." }
] }
```

## What Redlock does not solve

This is the question interviewers ask specifically to check whether you know the critique, not just the algorithm.

- **TTL races with pauses**, as covered above: no lock built on wall-clock TTLs can guarantee the holder is still logically the holder at the moment it acts.
- **Clock drift or jumps across nodes.** Redlock assumes clocks move forward at roughly the same rate on every instance. An NTP correction that jumps a clock backward or forward can make a lock look valid on one instance and expired on another.
- **The fencing token problem.** Even a "correctly acquired" lock only proves *who acquired it*, not that the protected resource itself will reject a write from a holder whose lock has since expired. Kleppmann's proposed fix is a monotonically increasing **fencing token** issued with every acquisition, so the protected resource rejects any write carrying a token lower than the last one it accepted. Standard Redlock, as originally specified, does not include this, and that gap is the core of the Kleppmann/antirez disagreement.
- **Sequential per-node cost.** Trying N instances one at a time, even with per-node timeouts, adds latency, which in practice pushes teams toward parallel acquisition or fewer, faster nodes.

> **Remember:** Redlock protects against one Redis instance failing. It does not protect against a paused holder, clock drift between nodes, or a downstream resource accepting a write from a holder that no longer actually owns the lock, that last one is what a fencing token fixes.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedlocks-fencing-q1", "type": "mcq",
      "prompt": "A client's Redlock lock expires, is re-acquired by another client, and then the original client's delayed write still reaches the protected resource. What closes this gap?",
      "options": [
        {"id":"a","text":"Using a longer TTL closes this gap completely"},
        {"id":"b","text":"A fencing token: the resource itself rejects any write carrying a lock-acquisition token lower than the last one it accepted, regardless of what the lock service believes"},
        {"id":"c","text":"Adding more Redis nodes to the Redlock cluster"},
        {"id":"d","text":"This gap cannot exist if the lock was acquired correctly"}
      ],
      "correct": "b",
      "explanation": "A lock only tracks who acquired it, not whether a delayed write from a former holder still lands. A fencing token makes the resource itself enforce ordering, rejecting any stale write regardless of what the lock currently says." }
] }
```

## When a TTL+renewal lock is good enough

Practical answer, in order of increasing rigor:

1. Pick a TTL comfortably larger than the expected work duration, and renew via a heartbeat, so expiration only fires when the holder is genuinely gone.
2. Always release through a token check, never a bare `DEL`.
3. For anything where a stale-lock double-execution would cause real damage, double-charging a payment, corrupting a file, don't rely on the lock alone. Add fencing tokens so the resource enforces ordering itself, or make the operation idempotent so a duplicate execution is harmless regardless of locking.
4. For most application-level uses, preventing a scheduled job from double-running, deduping a webhook handler, a TTL-plus-renewal lock without fencing is a pragmatic, industry-standard trade-off. Know which tier you're in, and say so explicitly.

The thread running through this whole lesson: a lock is only as trustworthy as the clock and scheduler underneath it. Every fix here, renewal, quorum, fencing, narrows the gap between "I believe I hold the lock" and "I actually still hold the lock." None of them close that gap completely.

> **Remember:** know which tier your use case is in. "Good enough" (TTL plus renewal) versus "needs fencing or idempotency" is a decision you should be able to justify out loud, not guess at.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedlocks-tier-q1", "type": "mcq",
      "prompt": "A scheduled cleanup job uses a Redis lock so it never runs on two machines at once. If the lock's safety guarantee is occasionally imperfect, what's the actual risk?",
      "options": [
        {"id":"a","text":"A payment could be charged twice"},
        {"id":"b","text":"The cleanup job might run twice in a rare edge case, which is usually a low-stakes, tolerable outcome for this kind of task"},
        {"id":"c","text":"Data loss across the entire database"},
        {"id":"d","text":"There is no way to reason about the risk without fencing tokens"}
      ],
      "correct": "b",
      "explanation": "Knowing which tier a use case falls into is the point: a scheduled cleanup job double-running occasionally is usually a tolerable, low-stakes outcome, which is exactly the case where a TTL-plus-renewal lock without fencing is a reasonable, industry-standard trade-off." }
] }
```

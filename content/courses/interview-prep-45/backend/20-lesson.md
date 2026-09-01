---
kind: lesson
id_key: interview-prep-45/day-20-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Distributed Locks"
position: 20
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
The previous lesson built a minimal Redis lock (`SET key token NX PX ttl`, released via a token-checked Lua script) as a way to make sure only one process touches a shared resource at a time. Today goes deeper into why that lock isn't actually safe under every failure mode, what Redlock proposes to fix it, and why even Redlock is a genuinely contested design. Martin Kleppmann and Redis's creator publicly disagreed on it, and knowing both sides is what separates a strong interview answer here. You'll implement TTL-with-renewal and a Redlock-style multi-instance lock.

## Why a single-instance TTL lock isn't fully safe

The TTL on that lock exists so a crashed holder doesn't lock the resource forever. But the TTL itself creates a new failure mode:

1. Client A acquires the lock, TTL 10s.
2. Client A pauses for 15 seconds (a GC pause, CPU steal in a VM, slow disk I/O), still believing it holds the lock.
3. The lock expires at 10s. Client B acquires it and starts working on the protected resource.
4. Client A wakes up, finishes its work, and (without the token check) could release B's lock or, worse, both A and B are now concurrently acting on the resource the lock was supposed to serialize.

This is the core critique: **a lock's TTL is a guess about how long you'll hold it, and the process holding it has no way to know the guess was wrong until it's too late.** No amount of "picking a better TTL" fixes this. It's a fundamental property of using time to coordinate mutual exclusion.

## Lock with TTL and renewal

Renewal (a "heartbeat" that extends the TTL while work is ongoing) narrows the window but doesn't close it. It just means the TTL only expires if the holder is *actually* stuck, not merely slow to renew in time.

```python
import redis
import threading
import uuid

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
    def __init__(self, resource: str, ttl_ms: int = 10_000):
        self.key = f"lock:{resource}"
        self.token = str(uuid.uuid4())
        self.ttl_ms = ttl_ms
        self._stop_renewal = threading.Event()
        self._renewal_thread = None

    def acquire(self) -> bool:
        acquired = r.set(self.key, self.token, nx=True, px=self.ttl_ms)
        if acquired:
            self._start_renewal()
        return bool(acquired)

    def _start_renewal(self):
        def renew_loop():
            # renew at half the TTL, so a single missed renewal still
            # leaves time before the lock actually expires
            while not self._stop_renewal.wait(self.ttl_ms / 2 / 1000):
                renewed = r.eval(RENEW_SCRIPT, 1, self.key, self.token, self.ttl_ms)
                if not renewed:
                    break  # someone else holds it now — stop pretending we do
        self._renewal_thread = threading.Thread(target=renew_loop, daemon=True)
        self._renewal_thread.start()

    def release(self):
        self._stop_renewal.set()
        if self._renewal_thread:
            self._renewal_thread.join(timeout=1)
        r.eval(RELEASE_SCRIPT, 1, self.key, self.token)
```

Redis's own client library (`redis-py`'s `Lock` class) and Redlock's `redlock-py` both implement this "watchdog" pattern under the hood.

## The Redlock algorithm

Redlock coordinates a lock across N independent Redis instances (not replicas of each other but separate masters, typically 5) to survive a single instance failing:

1. Get the current time.
2. Try to acquire the lock (same `SET NX PX`) on all N instances sequentially, using a short timeout per instance so a down instance doesn't stall the whole attempt.
3. The lock is considered acquired only if it was acquired on a **majority** (N/2 + 1) of instances, **and** the total time spent acquiring is less than the lock's TTL (otherwise it may have already started expiring on the first instances by the time you finish acquiring the last).
4. If acquired, the effective lock validity is the original TTL minus the time spent acquiring, minus a small clock-drift safety margin.
5. If not acquired on a majority, release the lock on every instance you did acquire it on, and let the caller retry after a random delay.

```python
import redis
import time
import uuid

class Redlock:
    def __init__(self, nodes: list[str], ttl_ms: int = 10_000):
        self.clients = [redis.Redis.from_url(url, decode_responses=True) for url in nodes]
        self.ttl_ms = ttl_ms
        self.quorum = len(nodes) // 2 + 1

    def acquire(self, resource: str) -> str | None:
        token = str(uuid.uuid4())
        start = time.monotonic()
        acquired_count = 0

        for client in self.clients:
            try:
                if client.set(f"lock:{resource}", token, nx=True, px=self.ttl_ms):
                    acquired_count += 1
            except redis.RedisError:
                pass  # treat an unreachable node as a failed acquire, not a crash

        elapsed_ms = (time.monotonic() - start) * 1000
        validity_ms = self.ttl_ms - elapsed_ms - (self.ttl_ms * 0.01)  # 1% clock-drift margin

        if acquired_count >= self.quorum and validity_ms > 0:
            return token

        self._release_all(resource, token)  # didn't reach quorum — clean up partial locks
        return None

    def _release_all(self, resource: str, token: str):
        script = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) end return 0"
        for client in self.clients:
            try:
                client.eval(script, 1, f"lock:{resource}", token)
            except redis.RedisError:
                pass
```

## What are the problems with distributed locks?

This is the question interviewers ask specifically to see if you know Redlock's critique, not just its algorithm:

- **TTL races with GC/scheduling pauses** (explained above): no lock built on wall-clock TTLs can guarantee the holder is still "logically" the holder when it acts.
- **Clock drift/jumps across nodes**: Redlock assumes clocks move forward at roughly the same rate on all N instances. An NTP correction that jumps a clock backward or forward can make a lock appear valid/expired inconsistently across instances.
- **The fencing token problem**: even a "correct" lock only tells you *who acquired it*, not that the resource being protected (e.g. a file, a database row) will reject writes from a holder whose lock has since expired. Kleppmann's proposed fix: the lock service hands out a monotonically increasing **fencing token** with each acquisition, and the protected resource itself rejects any write tagged with a token lower than the last one it accepted. Redlock, as originally specified, doesn't include this, which was the crux of the Kleppmann/antirez disagreement.
- **Sequential per-node acquisition cost**: trying N instances one at a time (with per-node timeouts) adds latency; in practice this pushes teams toward parallel acquisition or fewer, faster nodes.

## How do you handle lock expiration?

Practical answer, in order of increasing rigor:

1. Pick a TTL comfortably larger than the expected work duration, and renew via a heartbeat (as implemented above) so expiration only fires when the holder is genuinely gone.
2. Always release via a token check, never a bare `DEL`.
3. For anything where a stale-lock double-execution would cause real damage (double-charging a payment, corrupting a file), don't rely on the lock alone. Add fencing tokens so the protected resource itself enforces ordering, or make the protected operation idempotent so a duplicate execution is harmless regardless of locking.
4. For most application-level uses (preventing a scheduled job from double-running, deduping a webhook handler), a TTL+renewal lock without fencing is a pragmatic, industry-standard trade-off. Know when you're in that "good enough" tier versus the "needs fencing" tier, and say so explicitly in the interview.

The thread running through this lesson: a lock is only ever as trustworthy as the clock and scheduler underneath it, and every fix here (renewal, quorum, fencing) is really about narrowing the gap between "I believe I hold the lock" and "I actually still hold the lock" rather than closing it completely.

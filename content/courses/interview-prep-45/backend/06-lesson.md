---
kind: lesson
id_key: interview-prep-45/day-06-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Redis Caching Strategies"
position: 6
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Redis shows up in nearly every backend system design interview as "add a cache in front of the DB" — but the follow-ups (invalidation, stampedes, distributed locks) are where candidates fall apart. Today: the data structures that actually matter, a real cache-aside implementation, a Redis-backed rate limiter, and a distributed lock with its well-known failure modes.

## Redis data structures and when to use each

| Type | Use case |
|---|---|
| **String** | Simple key-value cache entry, counters (`INCR`), feature flags |
| **Hash** | Object-like data (a user profile) without deserializing a whole JSON blob to read one field |
| **List** | Queues, recent-activity feeds (`LPUSH` + `LTRIM` to cap size) |
| **Set** | Unique membership checks, tag lists, "has this user done X" |
| **Sorted Set (ZSET)** | Leaderboards, rate-limiting windows, anything ranked by a score (score = timestamp for sliding windows) |
| **Stream** | Append-only event log, consumer groups — a lightweight Kafka alternative |

```python
import redis

r = redis.Redis(host="localhost", port=6379, decode_responses=True)

r.set("user:42:name", "Ada", ex=300)          # string with 300s TTL
r.hset("user:42", mapping={"name": "Ada", "plan": "pro"})  # hash — update one field without touching others
r.zadd("leaderboard", {"user:42": 1500})       # sorted set — O(log n) insert, ranked reads
r.zrevrange("leaderboard", 0, 9, withscores=True)  # top 10
```

## Cache-aside pattern

The most common caching pattern in backend systems: the application checks the cache first, falls back to the source of truth on a miss, and populates the cache for next time.

```python
import json
import redis

r = redis.Redis(host="localhost", port=6379, decode_responses=True)

CACHE_TTL_SECONDS = 300


def get_user(user_id: int, db) -> dict:
    cache_key = f"user:{user_id}"

    cached = r.get(cache_key)
    if cached is not None:
        return json.loads(cached)  # cache hit — no DB round trip

    # cache miss — fall back to the database
    user = db.query_one("SELECT id, name, email FROM users WHERE id = %s", [user_id])
    if user is None:
        return None

    r.set(cache_key, json.dumps(user), ex=CACHE_TTL_SECONDS)
    return user


def update_user(user_id: int, fields: dict, db) -> None:
    db.execute("UPDATE users SET name = %s WHERE id = %s", [fields["name"], user_id])
    r.delete(f"user:{user_id}")  # invalidate on write — don't try to update the cache in place
```

**Why delete on write instead of update-in-place:** updating the cache to match a write requires the cache to always be a perfect mirror of the write logic — any code path that writes and forgets to update the cache leaves stale data forever. Deleting is simpler and self-healing: the next read repopulates from the source of truth. This is the answer to "what is cache invalidation" — cache invalidation is the problem of keeping cached data consistent with its source, and delete-on-write (rather than update-on-write) is the standard way to avoid the "there are only two hard problems in computer science" trap.

**The other classic failure mode — cache stampede:** if a hot key expires and 1000 concurrent requests all miss at once, all 1000 hit the database simultaneously to repopulate it. Mitigate with a short lock around the repopulation (below), jittered TTLs so keys don't all expire at the same second, or serving stale data while one request refreshes in the background.

## Distributed lock (and its real problems)

A basic Redis lock uses `SET key value NX PX ttl` — set only if the key doesn't already exist (`NX`), with an expiry (`PX`, milliseconds) so a crashed holder doesn't lock everyone out forever.

```python
import uuid
import time

def acquire_lock(r: redis.Redis, lock_name: str, ttl_ms: int = 5000) -> str | None:
    token = str(uuid.uuid4())  # unique per acquisition attempt — needed to release safely
    acquired = r.set(f"lock:{lock_name}", token, nx=True, px=ttl_ms)
    return token if acquired else None


# Lua script so check-and-delete is atomic — a plain GET-then-DELETE from Python has a race window
RELEASE_LOCK_SCRIPT = """
if redis.call("GET", KEYS[1]) == ARGV[1] then
    return redis.call("DEL", KEYS[1])
else
    return 0
end
"""

def release_lock(r: redis.Redis, lock_name: str, token: str) -> bool:
    result = r.eval(RELEASE_LOCK_SCRIPT, 1, f"lock:{lock_name}", token)
    return result == 1


def with_lock(r: redis.Redis, lock_name: str, ttl_ms: int = 5000):
    token = acquire_lock(r, lock_name, ttl_ms)
    if token is None:
        raise RuntimeError(f"Could not acquire lock: {lock_name}")
    try:
        yield
    finally:
        release_lock(r, lock_name, token)
```

**The unique token matters:** without it, process A could acquire the lock, take longer than the TTL, have the lock auto-expire, process B acquires it — and then process A finishes and blindly deletes the key, releasing a lock it no longer owns and letting a third process C acquire it while B still thinks it holds it. The token makes release conditional on "am I still the owner," closing that window.

**What interviewers want you to say about distributed locks with a single Redis instance:** this pattern is *not* safe under Redis failover. If the Redis master crashes right after granting a lock but before replicating it to a replica, and that replica gets promoted to master, a second client can acquire the "same" lock — because the replica never saw it. This is the exact critique Martin Kleppmann made of Redlock. For correctness-critical locking (not just "reduce duplicate work"), use a system with real consensus (e.g. a Postgres advisory lock inside a transaction, or ZooKeeper/etcd) — Redis locks are best treated as a **best-effort** optimization, not a correctness guarantee, unless you specifically implement and understand Redlock's multi-instance quorum protocol.

## Rate limiter with Redis

A sliding-window counter using `INCR` + `EXPIRE`, simple and good enough for most APIs:

```python
def is_rate_limited(r: redis.Redis, user_id: int, limit: int = 100, window_seconds: int = 60) -> bool:
    key = f"ratelimit:{user_id}:{int(time.time()) // window_seconds}"
    count = r.incr(key)
    if count == 1:
        r.expire(key, window_seconds)  # only set TTL on the first request in this window
    return count > limit
```

This is a **fixed-window** limiter — cheap, but it allows up to `2x limit` requests across a window boundary (a burst at the end of one window plus a burst at the start of the next). A sliding-window-log using a sorted set is more accurate at the cost of more memory:

```python
def is_rate_limited_sliding(r: redis.Redis, user_id: int, limit: int = 100, window_seconds: int = 60) -> bool:
    key = f"ratelimit:sliding:{user_id}"
    now = time.time()
    pipe = r.pipeline()
    pipe.zremrangebyscore(key, 0, now - window_seconds)  # drop entries older than the window
    pipe.zadd(key, {str(uuid.uuid4()): now})               # record this request
    pipe.zcard(key)                                         # count requests in the window
    pipe.expire(key, window_seconds)
    _, _, count, _ = pipe.execute()
    return count > limit
```

Using `r.pipeline()` batches these four commands into a single round trip — worth mentioning as a general Redis performance technique, not just for rate limiting.

## Key takeaways

- Pick the Redis type that matches the access pattern: strings for simple values, hashes for partial-field reads, sorted sets for anything ranked or windowed.
- Cache-aside: read-through on miss, delete (not update) on write — deletion is simpler and self-healing.
- Cache stampede is the classic cache-aside failure mode: a hot key's expiry causes a thundering herd of simultaneous DB hits; mitigate with locking, jitter, or stale-while-revalidate.
- A Redis lock needs a unique per-holder token and an atomic compare-and-delete (Lua script) on release — a plain GET-then-DELETE has a race.
- Single-instance Redis locks are best-effort, not correctness guarantees — they can fail across a master/replica failover; use Postgres advisory locks or a consensus system when correctness actually matters.
- A fixed-window rate limiter is cheap but bursts at window boundaries; a sorted-set sliding-window log is accurate but costs more memory per key.

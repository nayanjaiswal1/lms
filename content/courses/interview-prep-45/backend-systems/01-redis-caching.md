---
kind: lesson
id_key: interview-prep-45/day-06-backend
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Redis Caching"
position: 1
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Redis shows up in nearly every backend system design interview as "put a cache in front of the database." The follow-up questions, invalidation, stampedes, eviction, are where most candidates fall apart. This lesson covers the data structures that actually matter, a real cache-aside implementation, a Redis-backed rate limiter, and what happens when Redis itself runs out of memory.

## Redis data structures and when to use each

| Type | Use it for |
|---|---|
| **String** | A simple cached value, a counter (`INCR`), a feature flag |
| **Hash** | Object-like data, a user profile, where you want to read or update one field without touching the rest |
| **List** | A queue, or a capped recent-activity feed (`LPUSH` plus `LTRIM`) |
| **Set** | Unique membership checks: "has this user already done X" |
| **Sorted Set (ZSET)** | Anything ranked by a number: leaderboards, rate-limit windows |
| **Stream** | An append-only event log with consumer groups, a lightweight Kafka |

```python
import redis

r = redis.Redis(host="localhost", port=6379, decode_responses=True)

r.set("user:42:name", "Ada", ex=300)                        # string, expires in 300s
r.hset("user:42", mapping={"name": "Ada", "plan": "pro"})   # hash: update one field, leave the rest
r.zadd("leaderboard", {"user:42": 1500})                    # sorted set: O(log n) insert, ranked reads
r.zrevrange("leaderboard", 0, 9, withscores=True)           # top 10
```

> **Remember:** pick the Redis type that matches the *access pattern* you need, not just "can this data fit in a string." A leaderboard is a sorted set because you need ranked reads, not just storage.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-rediscaching-types-q1", "type": "mcq",
      "prompt": "Why store a user's profile fields in a Redis hash instead of one JSON string?",
      "options": [
        {"id":"a","text":"Hashes are always faster to read than strings, regardless of access pattern"},
        {"id":"b","text":"A hash lets you read or update one field directly, without deserializing and re-serializing the entire object for every small change"},
        {"id":"c","text":"Strings cannot hold more than 100 characters in Redis"},
        {"id":"d","text":"Hashes automatically expire after one hour"}
      ],
      "correct": "b",
      "explanation": "A hash exposes per-field access (HSET/HGET on one field). A JSON string forces you to load and re-parse the whole blob even to change a single field." }
] }
```

## Cache-aside: the default pattern

The application checks the cache first, falls back to the source of truth on a miss, and fills the cache for next time.

```python
CACHE_TTL_SECONDS = 300

def get_user(user_id: int, db) -> dict:
    cache_key = f"user:{user_id}"
    cached = r.get(cache_key)
    if cached is not None:
        return json.loads(cached)                      # hit — no DB round trip

    user = db.query_one("SELECT id, name, email FROM users WHERE id = %s", [user_id])
    if user is None:
        return None
    r.set(cache_key, json.dumps(user), ex=CACHE_TTL_SECONDS)
    return user

def update_user(user_id: int, fields: dict, db) -> None:
    db.execute("UPDATE users SET name = %s WHERE id = %s", [fields["name"], user_id])
    r.delete(f"user:{user_id}")                          # invalidate — don't rewrite in place
```

**Why delete on write, instead of updating the cache in place?** Updating the cache to match a write means every single write path must remember to keep the cache in sync. One forgotten spot leaves stale data forever. Deleting is simpler and self-healing: the very next read repopulates the cache from the real source of truth.

**Cache stampede** is the other classic failure. If one hot key expires and a thousand requests all miss at the same instant, all thousand hit the database at once to refill it. Mitigate with a short lock around the refill, jittered TTLs so keys don't all expire in the same second, or serving the stale value while one request refreshes it in the background.

> **Remember:** on write, delete the cache key, don't overwrite it. The next read repopulates from the real source of truth, which is simpler than keeping two copies in sync forever.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-rediscaching-aside-q1", "type": "mcq",
      "prompt": "Why does update_user() delete the cache key instead of writing the new value into the cache directly?",
      "options": [
        {"id":"a","text":"Deleting is always faster than a SET call"},
        {"id":"b","text":"Overwriting the cache requires every write path to correctly mirror the write logic; a forgotten path leaves stale data forever, while deleting is simple and self-healing on the next read"},
        {"id":"c","text":"Redis does not allow overwriting an existing key"},
        {"id":"d","text":"Deleting uses less memory than any SET call"}
      ],
      "correct": "b",
      "explanation": "Delete-on-write means the next read always goes back to the real source of truth. Update-in-place requires every write path to remember to keep the cache correct, which is easy to get wrong in one forgotten corner of the codebase." }
] }
```

## Eviction policies: what happens when Redis runs out of memory

Once Redis hits its configured `maxmemory`, it has to free space for a new write. Which key it throws away is the eviction policy.

| Policy | Behavior |
|---|---|
| `noeviction` | Reject the write with an error instead of evicting anything |
| `allkeys-lru` / `allkeys-lfu` | Evict least-recently / least-frequently used, across every key |
| `volatile-lru` / `volatile-lfu` / `volatile-ttl` | Same idea, but only considers keys that already have a TTL set |
| `allkeys-random` | Evict a random key |

The choice depends on what Redis is holding. If Redis is a pure cache, everything in it is disposable and can be rebuilt from the database, so an `allkeys-*` policy is safe. If Redis mixes disposable cache data with data you actually need to keep, like session state or queue contents, use a `volatile-*` policy instead: only the keys you deliberately gave a TTL become eligible for eviction, and anything without one is never silently dropped under memory pressure.

> **Remember:** if Redis only holds a cache, `allkeys-*` is safe. If it also holds data you can't afford to lose, use `volatile-*` so only your TTL'd cache keys are ever evicted.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-rediscaching-eviction-q1", "type": "mcq",
      "prompt": "A Redis instance holds both disposable cache entries (with a TTL) and session data (no TTL) that must never be silently dropped. Which eviction policy fits?",
      "options": [
        {"id":"a","text":"allkeys-lru, since it evicts across every key regardless of TTL"},
        {"id":"b","text":"volatile-lru, since it only considers keys that already have a TTL set, leaving the untimed session data alone"},
        {"id":"c","text":"noeviction, so nothing is ever evicted under any circumstances"},
        {"id":"d","text":"allkeys-random, since randomness is fair to every key"}
      ],
      "correct": "b",
      "explanation": "A volatile-* policy only evicts keys that were given an explicit TTL. Mixing cache data (TTL'd) with data you must keep (no TTL) is exactly the case this policy is built for." }
] }
```

## A distributed lock, and its real problems

`SET key value NX PX ttl` sets a key only if it doesn't already exist (`NX`), with an expiry in milliseconds (`PX`) so a crashed holder doesn't lock everyone out forever.

```python
import uuid

def acquire_lock(r: redis.Redis, lock_name: str, ttl_ms: int = 5000) -> str | None:
    token = str(uuid.uuid4())                            # unique per attempt, needed to release safely
    acquired = r.set(f"lock:{lock_name}", token, nx=True, px=ttl_ms)
    return token if acquired else None

# Release must be one atomic check-and-delete — a plain GET then DEL from Python has a race window
RELEASE_LOCK_SCRIPT = """
if redis.call("GET", KEYS[1]) == ARGV[1] then
    return redis.call("DEL", KEYS[1])
else
    return 0
end
"""

def release_lock(r: redis.Redis, lock_name: str, token: str) -> bool:
    return r.eval(RELEASE_LOCK_SCRIPT, 1, f"lock:{lock_name}", token) == 1
```

Here's why the token matters: without it, process A acquires the lock, runs longer than the TTL, and the lock expires while A is still working. Process B then acquires it. When A finally finishes, a plain `DEL` would release a lock A no longer owns, letting a third process C grab it while B still believes it's the only holder. Checking the token before deleting closes that window.

What interviewers actually want you to say: a single Redis instance's lock is **not** safe across a failover. If the primary crashes right after granting a lock, before replicating it to a replica, and that replica gets promoted, a second client can acquire the "same" lock, because the new primary never saw it. Treat this as a best-effort optimization, not a correctness guarantee, unless you specifically implement and understand a multi-instance quorum protocol like Redlock.

> **Remember:** release a lock with a token-checked script, never a plain `DEL`. A single Redis instance's lock is best-effort, not safe across a failover.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-rediscaching-lock-q1", "type": "mcq",
      "prompt": "Why must releasing a Redis lock be a Lua script that checks the token, rather than a plain DEL?",
      "options": [
        {"id":"a","text":"A plain DEL is slower than a Lua script"},
        {"id":"b","text":"A slow holder's lock can expire and be re-acquired by another process; a plain DEL would then release the new holder's lock instead of just its own"},
        {"id":"c","text":"Redis does not support DEL on keys with a TTL"},
        {"id":"d","text":"Lua scripts are required for every Redis command"}
      ],
      "correct": "b",
      "explanation": "If the original holder's TTL expires before it finishes, another client can acquire the same key. A plain DEL then releases whatever is currently there, not necessarily your own lock. Checking the token first makes the release conditional on still being the true owner." }
] }
```

## A sliding-window rate limiter

A fixed-window counter (`INCR` plus `EXPIRE`) is cheap but allows a burst of up to twice the limit across a window boundary: once right before the window resets, once right after.

```python
def is_rate_limited_sliding(r: redis.Redis, user_id: int, limit: int = 100, window_seconds: int = 60) -> bool:
    key = f"ratelimit:sliding:{user_id}"
    now = time.time()
    pipe = r.pipeline()
    pipe.zremrangebyscore(key, 0, now - window_seconds)   # drop entries older than the window
    pipe.zadd(key, {str(uuid.uuid4()): now})               # record this request
    pipe.zcard(key)                                         # count requests in the window
    pipe.expire(key, window_seconds)
    _, _, count, _ = pipe.execute()
    return count > limit
```

`r.pipeline()` batches these four commands into a single round trip. That's worth naming as a general Redis technique beyond rate limiting: fewer round trips, and Redis runs a pipeline's commands without another client's commands interleaved in between, though it is not a single atomic step the way a Lua script is. For true atomicity under heavy concurrent access to the same key, move this logic into a Redis Lua script so the whole read-check-write happens as one atomic step on the server.

> **Remember:** a fixed-window counter allows a 2x burst at the window boundary. A sorted set that prunes old entries before counting fixes that at the cost of more memory per key.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-rediscaching-ratelimit-q1", "type": "mcq",
      "prompt": "What is the specific weakness of a fixed-window rate limiter (INCR plus EXPIRE) that a sliding-window sorted set fixes?",
      "options": [
        {"id":"a","text":"Fixed windows cannot be implemented in Redis at all"},
        {"id":"b","text":"A client can send up to double the limit by bursting right before a window resets and again right after, since the two windows are counted independently"},
        {"id":"c","text":"INCR is not atomic, so counts can be lost"},
        {"id":"d","text":"Fixed windows use more memory than sorted sets"}
      ],
      "correct": "b",
      "explanation": "A fixed window resets its count to zero at a clock boundary, with no memory of requests just before it. A burst at the very end of one window plus a burst at the very start of the next can total nearly double the limit in a short span." }
] }
```

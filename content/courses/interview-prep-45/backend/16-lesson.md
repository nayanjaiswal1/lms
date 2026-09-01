---
kind: lesson
id_key: interview-prep-45/day-16-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Redis Advanced Patterns"
position: 16
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Redis interview questions rarely stop at "it's a key-value store." Interviewers want to see you pick the right data structure for a real feature (leaderboards, live feeds, rate limiters) and reason about what happens when Redis restarts or dies mid-write. Today covers sorted sets, streams, pub/sub, persistence trade-offs, and building a sliding-window rate limiter from scratch.

## Sorted sets: the leaderboard data structure

A sorted set (`ZSET`) stores unique members each with a floating-point score, kept in score order, with O(log N) inserts and O(log N + M) range queries. That's exactly a leaderboard's access pattern: update a score, read the top N, look up someone's rank.

```python
import redis

r = redis.Redis(host="localhost", port=6379, decode_responses=True)

# record/update a score — ZADD overwrites if the member already exists
r.zadd("leaderboard:weekly", {"user:42": 1500})
r.zincrby("leaderboard:weekly", 250, "user:42")   # += 250, atomic

# top 10, highest score first
top10 = r.zrevrange("leaderboard:weekly", 0, 9, withscores=True)

# a specific user's rank (0-indexed, descending) and score
rank = r.zrevrank("leaderboard:weekly", "user:42")
score = r.zscore("leaderboard:weekly", "user:42")
```

Under the hood a `ZSET` is a skip list plus a hash table: the hash table gives O(1) score lookups by member, the skip list gives ordered range scans. That combination is why `ZADD`, `ZSCORE`, and `ZRANGE` are all fast. An interviewer asking "how would you implement a leaderboard without Redis" is really asking whether you understand this trade-off: a plain SQL table with `ORDER BY score` needs an index scan and re-sorts on every write-heavy update, while the skip list keeps order incrementally.

## Streams: append-only logs with consumer groups

`XADD` appends immutable entries to a stream; unlike pub/sub, entries persist and can be replayed. Consumer groups let multiple workers split a stream's entries without duplicating work, and each entry is only acknowledged once processed, giving at-least-once delivery with retry on crash.

```python
# producer
r.xadd("events:orders", {"order_id": "501", "status": "created"})

# consumer group setup (once)
r.xgroup_create("events:orders", "order-processors", id="0", mkstream=True)

# each worker reads new entries and never sees another worker's entries
while True:
    resp = r.xreadgroup(
        "order-processors", "worker-1",
        {"events:orders": ">"}, count=10, block=5000,
    )
    for stream, entries in resp or []:
        for entry_id, fields in entries:
            process(fields)
            r.xack("events:orders", "order-processors", entry_id)  # confirm processed
```

If `worker-1` crashes after reading but before acking, the entry sits in the group's Pending Entries List (PEL). `XCLAIM`/`XAUTOCLAIM` let another worker take over stale pending entries after a timeout. This is the mechanism interviewers are checking for when they ask "how do you not lose messages if a consumer dies."

## Pub/sub: fire-and-forget real-time updates

```python
# publisher
r.publish("chat:room-7", '{"user": "alice", "msg": "hi"}')

# subscriber
pubsub = r.pubsub()
pubsub.subscribe("chat:room-7")
for message in pubsub.listen():
    if message["type"] == "message":
        handle(message["data"])
```

The critical distinction from streams: pub/sub has **no persistence and no replay**. A message published while a subscriber is disconnected is gone forever, since Redis doesn't buffer it. Use pub/sub for ephemeral broadcast (typing indicators, live cursors); use streams when a consumer must never miss an event.

## Redis persistence

Two mechanisms, often combined:

- **RDB (snapshotting)**: periodic point-in-time dumps of the whole dataset to disk (`save 900 1` etc.). Fast to restart from, but any writes since the last snapshot are lost on crash.
- **AOF (append-only file)**: every write command is logged; on restart Redis replays the log. `appendfsync everysec` (default) fsyncs once per second, so at most 1 second of writes is lost on a hard crash; `always` fsyncs every write (durable, much slower).

Interview answer for "what is Redis persistence": RDB trades durability for fast restarts and compact backups; AOF trades write throughput for a small, bounded data-loss window. Production setups typically enable both, RDB for fast full recovery/backups and AOF for minimizing loss between snapshots.

**How do you handle Redis failure?** Run Redis Sentinel or Redis Cluster for automatic failover: Sentinel monitors a primary and its replicas, and promotes a replica to primary if the original stops responding, updating clients via pub/sub notifications. Application code should never treat Redis as a source of truth for data that can't be reconstructed. Cache misses fall back to Postgres; anything Redis alone holds (session state, rate-limit counters) should tolerate being reset.

## Implementation: sliding-window rate limiter

Fixed-window counters (`INCR key; EXPIRE key 60`) allow bursts at window boundaries: a client can send the limit twice, once right before a window resets and once right after. A sliding window log fixes that using a sorted set keyed by timestamp:

```python
import time
import redis

r = redis.Redis(decode_responses=True)

def is_allowed(user_id: str, limit: int = 100, window_seconds: int = 60) -> bool:
    key = f"ratelimit:{user_id}"
    now = time.time()
    window_start = now - window_seconds

    pipe = r.pipeline()
    pipe.zremrangebyscore(key, 0, window_start)   # drop entries older than the window
    pipe.zcard(key)                                # count what's left
    pipe.zadd(key, {str(now): now})                # record this request
    pipe.expire(key, window_seconds)               # let idle keys evict themselves
    _, current_count, _, _ = pipe.execute()

    return current_count < limit
```

Why a pipeline: each command is one round trip; wrapping them cuts four round trips to one and, because Redis executes a pipeline's commands without interleaving another client's commands between them, avoids one client's read racing another client's write on the same key. It's not a single atomic operation the way a Lua script is. For true atomicity under heavy concurrency (many workers hitting the same key), move this logic into a Redis Lua script (`EVAL`) so the whole read-check-write happens as one atomic step server-side.

```lua
-- rate_limit.lua — same logic, atomic on the server
local key = KEYS[1]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])

redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
local count = redis.call('ZCARD', key)
if count < limit then
    redis.call('ZADD', key, now, now)
    redis.call('EXPIRE', key, window)
    return 1
end
return 0
```

Streams and pub/sub look similar on the surface (both fan messages out to consumers) but answer different questions: streams give durable, replayable, at-least-once delivery via consumer groups and the pending-entries list, while pub/sub gives none of that and drops messages sent while a subscriber is offline. Picking between them in an interview is really picking between "can I afford to lose this message" and "do I need the absolute lowest latency and don't care if a disconnected client misses an update."

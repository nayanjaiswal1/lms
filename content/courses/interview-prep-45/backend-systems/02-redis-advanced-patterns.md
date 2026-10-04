---
kind: lesson
id_key: interview-prep-45/day-16-backend
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Redis Advanced Patterns"
position: 2
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Redis interviews rarely stop at "it's a key-value store." Interviewers want to see you pick the right data structure for a real feature, a leaderboard, a live feed, a rate limiter, and reason about what happens when Redis restarts or dies mid-write. This lesson covers sorted sets, streams, pub/sub, and the two persistence mechanisms behind Redis's durability story.

## Sorted sets: the leaderboard data structure

A sorted set (`ZSET`) stores unique members, each with a floating-point score, always kept in score order, with fast inserts and fast range reads. That is exactly a leaderboard's access pattern: update a score, read the top N, look up one person's rank.

```python
r.zadd("leaderboard:weekly", {"user:42": 1500})        # insert or overwrite a score
r.zincrby("leaderboard:weekly", 250, "user:42")          # += 250, atomically

top10 = r.zrevrange("leaderboard:weekly", 0, 9, withscores=True)
rank = r.zrevrank("leaderboard:weekly", "user:42")       # 0-indexed, descending
score = r.zscore("leaderboard:weekly", "user:42")
```

Under the hood, a sorted set is a skip list plus a hash table. The hash table gives a fast lookup by member name; the skip list gives fast ordered range scans. That combination is why adding a score, reading a score, and reading a range are all fast. Asking "how would you build a leaderboard without Redis" is really asking whether you see this trade-off: a plain SQL table with `ORDER BY score` needs an index scan and effectively re-sorts on every write-heavy update, while a skip list keeps its order incrementally as scores change.

> **Remember:** a sorted set is a skip list plus a hash table. The hash table gives fast lookups by name; the skip list gives fast ordered ranges. That's why it fits a leaderboard so well.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-redisadvanced-zset-q1", "type": "mcq",
      "prompt": "Why does a Redis sorted set fit a leaderboard better than a SQL table with ORDER BY on a score column?",
      "options": [
        {"id":"a","text":"SQL cannot sort by a numeric column"},
        {"id":"b","text":"A sorted set's skip list keeps its order incrementally as scores change, instead of re-sorting the whole result on every read the way a plain ORDER BY effectively does under heavy writes"},
        {"id":"c","text":"Sorted sets can only hold up to 100 members"},
        {"id":"d","text":"SQL tables cannot store floating-point scores"}
      ],
      "correct": "b",
      "explanation": "The skip list structure underneath a sorted set maintains order as data changes, giving fast ranked reads without a fresh sort each time. A SQL index scan with ORDER BY has to redo more work as the underlying data changes frequently." }
] }
```

## Streams: durable, replayable logs

`XADD` appends an immutable entry to a stream. Unlike pub/sub, entries persist and can be replayed. Consumer groups let several workers split a stream's entries without duplicating work, and each entry is acknowledged only once it's actually processed, giving at-least-once delivery with retry on crash.

```python
r.xadd("events:orders", {"order_id": "501", "status": "created"})   # producer

r.xgroup_create("events:orders", "order-processors", id="0", mkstream=True)  # once

while True:
    resp = r.xreadgroup(
        "order-processors", "worker-1",
        {"events:orders": ">"}, count=10, block=5000,
    )
    for stream, entries in resp or []:
        for entry_id, fields in entries:
            process(fields)
            r.xack("events:orders", "order-processors", entry_id)   # confirm processed
```

If `worker-1` crashes after reading an entry but before acking it, that entry sits in the group's Pending Entries List. `XCLAIM`/`XAUTOCLAIM` let another worker take over stale pending entries after a timeout. This mechanism is exactly what an interviewer is checking for with "how do you not lose messages if a consumer dies."

The critical distinction from pub/sub: **pub/sub has no persistence and no replay.** A message published while a subscriber is disconnected is gone the instant it's sent, since Redis never buffers it. Use pub/sub for ephemeral broadcast, typing indicators, live cursors. Use streams when a consumer must never miss an event.

> **Remember:** streams persist and can be replayed, with a pending-entries list to recover a crashed consumer's work. Pub/sub delivers only to whoever is listening right now, and drops everything else.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-redisadvanced-streams-q1", "type": "mcq",
      "prompt": "A subscriber is disconnected for 10 seconds while messages are published. What happens to those messages under pub/sub versus a stream with a consumer group?",
      "options": [
        {"id":"a","text":"Both pub/sub and streams deliver the missed messages once the subscriber reconnects"},
        {"id":"b","text":"Pub/sub loses those messages permanently; a stream keeps them, so the consumer can read them once it reconnects and catches up"},
        {"id":"c","text":"Streams lose the messages, but pub/sub keeps them"},
        {"id":"d","text":"Neither mechanism can recover from a disconnect of any length"}
      ],
      "correct": "b",
      "explanation": "Pub/sub is fire-and-forget with no buffering: a message sent while nobody is listening is gone. A stream persists every entry, so a reconnecting consumer group member can pick up exactly where it left off." }
] }
```

## Redis persistence: RDB and AOF

Two mechanisms, often combined:

- **RDB (snapshotting)**: a periodic point-in-time dump of the whole dataset to disk. Fast to restart from and compact to back up, but any writes since the last snapshot are lost on a crash.
- **AOF (append-only file)**: every write command is logged, and replayed on restart. The default, `appendfsync everysec`, fsyncs once a second, so at most one second of writes is lost on a hard crash; `always` fsyncs every single write, durable but much slower.

The interview answer for "what is Redis persistence": RDB trades durability for fast restarts and small backups. AOF trades some write throughput for a small, bounded data-loss window. Production setups commonly run both: RDB for fast full recovery, AOF for minimizing loss between snapshots.

For failure recovery beyond a single instance, run Redis Sentinel or Redis Cluster: Sentinel monitors a primary and its replicas and promotes a replica if the original stops responding, notifying clients over pub/sub. The broader rule: never treat Redis as the source of truth for data you can't afford to lose. A cache miss should always be able to fall back to Postgres; anything Redis alone holds, session state, rate-limit counters, should tolerate being reset.

> **Remember:** RDB is fast restarts with a bigger loss window; AOF is a small loss window with more write overhead. Production systems commonly run both together.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-redisadvanced-persistence-q1", "type": "mcq",
      "prompt": "A Redis instance uses RDB snapshots only, taken every 15 minutes, and then crashes. How much data can be lost?",
      "options": [
        {"id":"a","text":"None; RDB never loses data"},
        {"id":"b","text":"Up to everything written since the last snapshot, since RDB only captures the dataset at fixed points in time"},
        {"id":"c","text":"Exactly one second of writes"},
        {"id":"d","text":"Only writes made in the final millisecond before the crash"}
      ],
      "correct": "b",
      "explanation": "RDB is a point-in-time dump. Anything written after the last snapshot exists only in memory, so a crash before the next snapshot loses that entire window, in this case up to 15 minutes' worth of writes." }
] }
```

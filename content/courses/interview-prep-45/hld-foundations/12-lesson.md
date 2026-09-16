---
kind: lesson
id_key: interview-prep-45/hld-12-coordination
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Coordination, Consensus, and Distributed Locks"
position: 12
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Every design eventually needs exactly one of something: one leader writing, one cron running, one worker holding a seat, one node owning a shard. Getting "exactly one" right in a system where nodes crash and networks lie is what consensus is for. You do not need to implement Raft in an interview — you need to know what it guarantees, when you need it, and why the naive distributed lock everyone writes is wrong.

## Leader election and what a leader is for

A **leader** (coordinator, primary, master) is the node temporarily granted the right to do something exactly once: accept writes, assign partitions, run a scheduled job, drive a rebalance.

Election requires three properties:

1. **Safety** — at most one leader at a time. Violating this is *split brain*, and it is how systems corrupt data.
2. **Liveness** — if the leader dies, a new one is elected within a bounded time.
3. **Fencing** — the old leader, when it returns, must be unable to act. This is the part naive implementations skip.

**Why fencing is mandatory.** A leader can be alive but partitioned, or paused by a long garbage-collection stop-the-world, or stalled on I/O. It still believes it is the leader. Meanwhile the cluster elected a new one. Now two nodes think they hold the lease.

The fix is a **monotonically increasing epoch (fencing token)** issued with the lease. Every write carries its token, and downstream storage **rejects any token lower than the highest it has seen**:

```
Leader A holds epoch 7, then pauses for 30 s (GC)
Cluster elects Leader B with epoch 8; B writes with token 8 → accepted
A wakes, writes with token 7 → REJECTED (7 < 8) → A steps down
```

Without the token, A's stale write silently overwrites B's. This is the single most valuable detail in the topic and almost nobody mentions it.

**Heartbeats and leases.** A leader holds a lease it must renew every few seconds. Failure detection is a timeout, and the timeout is a real trade-off: short timeouts detect failure fast but cause spurious elections during a GC pause or network blip; long timeouts are stable but extend the unavailability window. Add jitter to election timeouts so candidates do not all campaign simultaneously and split the vote.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-election-q1", "type": "mcq",
      "prompt": "A leader pauses for 30 seconds in garbage collection. The cluster elects a new leader. The old leader wakes up and writes. What prevents corruption?",
      "options": [
        {"id":"a","text":"The old leader notices it was replaced and stops on its own"},
        {"id":"b","text":"A fencing token: each leadership term has a monotonically increasing epoch, and storage rejects any write carrying an epoch lower than the highest it has seen"},
        {"id":"c","text":"The lease timeout guarantees the old leader cannot write"},
        {"id":"d","text":"The new leader locks the database"}
      ],
      "correct": "b",
      "explanation": "A paused node learns nothing while paused, so it cannot police itself, and a lease timeout is only a promise the paused node has already broken. Only a check at the resource — reject stale epochs — is safe." }
] }
```

## Consensus: Raft in the amount you need

Consensus is agreement on a value (or a sequence of values) among nodes that can crash and whose network can drop or delay messages. Every practical use is really **replicated state machine**: agree on an ordered log of commands, apply it in the same order everywhere, and every replica ends in the same state.

**Raft in five bullets** — enough to answer any HLD-level question:

1. Nodes are **follower**, **candidate**, or **leader**. Time is divided into numbered **terms** (the epoch/fencing number).
2. A follower that hears no heartbeat becomes a candidate and requests votes. A node grants one vote per term. **A candidate that wins a majority becomes leader** — majority quorum is what makes two leaders in the same term impossible.
3. All writes go to the leader, which appends to its log and replicates to followers.
4. An entry is **committed** once a majority has stored it; only then is it applied and acknowledged. Committed entries survive any minority failure.
5. A node may only vote for a candidate whose log is at least as up to date as its own, so a leader can never be elected that is missing committed entries.

**Quorum arithmetic** you should be able to state instantly:

| Nodes | Majority | Tolerates | Note |
|---|---|---|---|
| 3 | 2 | 1 failure | The common default |
| 5 | 3 | 2 failures | Better durability, slower commits |
| 7 | 4 | 3 failures | Rarely worth the latency |
| 4 | 3 | 1 failure | **No better than 3** — always use odd numbers |

**Where you meet it in real systems:** etcd and ZooKeeper (Raft/ZAB) backing Kubernetes, service discovery, and config; Kafka's controller and partition leadership (KRaft); CockroachDB, TiDB, and Spanner replicating each range with Raft/Paxos; Consul for service catalogues and locks.

**The rule for interviews: use a consensus system, do not build one.** "I'd store leadership and cluster metadata in etcd, which gives me a linearizable key-value store with leases and compare-and-swap" is exactly the right level of answer — and it also tells the interviewer you know consensus is expensive and belongs to a small control plane, not on your data path.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-raft-q1", "type": "mcq",
      "prompt": "Why is a 5-node Raft cluster preferred over a 4-node one?",
      "options": [
        {"id":"a","text":"5 nodes commit faster than 4"},
        {"id":"b","text":"Both need a majority of 3, so 4 nodes tolerate only 1 failure while 5 tolerate 2 — the fourth node adds cost and latency without adding fault tolerance"},
        {"id":"c","text":"Raft requires a prime number of nodes"},
        {"id":"d","text":"4-node clusters cannot elect a leader"}
      ],
      "correct": "b",
      "explanation": "Majority of 4 is 3 and majority of 5 is 3, so an even cluster wastes a node. This is why every production consensus cluster is 3, 5, or 7." }
] }
```

## Distributed locks — and why the naive one is broken

The requirement is mutual exclusion across processes: only one worker runs this job, only one request holds this seat.

The naive Redis lock, and its two bugs:

```
# BROKEN in two ways
if redis.setnx("lock:job", "1"):     # bug 1: no expiry → a crashed holder locks forever
    do_work()
    redis.delete("lock:job")          # bug 2: deletes ANY holder's lock, not just mine
```

The correct single-instance version:

```
token = str(uuid.uuid4())
# Atomic acquire with an expiry: NX = only if absent, EX = auto-release on crash.
if redis.set("lock:job", token, nx=True, ex=30):
    try:
        do_work()
    finally:
        # Release only if we still hold it — compare-and-delete, atomically, in Lua.
        redis.eval(
            "if redis.call('get', KEYS[1]) == ARGV[1] "
            "then return redis.call('del', KEYS[1]) else return 0 end",
            1, "lock:job", token,
        )
```

Two fixes, two reasons: the **expiry** means a crashed holder cannot deadlock the system, and the **token compare-and-delete** means a slow holder whose lock already expired cannot delete the lock a *different* worker now holds.

**The remaining, unfixable problem.** Suppose the work takes longer than the TTL — a GC pause, a slow disk, a stalled network call. The lock expires, worker B acquires it, and now **two workers are in the critical section simultaneously**. No amount of Redis cleverness removes this: the lock holder cannot know it has been evicted.

Therefore:

- **For efficiency** (don't do the same work twice; a duplicate is merely wasteful) — a Redis lock is fine.
- **For correctness** (a duplicate corrupts data or double-charges) — a lock is **not** sufficient. You need a fencing token checked at the resource, or you need to make the protected operation idempotent, or you need the resource itself to enforce the invariant (a unique constraint, a conditional `UPDATE … WHERE version = ?`).

Redlock (the multi-node Redis algorithm) is contested precisely because it does not solve this; the same pause argument applies. When you genuinely need correctness under contention, **push the invariant into a system that can enforce it**: a database unique constraint, a conditional update, or a lease from a consensus store (etcd/ZooKeeper) that issues monotonic revision numbers you can fence with.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-lock-q1", "type": "mcq",
      "prompt": "A worker holds a 30-second Redis lock, then stalls for 40 seconds. Another worker acquires the lock and starts. What is the correct conclusion?",
      "options": [
        {"id":"a","text":"Use a longer TTL — 5 minutes will make this impossible"},
        {"id":"b","text":"A TTL-based lock cannot guarantee mutual exclusion, because the holder cannot know it was evicted. For correctness, enforce the invariant at the resource — a fencing token, a unique constraint, or a conditional update — rather than relying on the lock alone"},
        {"id":"c","text":"Use Redlock across five Redis nodes, which removes the problem"},
        {"id":"d","text":"Disable the TTL so the lock never expires"}
      ],
      "correct": "b",
      "explanation": "Any TTL can be exceeded by a pause, and removing the TTL trades this failure for a permanent deadlock on crash. Redlock does not address the pause either. Locks are an optimisation; correctness must live at the resource." }
] }
```

## Coordination in practice: what to actually use

Most systems need far less coordination than they think. The cheapest coordination is **none**:

| Instead of coordinating | Do this |
|---|---|
| A lock so only one worker processes an item | **Partition** the work by key so only one worker ever owns that key |
| A lock to prevent double-processing | Make the operation **idempotent** and let duplicates be harmless |
| A global counter | Per-node counters summed at read time, or a probabilistic sketch |
| A lock around read-modify-write | A single **atomic/conditional statement** in the database |
| A distributed lock for "run this cron once" | A **lease** in etcd, or `INSERT … ON CONFLICT DO NOTHING` on a `(job, scheduled_for)` unique key |

That last row is worth remembering: a scheduled job with a unique constraint on `(job_name, run_at)` gives you exactly-once scheduling using nothing but the database you already have.

**Where a real coordination service is the right answer:**

- Cluster membership and configuration (etcd, ZooKeeper, Consul)
- Leader election for a control plane
- Shard/partition assignment and rebalancing
- Service discovery and health state
- Feature flags and dynamic configuration with change notification (watches)

**Two properties to demand of any of these**: leases with automatic expiry (so a dead client releases its claim) and compare-and-swap / revision numbers (so you can fence).

**Time**, one last warning. Do not coordinate with wall clocks. NTP skew across machines is milliseconds at best, clocks step backwards, and virtual machines pause. Use **monotonic clocks** for measuring elapsed time, **logical clocks** (Lamport, vector) for ordering events, and consensus revision numbers for fencing. Spanner's TrueTime, which needs GPS receivers and atomic clocks to bound uncertainty and then *waits out* that bound on every commit, is the honest measure of how hard globally-ordered time really is.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-practice-q1", "type": "mcq",
      "prompt": "You must guarantee a nightly job runs exactly once across 10 identical app instances. Which is the simplest sufficient mechanism?",
      "options": [
        {"id":"a","text":"A Redis lock with a 1-hour TTL"},
        {"id":"b","text":"A unique constraint on (job_name, scheduled_for) with INSERT … ON CONFLICT DO NOTHING — the one instance whose insert succeeds runs the job, using only the database you already operate"},
        {"id":"c","text":"Designate instance #1 as the runner in configuration"},
        {"id":"d","text":"Have every instance run it and deduplicate the results later"}
      ],
      "correct": "b",
      "explanation": "The database's unique index is an atomic, durable compare-and-set — exactly what \"exactly once\" needs, with no extra system. A hardcoded instance has no failover, and a TTL lock has the eviction problem plus another dependency." }
] }
```

## Key takeaways

**The recall card:**

```
Need exactly one of something? → leader election, and FENCING is not optional.
  Fencing token = monotonically increasing epoch, checked and rejected AT THE RESOURCE.
  A paused (GC'd) leader cannot police itself — only the resource can.

Raft: terms · majority vote · leader-only writes · commit on majority · up-to-date-log rule
  Cluster sizes: 3 (tolerate 1) · 5 (tolerate 2) · always ODD
  Use etcd / ZooKeeper / Consul. Do not implement consensus.

Distributed lock (Redis): SET key token NX EX ttl  +  Lua compare-and-delete on release
  Locks give EFFICIENCY, never CORRECTNESS — a pause can exceed any TTL.
  Correctness lives at the resource: unique constraint · conditional UPDATE · fencing token

Cheapest coordination is none: partition the work · make it idempotent · one atomic statement
Time: monotonic clocks for elapsed, logical clocks for order, never wall clocks for ordering.
```

- **Fencing tokens are the highest-value detail in this lesson.** "Split brain is prevented by an epoch number that storage rejects when stale" is a sentence very few candidates produce.
- **Consensus is for the control plane, not the data path** — it costs a majority round trip per decision.
- **Say the honest thing about distributed locks**: efficiency yes, correctness no, and name where the invariant is really enforced instead.
- **Design coordination away before designing it in.** Partitioning and idempotency remove more locks than any lock implementation improves.

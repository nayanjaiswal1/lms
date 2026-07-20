---
kind: lesson
id_key: interview-prep-45/day-21-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 21 — Weekly Review"
position: 21
estimated_minutes: 27
source:
    - 45-day-interview-roadmap.md
---
No new material today — this is a consolidation checkpoint. Weeks stack up fast in a 45-day plan, and the topics from Days 15-20 (transactions, Redis, distributed systems, Kafka, Celery, locks) are exactly the ones that blur together under interview pressure if you don't actively re-test yourself. Use today to close the gaps before moving on.

## How to run this review

Don't re-read the lessons passively — that produces false confidence. For each topic below, do this in order:

1. **Closed-book recall (5 min per topic).** Write down, from memory, the core mechanism and one piece of code you'd want in a whiteboard answer. If you can't produce it without looking, that's the gap — mark it.
2. **Answer the interview questions out loud**, as if a person asked them. Silently "knowing" the answer and being able to say it fluently under time pressure are different skills — this is the one interviews actually test.
3. **Re-read only the lesson sections tied to what you flagged in step 1.** Don't re-read everything; that's how a review session eats your whole day and teaches you nothing new.

## Self-check: PostgreSQL Transactions (Day 15)

- Recall the four ACID properties and which failure mode each one addresses.
- Explain, without looking, why Postgres never produces a dirty read (MVCC — readers see committed snapshots only).
- State the difference between Read Committed and Serializable, including what happens when Serializable detects a conflict.
- Recall why `select_for_update()` plus sorted lock ordering avoids deadlocks in the bank transfer example.

## Self-check: Redis Advanced Patterns (Day 16)

- Explain why a sorted set fits a leaderboard (skip list + hash table → ordered scan and O(1) lookup).
- State the one-sentence difference between streams and pub/sub (persistence and replay vs. fire-and-forget).
- Recall RDB vs AOF trade-offs and why production systems often run both.
- Rebuild the sliding-window rate limiter logic from memory: what does the sorted set store, and why prune before counting?

## Self-check: Distributed Systems Basics (Day 17)

- State CAP precisely: it's a forced choice only *during a partition*, and it's CP vs AP, not "pick two" in general.
- Explain eventual consistency and the read-your-own-writes problem it creates.
- Recall why `SET NX PX` must be one atomic command, and why lock release needs a token check.
- Explain why full jitter beats fixed exponential backoff under contention.

## Self-check: Message Queues / Kafka (Day 18)

- State what Kafka guarantees about ordering (within a partition only) and why keying by entity ID is the standard pattern.
- Explain what bounds consumer parallelism within a consumer group (partition count).
- Recall the two-layer defense against duplicate processing (idempotent producer + idempotent consumer).

## Self-check: Celery Deep Dive (Day 19)

- Explain how Celery routing simulates "priority" on a Redis broker (separate queues, not a priority field).
- State the difference between `chain` and `chord`, and why a chord needs a result backend.
- Recall the two settings that protect against a task that runs too long and a worker that crashes mid-task (`task_soft_time_limit`, `acks_late`).
- Explain why broker and result backend are conceptually separate even when both point at Redis.

## Self-check: Distributed Locks (Day 20)

- Explain the core weakness of any TTL-based lock (a paused holder can't know its lock expired before it's too late).
- State what Redlock adds over a single-instance lock (quorum across N independent instances) and what it does *not* solve by default (the fencing token problem).
- Recall when a TTL+renewal lock is "good enough" versus when you need fencing tokens or idempotent operations instead.

## Plan for Week 4

Before moving into Days 22-28 (Django ORM, FastAPI, security, WebSockets, async pipelines, testing, migrations), close out the loose ends from this week:

- **Complete remaining DSA topics** — if your DSA track has fallen behind the backend track, this is the checkpoint to catch up before system-design-heavy days compound the gap.
- **Add more system designs** — CAP, eventual consistency, and distributed locks are exactly the building blocks system-design interviews expect you to compose from memory; sketch one design (e.g. a rate limiter service, a leaderboard service) using only this week's material.
- **Start frontend deep dives** — if the roadmap's frontend track hasn't started yet, this is the natural point to interleave it, since backend Week 4 shifts toward framework-specific (Django/FastAPI) rather than infrastructure topics.

## Key takeaways

- A review day's value comes from recall-under-pressure practice, not re-reading — treat each self-check like a live interview question.
- Track every gap you find in step 1; those are your actual study list for the next pass, not the full lesson set.
- Week 4 shifts from distributed-systems infrastructure to framework-specific backend work — make sure this week's concepts (transactions, locks, queues) are solid before that context switch.

## Today's checklist

- [ ] PostgreSQL Transactions: reviewed and self-tested
- [ ] Redis Advanced: reviewed and self-tested
- [ ] Distributed Systems: reviewed and self-tested
- [ ] Kafka: reviewed and self-tested
- [ ] Celery Deep Dive: reviewed and self-tested
- [ ] Distributed Locks: reviewed and self-tested
- [ ] Complete remaining DSA topics
- [ ] Add more system designs
- [ ] Start frontend deep dives

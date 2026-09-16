---
kind: lesson
id_key: interview-prep-45/hld-15-cheatsheet
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "HLD Cheat Sheet and Recall Drill"
position: 15
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
---

Fourteen lessons of building blocks are useless if you cannot retrieve them under pressure. This lesson is the retrieval layer: the decision trees you run at the whiteboard, the numbers you should be able to say without thinking, the phrases that earn points, and a self-test you can repeat weekly until it is boring.

Use it three ways: read it once now, re-read the recall cards the night before an interview, and run the drill at the end of it every week until every answer comes back in under five seconds.

## The one-page map

Everything in this section, arranged as the order you use it in.

```
FRAMEWORK (Lesson 1)      Requirements → Estimation → API+Schema → HLD → Deep dive → Close
                          45 min: 5 / 5 / 5 / 10 / 15 / 5

ESTIMATION (2)            sec/day ≈ 100k · 1M/day ≈ 10 QPS · peak = 2–3× avg
                          storage/yr = bytes/day × 400 × replicas
                          → conclusion: which subsystem is actually hard?

TRAFFIC IN  (3,4,5)       DNS → CDN → LB → Gateway → stateless services
                          protocol: REST public · gRPC internal · SSE push · WS duplex
                          API: /v1, cursor pages, idempotency keys, 429 + Retry-After
                          LB: L4 vs L7 · least-connections · readiness ≠ liveness · draining

DATA        (6,7,8,9)     cache-aside + delete-on-write + TTL jitter
                          store chosen from the ACCESS PATTERN · index = left prefix
                          B-tree (reads) vs LSM (writes)
                          replication scales READS · partitioning scales WRITES
                          partition key: cardinality · even access · query alignment
                          CAP per operation · PACELC everyday · W+R>N

ASYNC       (10,11,12)    response-independent work → queue
                          queue (delete on ack) vs log (retained, replayable)
                          at-least-once + idempotent consumer · DLQ · consumer lag
                          outbox for dual writes · saga for cross-service workflows
                          exactly one of something → leader election + FENCING TOKEN

OPERATE     (13,14)       timeouts · backoff+jitter · circuit breaker · bulkhead · shed
                          token bucket rate limiting · SLI/SLO/error budget
                          RED + USE · p99 not average · trace id everywhere
                          TLS + authZ at the data layer · expand-migrate-contract
```

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-map-q1", "type": "mcq",
      "prompt": "In the 45-minute budget, which two steps together get the most time, and why?",
      "options": [
        {"id":"a","text":"Requirements and estimation, because they determine everything else"},
        {"id":"b","text":"High-level design (10 min) and deep dive (15 min) — the deep dive is where technical depth and trade-off reasoning, the two highest-weight scorecard rows, are actually demonstrated"},
        {"id":"c","text":"API design and data modelling, because they are the concrete artefacts"},
        {"id":"d","text":"The close, because last impressions matter most"}
      ],
      "correct": "b",
      "explanation": "Requirements and estimation are cheap and mandatory but capped at ~5 minutes each. Depth is demonstrated in the deep dive, which is why over-running the early steps is so costly." }
] }
```

## Decision trees

Run these top-down at the whiteboard. Each one converts a question into an answer plus its cost.

**Which datastore?**
```
Relationships + ad-hoc queries + invariants ......... relational (Postgres)
Known key, huge write rate, no joins ............... wide-column (Cassandra/DynamoDB)
Whole documents, flexible schema ................... document (Mongo)
Sub-ms, ephemeral, counters/sessions/queues ........ Redis
Text relevance, faceting ........................... search index (Elasticsearch)
High-rate timestamped metrics ...................... time-series (+ downsampling)
Traversal of relationships ......................... graph
Large blobs ........................................ object store + metadata row
Scans over billions of rows ........................ columnar warehouse
Unsure ............................................. Postgres, and say why you'd move
```

**Reads are slow.**
```
Is the query indexed?          → composite index, equality cols first, range col last
Still slow?                    → covering index / denormalise to avoid the join
Volume too high for one node?  → read replicas (mind replication lag)
Same data re-read constantly?  → cache-aside + TTL + jitter (invalidate on write)
Expensive to compute per read? → precompute / materialise on write
Dataset too large for a node?  → partition, aligned with the dominant query
```

**Writes are slow.**
```
Are writes fsync-bound?        → batch them; group commits
Too many indexes?              → drop the ones no query uses
One node saturated?            → shard on a high-cardinality, evenly-accessed key
Bursty?                        → queue + workers (load levelling)
Append-heavy at huge volume?   → LSM-based store, or a log
Contention on one row?         → atomic UPDATE, or shard the counter, or a ledger
```

**Client needs updates.**
```
Rare updates, staleness fine ....... polling
Server → client only ............... SSE
Both directions .................... WebSocket (+ sticky routing + pub/sub backbone)
Loss-tolerant media ................ UDP / WebRTC
```

**Two things must change together.**
```
Same database ...................... local transaction (and consider keeping it that way)
DB write + event publish ........... transactional outbox / CDC
Multi-service workflow ............. saga (orchestrated if 4+ steps) + compensations
Reserve, then confirm/cancel ....... TCC / reservation with a TTL
Must be atomic, few participants ... 2PC (blocks on coordinator failure)
Replicated state, never diverges ... consensus (etcd/Raft)
Always ............................. idempotent steps + a reconciliation job
```

**Something must happen exactly once.**
```
Scheduled job across N instances ... unique constraint on (job, run_at) — cheapest correct
One owner per key ................. partition the work; no lock needed
Duplicate is merely wasteful ...... Redis lock: SET NX EX + Lua compare-and-delete
Duplicate corrupts data ........... fencing token / unique constraint / conditional UPDATE
Cluster leadership ................ lease in etcd/ZooKeeper + epoch checked at the resource
```

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-trees-q1", "type": "mcq",
      "prompt": "Reads are slow, the query is already served by a good composite index, and one node's CPU is saturated by read volume. What is the next move?",
      "options": [
        {"id":"a","text":"Shard the table immediately"},
        {"id":"b","text":"Add read replicas (accepting replication lag, with read-your-own-writes routed to the leader) and/or cache the hot results — reads are what replication and caching are for"},
        {"id":"c","text":"Switch to an LSM-tree storage engine"},
        {"id":"d","text":"Increase the isolation level"}
      ],
      "correct": "b",
      "explanation": "Read volume on a correctly-indexed query is the textbook case for replicas and caching. Sharding is for write and storage limits and costs you joins and transactions; changing the storage engine optimises writes, not reads." }
] }
```

## Numbers and phrases to have on instant recall

**Numbers.**

```
Time      : memory 100 ns · SSD read 100 µs · DC round trip 500 µs
            cross-country 70 ms · cross-Atlantic 150 ms
Throughput: Postgres ~10k QPS/node · Redis ~100k+ ops/sec · app server ~10k req/sec
            Kafka broker ~100k+ msg/sec · 10 Gbps NIC ≈ 1.25 GB/s
Scale     : sec/day ≈ 100k · 1M/day ≈ 10 QPS · 1B/day ≈ 10k QPS · peak = 2–3×
Sizes     : UUID 16 B · post 300 B · user row 1 KB · API response 1–10 KB
            thumbnail 50 KB · photo 2 MB · 1080p video 50 MB/min
Uptime    : 99.9% = 43 min/month · 99.99% = 4.3 min/month
Quorum    : W + R > N · clusters of 3, 5, 7 (odd) · majority tolerates ⌊(n−1)/2⌋ failures
```

**Phrases that earn points** — these are worth rehearsing verbatim, because under pressure you will produce what you have said before:

1. "Before I design anything — what scale, and is this read-heavy or write-heavy?"
2. "I'll scope to X and Y, and treat Z as out of scope unless you'd like it."
3. "That's 100:1 reads to writes, so the interesting problem is the read path."
4. "Anything the user's response doesn't depend on goes behind a queue."
5. "I'm choosing X; the cost is Y, and I'd mitigate it with Z."
6. "This is CP for the payment and AP for the product page — the choice is per operation."
7. "Writes to the database and publishes to the broker aren't atomic, so I'd use a transactional outbox."
8. "At-least-once delivery plus an idempotent consumer — effectively once."
9. "Replication lag breaks read-your-own-writes, so I'd route that user to the leader for a few seconds."
10. "Every real system has a hot key; here it's the celebrity account, and I'd handle it with a separate read path."
11. "Four synchronous dependencies at 99.9% each caps me at about 99.6% — I'd move two of them off the critical path."
12. "I'd alert on the checkout SLO, propagate a trace id into every log line, and add a daily reconciliation job."

**Anti-patterns that lose points**, so you can hear yourself doing them: drawing boxes before asking requirements; naming technologies without justifying them; reaching for microservices, Kafka, or sharding at 200 QPS; claiming exactly-once delivery; presenting one design with no costs; going silent while thinking; and running out of time because requirements took fifteen minutes.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-phrases-q1", "type": "mcq",
      "prompt": "Which statement would an interviewer most likely mark as an error rather than a strength?",
      "options": [
        {"id":"a","text":"\"We'll use Kafka's transactions to get exactly-once delivery end to end, so consumers don't need to handle duplicates.\""},
        {"id":"b","text":"\"At-least-once delivery with an idempotent consumer, deduplicated on a unique message id.\""},
        {"id":"c","text":"\"This is CP for the payment path and AP for the catalogue.\""},
        {"id":"d","text":"\"I'd start with one Postgres primary and a replica; here's the load at which I'd shard.\""}
      ],
      "correct": "a",
      "explanation": "Kafka's transactions give exactly-once semantics for writes back into Kafka, not for external side effects like charging a card or sending an email. Claiming end-to-end exactly-once — and skipping consumer idempotency because of it — is a recognisable error." }
] }
```

## The weekly recall drill

Answer out loud, from memory, then check yourself against the lesson named in brackets. Target: every answer inside five seconds, no notes. Repeat weekly — the point is retrieval practice, not re-reading.

**Round 1 — framework and numbers**
1. The six steps of a design interview and the minutes for each. [1]
2. Seconds in a day, and what 1M/day and 1B/day come to in QPS. [2]
3. Memory vs SSD vs cross-Atlantic latency, in orders of magnitude. [2]
4. The four rows of the interviewer's scorecard. [1]

**Round 2 — the request path**
5. When to use SSE instead of WebSocket, and what WebSocket costs you architecturally. [3]
6. Why cursor pagination beats offset, and why the cursor needs a tie-breaker. [4]
7. What an idempotency key protects against, and which database feature makes it correct. [4]
8. L4 vs L7 — one thing only L7 can do. [5]
9. Why a health check must not test the database. [5]

**Round 3 — data**
10. Cache-aside on write: update the cached value or delete it? Why? [6]
11. Name the three cache failure modes and one fix each. [6]
12. An index on `(a, b, c)` — which queries does it serve? [7]
13. B-tree vs LSM in one sentence. [7]
14. Which anomaly does Read Committed still allow, and the three ways to prevent it. [7]
15. Replication scales what? Partitioning scales what? [8]
16. The three tests for a partition key. [8]
17. Why `hash(key) % N` is a trap. [8]
18. What P in CAP really means, and why "CA" isn't a thing. [9]
19. State PACELC, and give the everyday half. [9]
20. Quorum rule for a read seeing the latest write. [9]

**Round 4 — async and coordination**
21. Queue vs log — the two questions that decide it. [10]
22. Why exactly-once delivery does not exist, and what you say instead. [10]
23. What the outbox pattern fixes, and how. [10]
24. Saga: what replaces rollback, and the three obligations it puts on you. [11]
25. 2PC: what happens when the coordinator dies after the votes? [11]
26. What a fencing token is and why a lease alone is insufficient. [12]
27. Why a Redis lock cannot guarantee correctness. [12]
28. The cheapest way to run a nightly job exactly once across 10 instances. [12]

**Round 5 — operations**
29. Availability of four synchronous 99.9% dependencies, and the fix. [13]
30. Four rules for retries. [13]
31. Circuit breaker states and the transitions. [13]
32. Token bucket vs fixed window — the two advantages. [13]
33. What a metastable failure is and how you escape one. [13]
34. RED and USE — what each is for. [14]
35. The JWT trade-off and its mitigation. [14]
36. Expand–migrate–contract: why all three steps. [14]

**Round 6 — apply it.** Pick a system you use daily (a food delivery app, a bank app, a music service) and give yourself six minutes: requirements, estimate, one API, one data model, one diagram, one bottleneck with a fix and its cost. Six minutes, out loud, no notes. Do this once a week with a different system — it is the closest thing to the real interview you can practise alone, and the **System Design** section's 28 case studies are the long-form version of the same exercise.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-drill-q1", "type": "mcq",
      "prompt": "What makes the weekly drill effective as study, compared with re-reading the lessons?",
      "options": [
        {"id":"a","text":"It covers more material in less time"},
        {"id":"b","text":"It is retrieval practice — recalling an answer from memory under a time limit strengthens recall far more than re-reading, and it exposes exactly which items you only *recognise* rather than know"},
        {"id":"c","text":"It replaces the need to understand the underlying concepts"},
        {"id":"d","text":"It guarantees the same questions will be asked in the interview"}
      ],
      "correct": "b",
      "explanation": "Re-reading produces familiarity, which feels like knowledge and collapses under interview pressure. Timed self-testing is the mechanism that makes recall reliable, and it identifies your weak items for free." }
] }
```

## Key takeaways

- **Procedure beats knowledge under pressure.** The six-step framework and the 45-minute budget are the two things to memorise absolutely; everything else you can re-derive from the decision trees.
- **Every answer is a choice plus its cost.** If a sentence doesn't contain a trade-off, it probably didn't earn anything.
- **The decision trees are the retrieval index** for the fourteen lessons behind them. Learn the branches; the details come back once you're on the right branch.
- **Practise out loud, on a clock, weekly.** Recall under time pressure is a separate skill from understanding, and it is the one the interview actually tests.
- **Next**: the **System Design** section applies all of this to 28 real questions, and the **Low-Level Design** section does the same job one level down, at the class and object level.

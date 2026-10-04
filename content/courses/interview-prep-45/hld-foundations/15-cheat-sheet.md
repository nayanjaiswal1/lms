---
kind: lesson
id_key: interview-prep-45/hld-15-cheatsheet
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "System Design Cheat Sheet"
position: 15
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Fourteen lessons of building blocks are useless if you can't pull them out of your memory under pressure. Picture a firefighter: knowing all the theory about how fire spreads doesn't help if they can't find the right hose in the dark in three seconds. This lesson is exactly that kind of muscle memory: the decision trees you run through at the whiteboard, the numbers you should be able to say without thinking, the phrases that earn real points, the reusable building blocks every design reaches for, and a self-test you can repeat until it gets boring.

Use this lesson three ways: read it once now, reread the recall cards the night before an interview, and run the drill at the very end of it, over and over, until every single answer comes back to you in under five seconds.

## The one-page map

Here's everything in this section, laid out in the order you'll actually use it during a real interview.

```
FRAMEWORK      Requirements → Estimation → API+Schema → HLD → Deep dive → Close
               45 min: 5 / 5 / 5 / 10 / 15 / 5

ESTIMATION     sec/day ≈ 100k · 1M/day ≈ 10 QPS · peak = 2–3× avg
               storage/yr = bytes/day × 400 × replicas
               → conclusion: which subsystem is actually hard?

TRAFFIC IN     DNS → CDN → LB → Gateway → stateless services
               protocol: REST public · gRPC internal · SSE push · WS duplex
               API: /v1, cursor pages, idempotency keys, 429 + Retry-After
               LB: L4 vs L7 · least-connections · readiness ≠ liveness · draining

DATA           cache-aside + delete-on-write + TTL jitter
               store chosen from the ACCESS PATTERN · index = left prefix
               B-tree (reads) vs LSM (writes)
               replication scales READS · partitioning scales WRITES
               partition key: cardinality · even access · query alignment
               CAP per operation · PACELC everyday · W+R>N

ASYNC          response-independent work → queue
               queue (delete on ack) vs log (retained, replayable)
               at-least-once + idempotent consumer · DLQ · consumer lag
               outbox for dual writes · saga for cross-service workflows
               exactly one of something → leader election + FENCING TOKEN

OPERATE        timeouts · backoff+jitter · circuit breaker · bulkhead · shed
               token bucket rate limiting · SLI/SLO/error budget
               RED + USE · p99 not average · trace id everywhere
               TLS + authZ at the data layer · expand-migrate-contract
```

> **Remember:** the map has five stops in order: get the numbers, get the traffic in, get the data right, make the slow parts async, then keep it alive under failure.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-map-q1", "type": "mcq",
      "prompt": "In the 45-minute budget, which two steps together get the most time, and why?",
      "options": [
        {"id":"a","text":"Requirements and estimation, because they determine everything else"},
        {"id":"b","text":"High-level design (10 minutes) and the deep dive (15 minutes), because the deep dive is where technical depth and trade-off reasoning, the two highest-weight rows on the scorecard, are actually demonstrated"},
        {"id":"c","text":"API design and data modelling, because they produce the concrete artefacts"},
        {"id":"d","text":"The close, because last impressions matter most"}
      ],
      "correct": "b",
      "explanation": "Requirements and estimation are cheap and mandatory, but each is capped at around 5 minutes. Real depth only shows up during the deep dive, which is exactly why running over time on the earlier steps costs you so much." }
] }
```

## Decision trees

Run through these from top to bottom, right at the whiteboard. Each one turns a question into an answer, plus the cost that answer carries with it.

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

> **Remember:** each tree converts a symptom into an answer plus its cost. If your answer has no cost attached, you skipped a branch.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-trees-q1", "type": "mcq",
      "prompt": "Reads are slow, the query is already served by a good composite index, and one server's CPU is saturated purely by read volume. What is the next move?",
      "options": [
        {"id":"a","text":"Shard the table immediately"},
        {"id":"b","text":"Add read replicas, accepting some replication lag and routing that one user's own writes back to the leader for a moment, and/or cache the hot results; reads are exactly what replication and caching exist for"},
        {"id":"c","text":"Switch the underlying storage engine to an LSM-tree"},
        {"id":"d","text":"Raise the isolation level"}
      ],
      "correct": "b",
      "explanation": "High read volume on a query that's already correctly indexed is the textbook case for read replicas and caching. Sharding solves write and storage limits, and costs you joins and transactions in return; switching the storage engine speeds up writes, not reads." }
] }
```

## Reusable building blocks

Nearly every design you draw reaches for the exact same small toolbox. Knowing what each tool actually solves, and what it costs you in return, is what turns a plain box on a diagram into a decision you can actually defend.

| Block | Solves | Watch out for |
|---|---|---|
| Load balancer (L4/L7) | Spreads traffic across servers, checks health | Sticky sessions break horizontal scaling |
| CDN | Slow-loading static files for far-away users | Cache invalidation after a deploy |
| Cache (Redis) | Slow reads, database overload | Stampede on expiry, stale data |
| Message queue (Kafka/SQS) | Decoupling, async work, traffic spikes | Ordering guarantees, at-least-once delivery |
| Database read replicas | Read scaling | Replication lag means stale reads |
| Sharding | Write scaling, dataset too big for one node | Cross-shard queries and joins get expensive |
| Rate limiter | Abuse protection, fairness between clients | Token bucket vs. sliding window trade-offs |
| Consistent hashing | Even key distribution across nodes that change | Hot keys still need their own handling |
| Object storage (S3-like) | Large files and media | Not a substitute for a database's own index |

**A checklist for redesigning any system from scratch.** Run any design prompt through these six steps, in order. First, requirements: 3 to 5 core features, plus the scale numbers, meaning daily users, requests per second, the ratio of reads to writes, and a latency target. Second, a capacity estimate: rough storage and bandwidth maths. Third, API design: 3 to 5 endpoints with their request and response shapes. Fourth, the high-level architecture: boxes for the client, load balancer, service, cache, database, and queue, and how data actually flows between them. Fifth, a deep dive: pick the ONE hardest part and go deep specifically on that. Sixth, bottlenecks and trade-offs: where does this design break at 10 times the scale, and what did you give up to get here.

> **Remember:** each building block solves one problem and creates a new watch-out. Naming both halves is what separates "I'd add a cache" from a real answer.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-blocks-q1", "type": "mcq",
      "prompt": "A design needs to protect against abusive clients sending far too many requests per second. Which building block fits, and what is its main watch-out?",
      "options": [
        {"id": "a", "text": "A rate limiter; the watch-out is choosing between algorithms like token bucket and sliding window, which trade off burst tolerance against precision"},
        {"id": "b", "text": "A CDN; the watch-out is cache invalidation after a deploy"},
        {"id": "c", "text": "Sharding; the watch-out is expensive cross-shard joins"},
        {"id": "d", "text": "Object storage; the watch-out is that it isn't a substitute for a database index"}
      ],
      "correct": "a",
      "explanation": "A rate limiter is the block built specifically for abuse protection and fairness between clients. Every block in the table pairs a problem it solves with a specific cost, and matching the wrong pair together is a common mistake to make under pressure." }
] }
```

## Numbers and phrases to have on instant recall

**Numbers worth memorising:**

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

**Phrases that earn real points.** These are worth practising word for word, because under real pressure you tend to say whatever you've already rehearsed saying, not whatever you're trying to think up fresh in the moment:

1. "Before I design anything, what scale are we targeting, and is this read-heavy or write-heavy?"
2. "I'll scope to X and Y, and treat Z as out of scope unless you'd like it covered."
3. "That's 100 reads for every write, so the interesting problem is the read path."
4. "Anything the user's response doesn't depend on goes behind a queue."
5. "I'm choosing X. The cost is Y, and I'd soften it with Z."
6. "This is CP for the payment and AP for the product page; the choice is per operation."
7. "Writing to the database and publishing to the broker aren't one atomic action, so I'd use a transactional outbox."
8. "At-least-once delivery plus an idempotent consumer gives me effectively-once behaviour."
9. "Replication lag breaks seeing your own writes, so I'd route that user to the leader for a few seconds."
10. "Every real system has a hot key; here it's the celebrity account, and I'd handle it with a separate read path."
11. "Four synchronous dependencies at 99.9% each caps me at about 99.6%; I'd move two of them off the critical path."
12. "I'd alert on the checkout SLO, propagate a trace id into every log line, and add a daily reconciliation job."

**Anti-patterns that lose points**, so you can catch yourself doing them: drawing boxes before asking any requirements; naming technologies without justifying why; reaching for many small services, a message broker, or sharding at only 200 requests a second; claiming exactly-once delivery is actually achievable; presenting one design with no stated costs at all; going quiet while you think instead of narrating out loud; and running out of time because requirements alone took fifteen minutes.

> **Remember:** rehearse the twelve phrases out loud until they come out naturally. Under pressure you say what you've already practiced saying, not what you newly think of.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-phrases-q1", "type": "mcq",
      "prompt": "Which statement would an interviewer most likely mark as a mistake rather than a strength?",
      "options": [
        {"id":"a","text":"\"We'll use Kafka's transactions to get exactly-once delivery end to end, so consumers don't need to handle duplicates.\""},
        {"id":"b","text":"\"At-least-once delivery with an idempotent consumer, deduplicated on a unique message id.\""},
        {"id":"c","text":"\"This is CP for the payment path and AP for the catalogue.\""},
        {"id":"d","text":"\"I'd start with one Postgres primary and a replica; here's the load at which I'd shard.\""}
      ],
      "correct": "a",
      "explanation": "Kafka's transactions only give exactly-once behaviour for writes going back into Kafka itself, not for outside effects like charging a card or sending an email. Claiming true end-to-end exactly-once, and skipping consumer-side deduplication because of it, is a recognisable mistake." }
] }
```

## The recall drill

Answer each question out loud, from memory, then check yourself against the lesson named in brackets. Aim for every answer to come back to you inside five seconds, with no notes. Repeat this drill often; the whole point is practising recall, not simply rereading the material again.

**Round 1, the framework and the numbers**
1. The six steps of a design interview, and the minutes given to each. [The System Design Interview Framework]
2. Seconds in a day, and what 1 million a day and 1 billion a day come to in requests per second. [Back-of-the-Envelope Estimation]
3. Memory versus SSD versus a cross-Atlantic round trip, in orders of magnitude. [Back-of-the-Envelope Estimation]
4. The four rows of the interviewer's scorecard. [The System Design Interview Framework]

**Round 2, the request path**
5. When to use SSE instead of WebSocket, and what WebSocket costs you architecturally. [Networking and Protocols for Design]
6. Why cursor pagination beats page numbers, and why the cursor needs a tie-breaker. [API Design and Idempotency]
7. What an idempotency key protects against, and which database feature makes it actually correct. [API Design and Idempotency]
8. L4 versus L7: one thing only L7 can do. [Load Balancing, Proxies, and Scaling Out]
9. Why a health check must not test the database. [Load Balancing, Proxies, and Scaling Out]

**Round 3, data**
10. On a write, do you update the cached value or delete it? Why? [Caching and CDNs]
11. Name the three cache failure modes and one fix for each. [Caching and CDNs]
12. An index on columns `(a, b, c)`: which queries does it actually help? [Choosing a Database]
13. B-tree versus LSM-tree, in one sentence. [Choosing a Database]
14. Which problem does Read Committed still allow, and the three ways to prevent it. [Choosing a Database]
15. What does replication scale? What does partitioning scale? [Replication, Partitioning, and Sharding]
16. The three tests for a good partition key. [Replication, Partitioning, and Sharding]
17. Why `hash(key) % N` is a trap, and what fixes it. [Replication, Partitioning, and Sharding]
18. What the "P" in CAP actually means, and why "CA" isn't a real thing. [CAP, PACELC, and Levels of Consistency]
19. State PACELC, and give the everyday half of it. [CAP, PACELC, and Levels of Consistency]
20. The quorum rule for a read to see the latest write. [CAP, PACELC, and Levels of Consistency]

**Round 4, async work and coordination**
21. Queue versus log: the two questions that decide between them. [Messaging, Queues, and Event-Driven Architecture]
22. Why exactly-once delivery doesn't really exist, and what you say instead. [Messaging, Queues, and Event-Driven Architecture]
23. What the outbox pattern fixes, and how. [Messaging, Queues, and Event-Driven Architecture]
24. A saga: what replaces rollback, and the three obligations it places on you. [Distributed Transactions and Data Integrity]
25. Two-phase commit: what happens if the coordinator dies right after collecting the votes? [Distributed Transactions and Data Integrity]
26. What a fencing token is, and why a lease by itself isn't enough. [Coordination, Consensus, and Distributed Locks]
27. Why a Redis lock alone cannot guarantee correctness. [Coordination, Consensus, and Distributed Locks]
28. The cheapest way to run a nightly job exactly once, across 10 separate instances. [Coordination, Consensus, and Distributed Locks]

**Round 5, operations**
29. The availability of four synchronous 99.9% dependencies chained together, and the fix. [Reliability, Resilience, and Rate Limiting]
30. Four rules for handling retries safely. [Reliability, Resilience, and Rate Limiting]
31. The circuit breaker's states, and the transitions between them. [Reliability, Resilience, and Rate Limiting]
32. Token bucket versus fixed window: the two advantages of the token bucket. [Reliability, Resilience, and Rate Limiting]
33. What a metastable failure is, and how you escape one. [Reliability, Resilience, and Rate Limiting]
34. RED and USE: what each one is actually for. [Observability, Security, and Cost]
35. The JWT trade-off, and how it's usually softened. [Observability, Security, and Cost]
36. Expand, migrate, contract: why all three steps are needed. [Observability, Security, and Cost]

**Round 6, apply it.** Pick a system you use every day, like a food delivery app, a banking app, or a music streaming service, and give yourself six minutes: state the requirements, do the estimate, write one API endpoint, sketch one data model, draw one diagram, and name one bottleneck along with its fix and its cost. Six minutes, entirely out loud, no notes. Repeat this with a different system next time; it's the closest thing to a real interview you can practise entirely on your own.

> **Remember:** rereading feels like learning but doesn't actually test recall. Answering out loud from memory, on a clock, is what actually sticks.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-15-drill-q1", "type": "mcq",
      "prompt": "What makes this recall drill effective as a way to study, compared with simply rereading the lessons again?",
      "options": [
        {"id":"a","text":"It covers more material in less time overall"},
        {"id":"b","text":"It is retrieval practice: pulling an answer out of memory under a time limit strengthens your recall far more than rereading does, and it reveals exactly which items you only *recognise* rather than actually know"},
        {"id":"c","text":"It removes the need to understand the underlying concepts at all"},
        {"id":"d","text":"It guarantees the exact same questions will be asked in a real interview"}
      ],
      "correct": "b",
      "explanation": "Rereading builds familiarity, which feels a lot like real knowledge but tends to fall apart under actual interview pressure. Timed self-testing is the mechanism that actually makes your recall reliable, and as a side effect, it shows you exactly which items you're weak on." }
] }
```

## Quick recap

The two things worth memorising absolutely are the six-step framework and the 45-minute budget. Everything else, you can work back out from the decision trees once you're standing on the right branch. If a sentence you say in an interview doesn't include a real trade-off, it probably didn't earn you anything.

---
kind: lesson
id_key: interview-prep-45/hld-02-estimation
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Back-of-the-Envelope Estimation"
position: 2
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Estimation is the step candidates most want to skip and the step that most changes the design. Its purpose is never precision — nobody checks your arithmetic. Its purpose is to answer one question in three minutes: **is this a one-machine problem, a one-rack problem, or a thousand-machine problem?** The answer decides everything you draw afterwards.

This lesson gives you a fixed set of numbers to memorise, four arithmetic shortcuts, and three worked estimates you can pattern-match against.

## The numbers worth memorising

Two tables. Learn them once; they cover the vast majority of estimates you will ever do at a whiteboard.

**Latency — the "orders of magnitude" ladder.** Round numbers, deliberately:

| Operation | Time | Rule of thumb |
|---|---|---|
| L1 cache reference | 1 ns | — |
| Main memory reference | 100 ns | RAM is ~100× L1 |
| Read 1 MB from memory | 10 µs | — |
| SSD random read | 100 µs | SSD is ~1,000× RAM |
| Read 1 MB from SSD | 200 µs | — |
| Round trip within a datacenter | 500 µs | |
| Disk (HDD) seek | 10 ms | HDD is ~100× SSD |
| Round trip US East ↔ US West | 70 ms | |
| Round trip US ↔ Europe | 150 ms | Light in fibre: ~200 km/ms |

The three ratios that matter more than the absolute numbers: **memory ≈ 100× faster than SSD, SSD ≈ 100× faster than spinning disk, and a cross-continent round trip costs more than 100,000 memory reads.** That last one is why you cache, why you batch, and why chatty microservice calls across regions are fatal.

**Capacity per commodity machine** — what one node can do before you need two:

| Resource | Realistic single-node number |
|---|---|
| Redis / in-memory cache | ~100k–1M ops/sec, 10s of GB of RAM |
| PostgreSQL (well-indexed, cached working set) | ~5k–10k simple queries/sec |
| Application server (Go/Java, simple JSON) | ~5k–20k req/sec |
| Application server (Python/Ruby, per process) | ~500–2k req/sec |
| Kafka broker | ~100k–1M messages/sec |
| Network interface | 10 Gbps ≈ 1.25 GB/sec |

Round aggressively. If someone quotes "8,000 QPS per Postgres node" and you said 10,000, nothing about your design changes — that is the point.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-numbers-q1", "type": "mcq",
      "prompt": "Roughly how much slower is a US↔Europe round trip (150 ms) than a main-memory read (100 ns)?",
      "options": [
        {"id":"a","text":"About 1,000×"},
        {"id":"b","text":"About 100,000×"},
        {"id":"c","text":"About 1,500,000×"},
        {"id":"d","text":"About 150×"}
      ],
      "correct": "c",
      "explanation": "150 ms = 150,000,000 ns; divided by 100 ns ≈ 1.5 million. This gap is why one cross-region call can dominate an entire request budget, and why you replicate data close to users rather than calling home." }
] }
```

## Four arithmetic shortcuts

These four turn estimation from arithmetic into recall.

**1. Powers of two → data sizes.**

| Power | Value | Name |
|---|---|---|
| 2^10 | ~1 thousand | KB |
| 2^20 | ~1 million | MB |
| 2^30 | ~1 billion | GB |
| 2^40 | ~1 trillion | TB |

**2. Seconds in a day ≈ 100,000.** (Actually 86,400 — round up.) So **1 million events/day ≈ 10/sec**, and **1 billion/day ≈ 10,000/sec**. Almost every QPS estimate you do is a variation on those two anchors.

**3. Peak = 2–3× average.** Real traffic is diurnal: a quiet night and a busy evening. Design for peak, size cost for average. If a launch or a flash sale is in scope, use 10×.

**4. Typical payload sizes** — so you can go from QPS to bytes:

| Thing | Size |
|---|---|
| UUID | 16 bytes |
| Timestamp | 8 bytes |
| Tweet / short text post | ~300 bytes |
| User record | ~1 KB |
| JSON API response | ~1–10 KB |
| Thumbnail image | ~50 KB |
| Full photo | ~2 MB |
| 1 minute of 1080p video | ~50 MB |

One derived habit: **storage per year ≈ bytes/day × 400** (365 rounded up), and if you keep replicas add a ×3.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-shortcuts-q1", "type": "mcq",
      "prompt": "A service handles 500 million requests per day. Roughly what is its average QPS, and what would you design for at peak?",
      "options": [
        {"id":"a","text":"~500 QPS average, ~1,000 peak"},
        {"id":"b","text":"~5,000 QPS average, ~10,000–15,000 peak"},
        {"id":"c","text":"~50,000 QPS average, ~150,000 peak"},
        {"id":"d","text":"~500,000 QPS average, ~1M peak"}
      ],
      "correct": "b",
      "explanation": "1 billion/day ≈ 10,000/sec, so 500 million/day ≈ 5,000/sec average. Multiply by 2–3 for peak → design for roughly 10,000–15,000 QPS." }
] }
```

## The estimation template

Always run the same five lines, in this order. Say each aloud; each one is a chance to earn a point.

```
1. Users        : DAU, and actions per user per day
2. QPS          : (DAU × actions) ÷ 100,000 sec  → then ×3 for peak
3. Read : Write : the single most design-relevant ratio
4. Storage      : bytes per record × records/day × 400 days/yr × years × replication
5. Bandwidth    : bytes per response × peak QPS
```

Then — and this is the part candidates forget — **state the conclusion**. An estimate with no conclusion earns nothing:

- "3,500 peak QPS is a handful of app servers, not a thousand." (You are not building Google.)
- "100:1 read:write, so caching and replicas carry this design."
- "50 TB/year of video means object storage plus a CDN, and the DB only holds metadata."
- "One shard tops out around 10k QPS, so at 40k I need at least 4–8 shards plus headroom."

There is a fifth conclusion worth practising because it is the bravest and most senior: **"these numbers are small — a single Postgres instance with a read replica handles this, and I'd start there."** Reaching for a distributed system a problem does not need is a real and commonly-marked negative.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-template-q1", "type": "mcq",
      "prompt": "Your estimate comes out at 200 QPS and 40 GB of total data. What is the strongest thing to say next?",
      "options": [
        {"id":"a","text":"\"I'll shard the database across 10 nodes for safety.\""},
        {"id":"b","text":"\"This fits comfortably on one primary database with a replica for reads and failover — I'd start simple and note where it would need to change at 50× this load.\""},
        {"id":"c","text":"\"I'll add Kafka between every service to decouple them.\""},
        {"id":"d","text":"\"Let's assume 100× more traffic so the design is future-proof.\""}
      ],
      "correct": "b",
      "explanation": "Matching the solution to the measured scale — and naming the load at which the design would change — is the senior answer. Pre-emptive sharding and unjustified Kafka are marked as over-engineering." }
] }
```

## Three worked estimates

**A. Read-heavy social feed (10M DAU).**

```
Reads : 10M × 10 timeline views       = 100M/day  → 1,000 QPS avg → 3,000 peak
Writes: 10M × 0.1 posts               = 1M/day    → 10 QPS avg    → 30 peak
Ratio : 100:1 read-heavy
Storage: 1M posts × 300 B             = 300 MB/day → ~120 GB/yr text
         (+ media: 10% of posts × 2 MB = 200 GB/day → 80 TB/yr → object store + CDN)
Bandwidth: 5 KB response × 3,000 QPS  = 15 MB/s   → trivial for text, huge for media
```
**Conclusion:** text is a small problem; media is the storage/bandwidth problem. Design the read path with a cache; put blobs in S3 behind a CDN and keep only metadata in the DB.

**B. Write-heavy metrics ingestion (100k servers, 1 metric/sec each).**

```
Writes: 100k × 1/sec                  = 100,000 writes/sec sustained
Storage: 100k/sec × 50 B × 100k sec/day = 500 GB/day raw → 180 TB/yr
```
**Conclusion:** a row-per-datapoint relational table is hopeless. This needs a time-series store with columnar compression, batched/buffered writes, and downsampling — keep 1-second resolution for a day, 1-minute for a month, 1-hour for a year, which cuts long-term storage by ~99%.

**C. Video platform (1M uploads/day, 500M views/day).**

```
Views  : 500M/day                     = 5,000 QPS avg → 15,000 peak
Uploads: 1M/day × 50 MB               = 50 TB/day ingest → 18 PB/yr raw
Transcoding: 1M videos × 5 renditions = 5M transcode jobs/day → 50/sec sustained
Egress : 15,000 concurrent streams × 5 Mbps ≈ 75 Gbps
```
**Conclusion:** 75 Gbps cannot come off your origin — the entire design is a CDN design. Transcoding is a queue-and-worker-fleet problem, and the metadata database is by far the easiest part.

Notice the pattern in all three: the estimate immediately identifies *which single subsystem is the actual problem*, and that becomes your deep dive.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-worked-q1", "type": "mcq",
      "prompt": "A metrics system ingests 100k datapoints/sec. Which conclusion follows most directly from that number?",
      "options": [
        {"id":"a","text":"Use a relational table with one row per datapoint and an index on timestamp"},
        {"id":"b","text":"Buffer and batch writes into a time-series/columnar store, and downsample older data to control storage growth"},
        {"id":"c","text":"Add read replicas"},
        {"id":"d","text":"Cache the datapoints in Redis permanently"}
      ],
      "correct": "b",
      "explanation": "100k sustained writes/sec is ~10× what a single relational primary handles, and 180 TB/yr of raw points is unaffordable at full resolution. Batching plus columnar compression plus downsampling is the standard answer; replicas scale reads, not writes." }
] }
```

## Key takeaways

**The recall card:**

```
Seconds/day     ≈ 100,000        1M/day  ≈ 10 QPS      1B/day ≈ 10,000 QPS
Peak            ≈ 2–3× average   Storage/yr ≈ bytes/day × 400 × replicas
Memory 100 ns · SSD 100 µs · DC round trip 500 µs · cross-continent 150 ms
Postgres ≈ 10k QPS/node · Redis ≈ 100k+ ops/sec · app server ≈ 10k req/sec
Tweet 300 B · user 1 KB · JSON response 1–10 KB · photo 2 MB · 1080p video 50 MB/min
```

- **The estimate is a decision, not a calculation.** Every estimate ends with a sentence starting "so…" that points at the subsystem you will deep dive.
- **Round to one significant figure and move on.** Being 30% off never changes an architecture; taking six minutes on long division does.
- **The read:write ratio is the highest-value single number.** Read-heavy → cache, replicas, precomputation. Write-heavy → partitioning, batching, queues, append-only storage.
- **Small numbers are a legitimate, senior answer.** "One database handles this" is a stronger response than an unjustified distributed system, provided you say at what load it stops being true.

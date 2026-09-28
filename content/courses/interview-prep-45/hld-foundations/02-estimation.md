---
kind: lesson
id_key: interview-prep-45/hld-02-estimation
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Back-of-the-Envelope Estimation"
position: 2
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Picture a shopkeeper who, before ordering stock, asks "how many customers a day, roughly?" She doesn't need the exact number. She needs to know if she's stocking a corner shop or a supermarket. Estimation in a system design interview is that same quick check, done with rough numbers in three minutes. Nobody checks your arithmetic. The only question that matters is: is this a one-machine problem, a one-rack-of-machines problem, or a thousand-machine problem? The answer decides everything you draw next.

This lesson gives you a set of numbers worth memorising, four shortcuts for doing the maths fast, and three worked examples to pattern-match against.

## The numbers worth memorising

Learn these two tables once. They cover almost every estimate you'll ever do at a whiteboard.

Picture two friends. One passes a note across the same classroom; the other mails a letter to a friend in another country. The classroom note is like reading from computer memory: almost instant. The international letter is like a network call to a server on another continent: it takes far, far longer. That speed gap is the entire reason system design keeps data close to whoever is asking for it.

**Latency, the time one operation takes.** These are rounded on purpose, because round numbers are what you actually need to remember:

| Operation | Time | Rule of thumb |
|---|---|---|
| L1 cache reference (a tiny, ultra-fast memory inside the CPU) | 1 ns | — |
| Main memory reference (regular RAM) | 100 ns | RAM is about 100 times slower than L1 |
| Read 1 MB from memory | 10 µs | — |
| SSD random read (a solid-state drive) | 100 µs | SSD is about 1,000 times slower than RAM |
| Read 1 MB from SSD | 200 µs | — |
| Round trip within one data center | 500 µs | |
| Disk (HDD) seek (an old-style spinning hard drive) | 10 ms | HDD is about 100 times slower than SSD |
| Round trip, US East to US West | 70 ms | |
| Round trip, US to Europe | 150 ms | Light in fibre-optic cable travels about 200 km per millisecond |

Here `ns` means nanosecond (a billionth of a second), `µs` means microsecond (a millionth of a second), and `ms` means millisecond (a thousandth of a second).

Three ratios matter more than the exact numbers: **memory is roughly 100 times faster than SSD, SSD is roughly 100 times faster than a spinning disk, and a trip across a continent costs more than 100,000 memory reads.** That last fact is the whole reason you cache data, batch requests together, and avoid chatty calls between services in different regions.

**How much one ordinary machine can handle, before you need a second one:**

| Resource | Realistic single-machine number |
|---|---|
| Redis (a fast, in-memory data store) | 100,000 to 1 million operations per second, tens of gigabytes of memory |
| PostgreSQL, well-indexed | 5,000 to 10,000 simple queries per second |
| Application server, Go or Java, simple JSON | 5,000 to 20,000 requests per second |
| Application server, Python or Ruby, one process | 500 to 2,000 requests per second |
| Kafka broker (a message-queue server) | 100,000 to 1 million messages per second |
| Network interface | 10 gigabits per second, about 1.25 gigabytes per second |

Round aggressively. If someone else says "8,000 queries per second on one Postgres node" and you said 10,000, nothing about your design changes. That's the whole point of rounding.

> **Remember:** memory beats SSD by about 100 times, SSD beats a spinning disk by about 100 times, and a cross-continent trip costs more than 100,000 memory reads. That's why you cache data close to the user.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-numbers-q1", "type": "mcq",
      "prompt": "Roughly how much slower is a US-to-Europe round trip (150 milliseconds) than reading from main memory (100 nanoseconds)?",
      "options": [
        {"id":"a","text":"About 1,000 times"},
        {"id":"b","text":"About 100,000 times"},
        {"id":"c","text":"About 1,500,000 times"},
        {"id":"d","text":"About 150 times"}
      ],
      "correct": "c",
      "explanation": "150 milliseconds equals 150,000,000 nanoseconds. Divide that by 100 nanoseconds and you get about 1.5 million. This gap is why one cross-region network call can eat your whole time budget for a request, and why you keep copies of data close to users instead of calling far away every time." }
] }
```

## Four arithmetic shortcuts

These four turn estimation from real maths into something you just remember.

**1. Powers of two match common data sizes.**

| Power | Value | Name |
|---|---|---|
| 2^10 | about 1 thousand | KB (kilobyte) |
| 2^20 | about 1 million | MB (megabyte) |
| 2^30 | about 1 billion | GB (gigabyte) |
| 2^40 | about 1 trillion | TB (terabyte) |

**2. A day has about 100,000 seconds.** It's really 86,400, but rounding up to 100,000 makes the mental maths easy. So **1 million events a day is about 10 a second**, and **1 billion a day is about 10,000 a second**. Nearly every "how many per second" question you'll ever answer is a version of one of those two.

**3. The busiest moment is 2 to 3 times the average.** Real traffic rises and falls through the day, like a shop that's quiet at 3am and busy at 7pm. Design your system to survive the busy peak, but estimate cost using the average. If a big launch or a sale is part of the scenario, use 10 times instead of 2 to 3.

**4. Typical sizes let you turn "how many requests" into "how many bytes."**

| Thing | Size |
|---|---|
| UUID (a unique random ID) | 16 bytes |
| Timestamp | 8 bytes |
| A tweet or short text post | about 300 bytes |
| A user record | about 1 KB |
| A JSON API response | about 1 to 10 KB |
| A thumbnail image | about 50 KB |
| A full photo | about 2 MB |
| One minute of 1080p video | about 50 MB |

One habit that follows from this: **storage for a year is roughly bytes-per-day multiplied by 400** (365 rounded up), and multiply again by 3 if you keep extra copies of the data.

> **Remember:** a million events a day is about 10 a second. A billion a day is about 10,000 a second. Multiply by 2 to 3 for the busiest moments of the day.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-shortcuts-q1", "type": "mcq",
      "prompt": "A service handles 500 million requests a day. Roughly what is its average requests per second, and what should you design for at the busiest moment?",
      "options": [
        {"id":"a","text":"About 500 average, about 1,000 at peak"},
        {"id":"b","text":"About 5,000 average, about 10,000 to 15,000 at peak"},
        {"id":"c","text":"About 50,000 average, about 150,000 at peak"},
        {"id":"d","text":"About 500,000 average, about 1 million at peak"}
      ],
      "correct": "b",
      "explanation": "1 billion a day is about 10,000 a second, so 500 million a day is about 5,000 a second on average. Multiply by 2 to 3 for the busiest moment, giving roughly 10,000 to 15,000 requests per second." }
] }
```

## The estimation template

Run through the same five lines every time, in this order, and say each one out loud. Each line is a chance to earn a point.

```
1. Users        : DAU, and actions per user per day
2. QPS          : (DAU × actions) ÷ 100,000 sec  → then ×3 for peak
3. Read : Write : the single most design-relevant ratio
4. Storage      : bytes per record × records/day × 400 days/yr × years × replication
5. Bandwidth    : bytes per response × peak QPS
```

Here DAU means daily active users, and QPS means queries (or requests) per second.

Then do the part most people forget: **say the conclusion out loud.** An estimate with no conclusion has earned nothing. Examples of a real conclusion:

- "3,500 requests a second at peak is a handful of app servers, not a thousand. I'm not building Google here."
- "100 reads for every write, so caching and extra read copies carry this design."
- "50 terabytes of video a year means the files live in object storage behind a CDN, and the database only stores information about them."
- "One database shard tops out around 10,000 requests a second, so at 40,000 I need at least 4 to 8 shards plus some spare room."

There's a fifth conclusion worth practising, because it's the bravest and most senior one to say: **"these numbers are small. A single Postgres database with one backup copy for reads handles this easily, and I'd start there."** Reaching for a big distributed system that the problem doesn't actually need is a real mistake, and interviewers do mark it down.

> **Remember:** an estimate that doesn't end in a "so..." sentence wasted everyone's time. Numbers only matter for the decision they point to.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-template-q1", "type": "mcq",
      "prompt": "Your estimate comes out at 200 requests a second and 40 GB of total data. What is the strongest thing to say next?",
      "options": [
        {"id":"a","text":"\"I'll split the database across 10 machines for safety.\""},
        {"id":"b","text":"\"This fits comfortably on one main database with a backup copy for reads and for failover. I'd start simple and note what load would force a change.\""},
        {"id":"c","text":"\"I'll add a message queue between every service to decouple them.\""},
        {"id":"d","text":"\"Let's assume 100 times more traffic, so the design is future-proof.\""}
      ],
      "correct": "b",
      "explanation": "Matching the design to the actual measured scale, and naming the load at which it would need to change, is the strong answer. Splitting the database early and adding a queue nobody asked for both look like over-building when the numbers don't call for it." }
] }
```

## Three worked estimates

**A. A read-heavy social feed, 10 million daily active users.**

```
Reads : 10M × 10 timeline views       = 100M/day  → 1,000 QPS avg → 3,000 peak
Writes: 10M × 0.1 posts               = 1M/day    → 10 QPS avg    → 30 peak
Ratio : 100:1 read-heavy
Storage: 1M posts × 300 B             = 300 MB/day → ~120 GB/yr text
         (+ media: 10% of posts × 2 MB = 200 GB/day → 80 TB/yr → object store + CDN)
Bandwidth: 5 KB response × 3,000 QPS  = 15 MB/s   → trivial for text, huge for media
```
**Conclusion:** the text is a small problem. The photos and videos are the real storage and bandwidth problem. Build the read path around a cache, keep the files in object storage behind a CDN, and store only information about each file in the database.

**B. Write-heavy metrics collection, 100,000 servers each sending one measurement a second.**

```
Writes: 100k × 1/sec                  = 100,000 writes/sec sustained
Storage: 100k/sec × 50 B × 100k sec/day = 500 GB/day raw → 180 TB/yr
```
**Conclusion:** a normal database table with one row per measurement can't keep up. This calls for a time-series database (one built for exactly this shape of data), which compresses data by column, batches writes together, and shrinks old data over time: full detail for a day, once-a-minute detail for a month, once-an-hour detail for a year. That cuts long-term storage by about 99%.

**C. A video platform, 1 million uploads a day, 500 million views a day.**

```
Views  : 500M/day                     = 5,000 QPS avg → 15,000 peak
Uploads: 1M/day × 50 MB               = 50 TB/day ingest → 18 PB/yr raw
Transcoding: 1M videos × 5 renditions = 5M transcode jobs/day → 50/sec sustained
Egress : 15,000 concurrent streams × 5 Mbps ≈ 75 Gbps
```
**Conclusion:** 75 gigabits per second cannot come straight from your own servers. The entire design has to be built around a CDN. Converting videos into different quality levels is a queue-and-worker problem, and the database that stores video titles and descriptions is by far the easiest part.

Notice the pattern across all three examples: the estimate points straight at one subsystem that's actually hard, and that subsystem becomes your deep dive later in the interview.

> **Remember:** every worked estimate should end by pointing at one subsystem. That's the part worth designing carefully.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-02-worked-q1", "type": "mcq",
      "prompt": "A metrics system takes in 100,000 measurements a second. Which conclusion follows most directly from that number?",
      "options": [
        {"id":"a","text":"Use a normal relational table with one row per measurement and an index on the timestamp"},
        {"id":"b","text":"Buffer and batch the writes into a time-series database, and shrink older data over time to control storage growth"},
        {"id":"c","text":"Add extra read copies of the database"},
        {"id":"d","text":"Store the measurements in Redis forever"}
      ],
      "correct": "b",
      "explanation": "100,000 sustained writes a second is about 10 times what one relational database can handle, and 180 terabytes a year of raw data is too expensive to keep at full detail. Batching writes into a time-series store and shrinking old data is the standard answer; extra read copies help reads, not this write load." }
] }
```

## Quick recap

```
Seconds/day     ≈ 100,000        1M/day  ≈ 10 QPS      1B/day ≈ 10,000 QPS
Peak            ≈ 2–3× average   Storage/yr ≈ bytes/day × 400 × replicas
Memory 100 ns · SSD 100 µs · DC round trip 500 µs · cross-continent 150 ms
Postgres ≈ 10k QPS/node · Redis ≈ 100k+ ops/sec · app server ≈ 10k req/sec
Tweet 300 B · user 1 KB · JSON response 1–10 KB · photo 2 MB · 1080p video 50 MB/min
```

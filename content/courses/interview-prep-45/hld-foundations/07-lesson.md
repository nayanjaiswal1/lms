---
kind: lesson
id_key: interview-prep-45/hld-07-storage-choice
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Databases I — Choosing Storage, Indexes, and Transactions"
position: 7
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

"SQL or NoSQL?" is asked in almost every design interview, and the answer that scores is never a preference — it is a mapping from *access pattern* to *storage engine*. This lesson covers that mapping, what an index actually is, why B-trees and LSM-trees behave so differently, and the transaction guarantees you are relying on whether you know it or not.

## Picking a store from the access pattern

Start from the queries, not the technology.

| If the workload is… | Use | Because |
|---|---|---|
| Entities with relationships, ad-hoc queries, multi-row invariants | **Relational** (Postgres, MySQL) | Joins, constraints, real transactions, mature tooling |
| Huge volume, known key, simple lookups, extreme write rate | **Wide-column** (Cassandra, DynamoDB, HBase) | Horizontal writes, tunable consistency, no joins |
| Flexible/evolving documents fetched whole | **Document** (MongoDB, DocumentDB) | Schema flexibility, nested reads without joins |
| Ephemeral state, counters, leaderboards, sessions, queues | **In-memory** (Redis) | Sub-ms latency, rich data structures |
| Full-text search, faceting, relevance ranking | **Search index** (Elasticsearch, OpenSearch) | Inverted index, scoring, aggregations |
| Time-stamped metrics at very high write rate | **Time-series** (Timescale, InfluxDB, Prometheus) | Columnar compression, downsampling, retention |
| Relationship traversal ("friends of friends of…") | **Graph** (Neo4j) | Index-free adjacency; joins would explode |
| Large immutable blobs | **Object store** (S3) + metadata in a DB | Cheap, durable, CDN-friendly |
| Scans over billions of rows for analytics | **Columnar / warehouse** (BigQuery, ClickHouse, Redshift) | Reads only the columns needed, compresses well |

Three things to say when you make the choice:

1. **"Postgres until proven otherwise."** It does JSON documents, full-text search, geospatial, and time-series adequately, and one system you can operate beats four you cannot. Reaching for Cassandra at 200 QPS is a marked negative.
2. **Polyglot persistence is normal but each store has a cost**: another thing to back up, monitor, secure, and keep in sync. Justify each one.
3. **Name the split when you use two.** "Postgres is the source of truth; Elasticsearch is a derived index rebuilt from the change stream, and it may lag by a second."

**Cassandra vs DynamoDB vs Mongo, in one line each**: Cassandra is leaderless multi-master with tunable quorums, unbeatable for write-heavy multi-region; DynamoDB is the same shape as a managed service with strict partition-key discipline; MongoDB is a leader-based document store that is pleasant to develop against and needs care when your access pattern turns relational.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-choice-q1", "type": "mcq",
      "prompt": "A system needs 100k writes/sec of sensor readings, always queried as \"readings for device X between T1 and T2\", and never joined to anything. What is the best fit?",
      "options": [
        {"id":"a","text":"A relational table with a B-tree index on (device_id, ts)"},
        {"id":"b","text":"A time-series or wide-column store partitioned by device_id and clustered by timestamp, with compression and downsampling of old data"},
        {"id":"c","text":"A graph database"},
        {"id":"d","text":"Redis as the source of truth"}
      ],
      "correct": "b",
      "explanation": "The access pattern is a known partition key plus a time range — exactly what wide-column/time-series engines are built for, and the write rate is ~10× a single relational primary. Partition by device, cluster by time, downsample the history." }
] }
```

## Indexes: what they are and when they hurt

An index is a separate data structure that maps column values to row locations, so the engine can seek instead of scan. Everything else follows from that sentence.

```sql
-- Without an index: sequential scan of 10M rows
SELECT * FROM tweets WHERE author_id = 42 ORDER BY created_at DESC LIMIT 20;

-- With this index: an index seek to author 42, then 20 rows read in order
CREATE INDEX idx_tweets_author_time ON tweets (author_id, created_at DESC);
```

**Composite index column order is the whole game.** An index on `(a, b, c)` serves queries filtering on `a`, on `a, b`, and on `a, b, c` — a *left prefix*. It does **not** serve a query filtering on `b` alone. The mnemonic that survives interviews: **equality columns first, then the range/sort column last**.

**A covering index** contains every column the query needs, so the engine never touches the table (`INCLUDE (...)` in Postgres). This turns two I/Os into one and is a first-line fix for a hot query.

**What indexes cost:**

- Every `INSERT`/`UPDATE`/`DELETE` must update every index on the table — a write-heavy table with eight indexes is doing nine writes.
- They consume storage and cache memory that the table's own hot pages want.
- The planner can pick badly when statistics are stale.
- **Low-cardinality columns rarely benefit** — an index on a boolean usually loses to a scan, because reading half the table via random index lookups is slower than reading it sequentially.

**Where indexes silently fail**: wrapping the column in a function (`WHERE lower(email) = ...` needs an expression index on `lower(email)`), a leading wildcard (`LIKE '%foo'`), implicit type casts, and `OR` across different columns (often better as a `UNION`).

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-index-q1", "type": "mcq",
      "prompt": "You have an index on `(country, city, created_at)`. Which query can it NOT accelerate?",
      "options": [
        {"id":"a","text":"WHERE country = 'IN'"},
        {"id":"b","text":"WHERE country = 'IN' AND city = 'Pune'"},
        {"id":"c","text":"WHERE city = 'Pune'"},
        {"id":"d","text":"WHERE country = 'IN' AND city = 'Pune' ORDER BY created_at DESC"}
      ],
      "correct": "c",
      "explanation": "A composite index is sorted by its leading column first, so it only serves queries that constrain a left prefix. Filtering on `city` alone means the index gives no useful ordering — you would need a separate index led by `city`." }
] }
```

## B-tree vs LSM-tree: why write-heavy stores are different

This is the "one level below the box" question for storage, and it explains the entire read/write personality of every database you will name.

**B-tree** (Postgres, MySQL/InnoDB, most relational engines). A balanced tree of fixed-size pages updated *in place*.

- Reads: predictable, ~O(log n) page reads, and the leaf pages are sorted so range scans are cheap.
- Writes: find the page, modify it, write it back — a **random** write, plus a write-ahead log entry for durability. Page splits fragment over time.
- Best for: read-heavy and mixed workloads, range queries, strong single-node consistency.

**LSM-tree** (Cassandra, RocksDB, LevelDB, HBase, ScyllaDB). Writes land in an in-memory table, are appended to a commit log, and are periodically flushed to immutable sorted files (SSTables) that background **compaction** merges.

- Writes: sequential appends only — dramatically faster, which is why LSM stores dominate write-heavy workloads.
- Reads: may have to check the memtable plus several SSTables, so a **read amplification** cost — mitigated by Bloom filters per SSTable (cheap "definitely not here") and by compaction.
- Costs: compaction consumes I/O and CPU in the background and causes latency spikes; deletes are **tombstones** that only free space at the next compaction; space amplification while duplicates coexist.

| | B-tree | LSM-tree |
|---|---|---|
| Write path | Random, in-place | Sequential append |
| Write throughput | Lower | **Much higher** |
| Read path | One tree | Memtable + N SSTables (+ Bloom filters) |
| Point-read latency | Predictable | More variable |
| Range scans | Excellent | Good |
| Space overhead | Fragmentation | Duplicates until compaction |
| Background work | Vacuum/rebuild | **Compaction** (I/O spikes) |
| Deletes | In place | Tombstones |

The one-sentence version, worth memorising: **"B-trees optimise reads by paying on every write; LSM-trees optimise writes by paying on reads and in background compaction."**

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-lsm-q1", "type": "mcq",
      "prompt": "Why do LSM-tree storage engines sustain far higher write throughput than B-tree engines?",
      "options": [
        {"id":"a","text":"They keep the entire dataset in memory"},
        {"id":"b","text":"Writes are buffered in memory and flushed as sequential appends of immutable sorted files, avoiding the random in-place page updates a B-tree performs"},
        {"id":"c","text":"They do not provide durability"},
        {"id":"d","text":"They use smaller page sizes"}
      ],
      "correct": "b",
      "explanation": "Sequential I/O beats random I/O by a wide margin even on SSDs, and never rewriting a page in place removes read-modify-write. The bill arrives later as read amplification and compaction I/O." }
] }
```

## Transactions: ACID and isolation levels

**ACID**, stated so you can defend it:

- **Atomicity** — all of the statements commit, or none do.
- **Consistency** — the transaction moves the database from one valid state to another, respecting declared constraints. (This is *not* the "C" in CAP; a favourite trick question.)
- **Isolation** — concurrent transactions do not see each other's partial work, to the degree the isolation level promises.
- **Durability** — once committed, it survives a crash (write-ahead log, fsync, replication).

**Isolation levels and the anomalies they permit** — know this table cold:

| Level | Dirty read | Non-repeatable read | Phantom read | Cost |
|---|---|---|---|---|
| Read Uncommitted | ✅ possible | ✅ | ✅ | Lowest |
| **Read Committed** (Postgres default) | ❌ | ✅ | ✅ | Low |
| **Repeatable Read** (MySQL default; Postgres = snapshot) | ❌ | ❌ | ✅ (❌ in Postgres) | Medium |
| **Serializable** | ❌ | ❌ | ❌ | Highest — retries under contention |

- **Dirty read**: you read another transaction's uncommitted data.
- **Non-repeatable read**: you read the same row twice in one transaction and get different values.
- **Phantom read**: you run the same range query twice and new rows appear.
- **Lost update**: two transactions read-modify-write the same row and one update vanishes. Read Committed does *not* protect you.

The practical rule: **Read Committed plus explicit locking or an atomic write** for the small number of places it matters.

```sql
-- Lost update, the classic bug: two concurrent runs can both read 10 and both write 9.
SELECT seats FROM events WHERE id = 1;          -- 10
UPDATE events SET seats = 9 WHERE id = 1;

-- Fix 1 — pessimistic: take the row lock, then decide.
BEGIN;
SELECT seats FROM events WHERE id = 1 FOR UPDATE;
UPDATE events SET seats = seats - 1 WHERE id = 1;
COMMIT;

-- Fix 2 — optimistic: no lock; retry if someone else moved first.
UPDATE events SET seats = seats - 1, version = version + 1
WHERE id = 1 AND version = $expected_version AND seats > 0;
-- 0 rows affected → someone beat you → re-read and retry

-- Fix 3 — atomic and best when it applies: let the database do the arithmetic
-- and let a CHECK constraint enforce the invariant.
UPDATE events SET seats = seats - 1 WHERE id = 1 AND seats > 0;
```

**Pessimistic vs optimistic** is a genuine interview trade-off: pessimistic locking is right under high contention (booking the last seat of a popular event); optimistic is right under low contention (editing your own profile), because it avoids holding locks and scales better — at the cost of retries when you guess wrong.

**MVCC**, the mechanism behind all of this in Postgres and MySQL: writers create new row versions instead of overwriting, so readers never block writers and writers never block readers. The cost is old versions that must be cleaned up (`VACUUM`), and long-running transactions that hold the cleanup back and bloat the table.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-txn-q1", "type": "mcq",
      "prompt": "Two concurrent requests each run `SELECT seats` (both read 10) and then `UPDATE events SET seats = 9`. Which anomaly is this, and which fix removes it without any locking?",
      "options": [
        {"id":"a","text":"Dirty read; fix by raising the isolation level to Read Committed"},
        {"id":"b","text":"Lost update; fix with a single atomic statement — `UPDATE events SET seats = seats - 1 WHERE id = 1 AND seats > 0` — so the database computes the new value under its own row lock"},
        {"id":"c","text":"Phantom read; fix with Serializable isolation"},
        {"id":"d","text":"Non-repeatable read; fix by reading twice"}
      ],
      "correct": "b",
      "explanation": "Read-modify-write in application code loses one of the two updates. Making the arithmetic part of the UPDATE means each statement takes the row lock and applies its decrement to the current value; the `seats > 0` guard prevents overselling." }
] }
```

## Key takeaways

**The recall card:**

```
Choose by access pattern, not fashion. Postgres until proven otherwise.
Index = seek instead of scan. Composite = LEFT PREFIX only.
       equality columns first, range/sort column last. Covering index avoids the table read.
Index cost = write amplification + memory + planner risk. Low cardinality rarely helps.
B-tree  : in-place, random writes, great reads       → read-heavy, relational
LSM-tree: append-only, sequential writes, compaction → write-heavy, Cassandra/Rocks
ACID's C ≠ CAP's C.
Isolation: Read Committed (default) allows non-repeatable + phantom + LOST UPDATE.
Concurrency fixes: atomic UPDATE > optimistic version check > SELECT FOR UPDATE
MVCC: readers don't block writers; cost is VACUUM and long-transaction bloat.
```

- **Justify the store with a query, every time.** "Reads are always by device and time range, never joined" is what makes a wide-column choice defensible.
- **The index answer that scores is the composite prefix rule** plus the honest cost: every index is another write on every insert.
- **B-tree vs LSM is the storage deep-dive question**, and one sentence covers it: reads paid up front vs writes paid later.
- **"Read Committed does not prevent lost updates"** is the single most useful transaction fact for design interviews — every booking, inventory, and wallet question is a lost-update question in disguise.

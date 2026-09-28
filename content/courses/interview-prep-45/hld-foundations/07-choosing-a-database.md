---
kind: lesson
id_key: interview-prep-45/hld-07-storage-choice
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Choosing a Database: Storage, Indexes and Transactions"
position: 7
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

"SQL or NoSQL?" comes up in almost every design interview. The answer that actually scores points is never a personal preference. It's a mapping from what your queries look like to which storage engine handles that shape best. This lesson walks through that mapping, what a database index actually is, why two common storage designs behave so differently, and the transaction guarantees you're already relying on, whether you know it or not.

## Picking a store from the access pattern

Start from the questions you'll actually ask the database, not from whichever technology you've heard of.

| If the workload is… | Use | Because |
|---|---|---|
| Related entities, varied queries, rules that span multiple rows | **Relational** (Postgres, MySQL) | Joins, constraints, real transactions, mature tools |
| Huge volume, a known key, simple lookups, very high write rate | **Wide-column** (Cassandra, DynamoDB, HBase) | Spreads writes across many machines, tunable correctness, no joins |
| Flexible, evolving records fetched as a whole | **Document** (MongoDB, DocumentDB) | Flexible shape, reads nested data without joins |
| Short-lived data, counters, leaderboards, sessions, queues | **In-memory** (Redis) | Sub-millisecond speed, useful built-in data structures |
| Full-text search, filters, ranking results by relevance | **Search index** (Elasticsearch, OpenSearch) | Built to search text quickly and score results |
| Time-stamped measurements at very high write rate | **Time-series** (Timescale, InfluxDB, Prometheus) | Compresses well, shrinks old data automatically, manages retention |
| Following relationships (friend of a friend of a friend) | **Graph** (Neo4j) | Follows connections directly, instead of joins that would explode |
| Large files that rarely change | **Object store** (S3) plus a small database for details about each file | Cheap, durable, works well with a CDN |
| Scanning billions of rows for analytics | **Columnar / warehouse** (BigQuery, ClickHouse, Redshift) | Reads only the columns it needs, compresses very well |

Three things worth saying out loud when you make this choice.

**"Postgres until proven otherwise."** A well-run Postgres database handles JSON documents, full-text search, location data, and time-series data reasonably well all at once. Running one system you actually know how to operate beats running four you don't. Reaching for Cassandra at 200 requests a second is treated as a mistake, not a strength.

**Using more than one kind of database at once is normal, but each one has a real cost.** Every extra store is one more thing to back up, monitor, secure, and keep in sync with the others. Justify each one you add.

**When you do use two stores, say clearly which one is the source of truth.** For example: "Postgres holds the real data; Elasticsearch is a search index rebuilt from a stream of Postgres's own changes, and it might lag behind by about a second."

**A one-line comparison of three popular wide-column and document stores.** Cassandra has no single leader, spreads writes across many equal machines, and lets you tune correctness per request; it's hard to beat for write-heavy systems spread across regions. DynamoDB is a managed service shaped the same way, but it demands careful choice of the key you partition by. MongoDB has a leader-based design, is pleasant to build with day to day, and needs extra care once your data starts looking more like related tables than standalone documents.

> **Remember:** start from the query you need to answer, not from a favourite database. "Postgres until proven otherwise" is a strong, defensible default.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-choice-q1", "type": "mcq",
      "prompt": "A system needs 100,000 writes a second of sensor readings, always queried as \"readings for device X between time T1 and T2,\" and never joined with anything else. What fits best?",
      "options": [
        {"id":"a","text":"A relational table with an index on device id and timestamp together"},
        {"id":"b","text":"A time-series or wide-column store, partitioned by device id and sorted within each partition by timestamp, with compression and shrinking of old data"},
        {"id":"c","text":"A graph database"},
        {"id":"d","text":"Redis as the only copy of the data"}
      ],
      "correct": "b",
      "explanation": "The query pattern here is a known key plus a time range, exactly what a time-series or wide-column store is built for, and the write rate is about 10 times what a single relational database handles. Partitioning by device and sorting by time, plus shrinking old data over time, is the standard answer." }
] }
```

## Indexes: what they are and when they hurt

Think of a textbook with no index at the back. To find every page that mentions "mitosis," you'd have to read the whole book cover to cover. An index at the back tells you the exact page numbers, so you jump straight there instead. A database index works the same way: it's a separate structure that maps a column's values to where the matching rows actually live, so the database can jump straight to them instead of reading every single row.

```sql
-- Without an index: sequential scan of 10M rows
SELECT * FROM tweets WHERE author_id = 42 ORDER BY created_at DESC LIMIT 20;

-- With this index: an index seek to author 42, then 20 rows read in order
CREATE INDEX idx_tweets_author_time ON tweets (author_id, created_at DESC);
```

**When an index covers several columns, the order you list them in matters enormously.** An index on columns `(a, b, c)` speeds up a query that filters on `a` alone, one that filters on `a` and `b` together, and one that filters on all three. This is called a left prefix, meaning it only helps when your query's filter starts matching from the leftmost column onward. It does **not** speed up a query that filters on `b` alone, skipping `a`. A rule worth remembering: put the columns you filter for an exact match first, and put the column you sort or filter by a range on last.

**A covering index** stores every column a query needs directly inside the index itself, so the database never has to go fetch the actual row separately. In Postgres this is written with `INCLUDE (...)`. This turns two separate reads into one, and it's often the first thing to try when a specific query is running too slowly.

**Indexes are not free. Here is what they cost you:**

- Every time you insert, update, or delete a row, every index on that table has to be updated too. A write-heavy table with eight indexes on it is really doing nine writes for every one you asked for.
- They take up storage space and memory that the table's own frequently-used pages would otherwise use.
- The database's query planner can sometimes choose a worse plan when its internal statistics are out of date.
- **Indexing a column with only a few possible values rarely helps.** An index on a true-or-false column usually loses to simply scanning the whole table, because jumping around randomly through an index to fetch half the rows is slower than just reading them in order.

**Indexes can silently fail to help in a few common situations**: wrapping the column in a function, like `WHERE lower(email) = ...`, needs a special index built on that exact function; a search pattern starting with a wildcard, like `LIKE '%foo'`, can't use a normal index either; neither can an implicit type conversion, or an `OR` condition spanning two different columns, which is often better rewritten as two queries combined with `UNION`.

> **Remember:** a composite index on `(a, b, c)` only helps queries that filter starting from the left: `a` alone, `a` and `b` together, or all three. It cannot help a query that filters on `b` alone.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-index-q1", "type": "mcq",
      "prompt": "You have an index on the columns `(country, city, created_at)`, in that order. Which query can it NOT speed up?",
      "options": [
        {"id":"a","text":"WHERE country = 'IN'"},
        {"id":"b","text":"WHERE country = 'IN' AND city = 'Pune'"},
        {"id":"c","text":"WHERE city = 'Pune'"},
        {"id":"d","text":"WHERE country = 'IN' AND city = 'Pune' ORDER BY created_at DESC"}
      ],
      "correct": "c",
      "explanation": "A composite index is sorted starting from its first column, so it only helps queries that filter starting from that same leftmost column onward. Filtering on `city` alone skips `country` entirely, so this index gives no useful shortcut; a separate index starting with `city` would be needed instead." }
] }
```

## B-tree vs LSM-tree: why write-heavy stores are different

Picture two libraries handling returned books. Library A puts every returned book straight back onto its exact alphabetical shelf spot right away. That's slower per book, but any book is instantly findable afterward. Library B just drops every return onto a cart by the door, and once the cart is full, carries the whole thing to the shelves in one batch. That's much faster per return, but you might have to check both the cart and the shelf to find a specific book. Library A is how a B-tree works. Library B is how an LSM-tree works. This single difference explains almost everything about how a database behaves under reads versus writes.

**A B-tree** is used by Postgres, MySQL's InnoDB engine, and most relational databases. It's a balanced tree of fixed-size pages, and it updates those pages *in place*, directly where they already live.

- Reading is predictable: roughly a handful of page reads no matter how big the table gets, and because the lowest level of the tree is kept sorted, scanning a range of values is cheap.
- Writing means finding the right page, changing it, and writing it back. That's a **random** write to disk, plus an entry in a separate log kept purely to survive a crash. Over time, pages that keep splitting apart become fragmented.
- Best suited to read-heavy or mixed workloads, range queries, and strong correctness on a single machine.

**An LSM-tree**, short for log-structured merge-tree, is used by Cassandra, RocksDB, LevelDB, HBase, and ScyllaDB. New writes land first in an in-memory table, get appended to a log on disk for safety, and are periodically flushed out into new, unchangeable, sorted files. A background process called compaction later merges those files back together.

- Writing only ever appends data, never rewrites it in place, which is dramatically faster. This is exactly why LSM-based stores dominate write-heavy workloads.
- Reading may have to check the in-memory table plus several of those sorted files on disk, a cost called read amplification. This is softened by keeping a Bloom filter per file, a small structure that can quickly say "definitely not in this file," and by the ongoing compaction process merging files together.
- The costs: compaction uses real disk and CPU time in the background and can cause sudden slowdowns; a delete is really just a marker called a tombstone, and the space isn't actually freed until the next compaction; and duplicate copies of the same data can pile up temporarily before compaction cleans them up.

| | B-tree | LSM-tree |
|---|---|---|
| How it writes | Random, changes data in place | Only ever appends |
| How much it can write | Lower | **Much higher** |
| How it reads | One tree | The in-memory table plus several files, helped by Bloom filters |
| How predictable a single read is | Very predictable | More variable |
| Range scans | Excellent | Good |
| Wasted space | Fragmented pages | Duplicate data until compaction runs |
| Background work | Occasional cleanup (called vacuum) | **Compaction**, which can cause sudden slowdowns |
| Deletes | Changed in place | Marked with a tombstone first |

The one sentence worth memorising: **B-trees make reads fast by paying a small cost on every write. LSM-trees make writes fast by paying that cost later, on reads and during background compaction.**

> **Remember:** a B-tree write updates data in place immediately. An LSM-tree write just appends, and cleans up later. That's why LSM-trees win on write-heavy workloads.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-lsm-q1", "type": "mcq",
      "prompt": "Why do LSM-tree storage engines sustain far more writes per second than B-tree engines?",
      "options": [
        {"id":"a","text":"They keep the entire dataset in memory"},
        {"id":"b","text":"Writes are buffered in memory and flushed as new, unchangeable, sorted files, avoiding the random in-place page changes a B-tree performs"},
        {"id":"c","text":"They don't guarantee data survives a crash"},
        {"id":"d","text":"They simply use smaller page sizes"}
      ],
      "correct": "b",
      "explanation": "Writing data in one continuous sweep beats jumping around randomly to update it, even on modern solid-state drives, and never rewriting a page in place skips the read-modify-write cost a B-tree pays. That cost doesn't disappear; it shows up later as extra reading work and background compaction." }
] }
```

## Transactions: ACID and isolation levels

Picture transferring 100 rupees from your account to a friend's. Two things have to happen: your balance drops by 100, and your friend's balance rises by 100. If the system crashes right after the first step but before the second, the money has simply vanished. A transaction is the database's promise that a group of changes like this happen together completely, or not at all.

**ACID is the set of guarantees a transaction makes, and you should be able to defend each letter:**

- **Atomicity** means every statement in the transaction commits, or none of them do.
- **Consistency** here means the transaction moves the database from one valid state to another, respecting whatever rules you've declared, like a column that must never be negative. This is a different "C" from the one in CAP, a topic covered in a later lesson; interviewers like to test whether you know that.
- **Isolation** means transactions running at the same time don't see each other's unfinished work, at least to the degree the chosen isolation level actually promises.
- **Durability** means once a transaction is confirmed, it survives a crash, thanks to a safety log, forcing data to disk, and often replication too.

**Isolation levels decide which problems can still happen. Learn this table well:**

| Level | Can you read another transaction's unfinished work? | Can the same read return different values twice? | Can new rows appear in a repeated range query? | Cost |
|---|---|---|---|---|
| Read Uncommitted | Yes | Yes | Yes | Lowest |
| **Read Committed** (Postgres's default) | No | Yes | Yes | Low |
| **Repeatable Read** (MySQL's default; called "snapshot" in Postgres) | No | No | Yes, except in Postgres, where it's also prevented | Medium |
| **Serializable** | No | No | No | Highest, and can force retries under heavy contention |

A few terms defined plainly. A **dirty read** means reading another transaction's work before it's even confirmed. A **non-repeatable read** means reading the same row twice in one transaction and getting two different answers. A **phantom read** means running the same range query twice and seeing new rows appear the second time. A **lost update** means two transactions each read a row, change it, and write it back, and one of those two changes silently disappears. Read Committed, Postgres's own default, does **not** protect you from a lost update.

The practical rule most teams follow: use Read Committed everywhere by default, and add explicit locking or an atomic write only in the small number of places where a lost update would actually matter.

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

**Choosing between locking ahead of time (pessimistic) and checking afterward (optimistic) is a real trade-off worth naming.** Locking ahead of time is right when many people are competing for the same thing at once, like booking the very last seat at a popular event. Checking afterward is right when competition is rare, like editing your own profile, because it never holds a lock and so scales better, at the cost of having to retry the occasional guess that turned out wrong.

**MVCC** (multi-version concurrency control) is the mechanism behind all of this in Postgres and MySQL. Instead of overwriting a row, a writer creates a new version of it, so readers never have to wait for writers, and writers never have to wait for readers. The cost is that old versions pile up and need periodic cleanup, called vacuuming, and a transaction left running for a long time can hold that cleanup back and let the table bloat.

> **Remember:** Read Committed does not prevent a lost update. Two people reading the same row and both writing back is a real bug, and the fix is one single atomic UPDATE statement, not two separate application steps.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-07-txn-q1", "type": "mcq",
      "prompt": "Two requests running at the same time each read the seats column (both see 10), then each write `seats = 9`. Which problem is this, and which fix removes it without using any lock?",
      "options": [
        {"id":"a","text":"A dirty read; fix it by raising the isolation level to Read Committed"},
        {"id":"b","text":"A lost update; fix it with one atomic statement, such as `UPDATE events SET seats = seats - 1 WHERE id = 1 AND seats > 0`, so the database computes the new value while holding its own row lock"},
        {"id":"c","text":"A phantom read; fix it with Serializable isolation"},
        {"id":"d","text":"A non-repeatable read; fix it by reading twice"}
      ],
      "correct": "b",
      "explanation": "Reading a value, changing it, and writing it back in separate application steps loses one of the two updates. Folding the arithmetic into the UPDATE statement itself means each statement takes the row's lock and applies its own change to whatever the current value actually is; the extra `seats > 0` check also stops overselling." }
] }
```

## Quick recap

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

---
kind: lesson
id_key: interview-prep-45/day-04-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "PostgreSQL Indexing"
position: 4
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Every backend interview eventually asks "how would you speed up this slow query" and the answer they want to hear is "add an index," followed immediately by "which kind, and why not just index everything." Today you build the mental model of a B-tree index, measure a real before/after, and learn the cases where an index makes things *worse*.

## What a B-tree index actually is

PostgreSQL's default index type is a B-tree (balanced tree). Instead of scanning every row (`Seq Scan`), the database walks a tree of sorted keys, each pointing to the physical row location (a "tuple ID" / TID), to find matching rows in `O(log n)` comparisons instead of `O(n)`.

```
                [50]
              /      \
         [20,35]      [70,90]
        /   |   \      /   |   \
     [..] [..] [..]  [..] [..] [..]
```

Each node holds a range of sorted key values; leaf nodes point to the actual heap (table) rows. A lookup for `WHERE id = 42` descends the tree, comparing against node boundaries, in a handful of page reads instead of reading the entire table.

Without an index, PostgreSQL does a **sequential scan**: read every page of the table, check every row against the `WHERE` clause. For a small table this is often *faster* than an index lookup (see selectivity below), and that's the nuance interviewers are listening for.

## Creating indexes and measuring the difference

```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    total NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Load 100k rows
INSERT INTO orders (customer_id, status, total, created_at)
SELECT
    (random() * 5000)::int,
    (ARRAY['pending', 'paid', 'shipped', 'cancelled'])[floor(random() * 4 + 1)],
    (random() * 500)::numeric(10, 2),
    now() - (random() * interval '365 days')
FROM generate_series(1, 100000);
```

```sql
-- Before: no index on status
EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'paid';
-- Seq Scan on orders  (cost=0.00..2334.00 rows=25000 width=32) (actual time=0.02..18.4 rows=~25000 loops=1)

CREATE INDEX idx_orders_status ON orders (status);

EXPLAIN ANALYZE
SELECT * FROM orders WHERE status = 'paid';
-- Still a Seq Scan! Because ~25% of rows match — the planner decides scanning is cheaper than
-- random-access index lookups for a quarter of the table.
```

```sql
-- Now try a selective column
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42;
-- Seq Scan, ~20 rows out of 100k

CREATE INDEX idx_orders_customer_id ON orders (customer_id);

EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42;
-- Index Scan using idx_orders_customer_id  (cost=0.29..8.31 rows=20 width=32) (actual time=0.015..0.045 rows=20 loops=1)
```

The `status` index barely helped; the `customer_id` index cut cost by two orders of magnitude. That gap **is** the interview answer to "when would you not use an index."

## Index selectivity

**Selectivity** equals distinct values divided by total rows. High selectivity (e.g. `customer_id`, near-unique) means an index prunes most of the table per lookup: a huge win. Low selectivity (e.g. `status` with 4 possible values, or a boolean flag) means an index lookup still has to fetch a large fraction of the table's rows, and each of those is a random-access read from the heap, often slower than one sequential scan that reads pages in order.

```sql
SELECT
    count(DISTINCT status)::float / count(*) AS status_selectivity,
    count(DISTINCT customer_id)::float / count(*) AS customer_selectivity
FROM orders;
-- status_selectivity: ~0.00004 (4 values / 100k rows)     -> bad index candidate alone
-- customer_selectivity: ~0.05   (5000 values / 100k rows) -> good index candidate
```

Rule of thumb interviewers want to hear: **an index pays off when a query returns a small fraction of the table.** If a query typically returns more than 10-15% of rows, a sequential scan is usually cheaper, and the planner knows this and will ignore your index (as seen above with `status`). That's correct behavior, not a bug.

## Reading EXPLAIN ANALYZE

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42 AND status = 'paid';
```

```
Index Scan using idx_orders_customer_id on orders
  (cost=0.29..8.45 rows=5 width=32)
  (actual time=0.018..0.052 rows=5 loops=1)
  Index Cond: (customer_id = 42)
  Filter: (status = 'paid'::text)
  Rows Removed by Filter: 15
Planning Time: 0.112 ms
Execution Time: 0.071 ms
```

Read it in this order:

- **`cost=A..B`**: the planner's estimate, in arbitrary units, not milliseconds. `A` is startup cost, `B` is total cost.
- **`actual time=A..B`**: real measured milliseconds, only present with `ANALYZE` (which actually *runs* the query, so be careful running it on a production `DELETE`/`UPDATE` without wrapping it in a transaction you roll back).
- **`rows=N`** on the plan node vs `rows=N` in `actual`: a large mismatch means stale table statistics; fix with `ANALYZE orders;`.
- **`Index Cond`** vs **`Filter`**: `Index Cond` is evaluated by the index itself (cheap); `Filter` is applied after fetching rows (the `status='paid'` check here happens after the index already narrowed to `customer_id=42`, since there's no composite index covering both).
- **`Rows Removed by Filter`**: rows the index scan fetched but then discarded. A high number here is a sign a composite index would help.

A composite index fixes the above filter cost entirely:

```sql
CREATE INDEX idx_orders_customer_status ON orders (customer_id, status);
-- now both conditions become Index Cond, zero rows removed by filter
```

**Column order in a composite index matters.** `(customer_id, status)` supports queries filtering on `customer_id` alone or `customer_id + status`, but not `status` alone, since the index can't be used to skip to arbitrary status values without a leading `customer_id` predicate. This is the classic "leftmost prefix" rule.

## When NOT to use an index

- Low-selectivity columns queried alone (booleans, small enums): sequential scan wins, as shown above.
- Small tables: a full table fits in a few pages, so index overhead exceeds the scan cost.
- Columns that are written far more than read: every `INSERT`/`UPDATE`/`DELETE` must also update every index on that table, so a heavily-written, rarely-queried column is pure overhead.
- Wide/large text columns without a partial or expression index: indexing a whole `TEXT` column bloats the index, so consider a `GIN`/trigram index or index only a prefix instead.

Selectivity is the number underlying all four of these cases. Whether the cause is a boolean flag, a tiny table, or a write-heavy column, the common thread is that an index is only worth its write overhead when it lets Postgres skip most of the table on read.

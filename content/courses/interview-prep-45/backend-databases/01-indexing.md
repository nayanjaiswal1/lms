---
kind: lesson
id_key: interview-prep-45/day-04-backend
course: interview-prep-45
section: backend-databases
section_title: "Databases (PostgreSQL)"
section_position: 9
section_group: "Backend"
title: "Indexing"
position: 1
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
---

Picture a phone book with a million names in random order. Finding "Smith" means checking every single page. Now picture the same names sorted alphabetically: you jump straight to the S section. An index is that sorted shortcut, built for a database table instead of a phone book.

Nearly every backend interview asks some version of "how would you speed up this slow query," and the answer they want is "add an index," followed immediately by "which kind, and why not just index every column." This lesson builds that full answer.

## How a database index finds a row fast

Without an index, Postgres does a **sequential scan**: it reads every page of the table and checks every row against your `WHERE` clause. On a small table that's fast enough. On a big one, it's the phone-book-in-random-order problem.

Postgres's default index type is a **B-tree**, a balanced tree of sorted keys. Each key points to the exact physical location of its row (called a tuple ID). A lookup walks down the tree comparing against a handful of boundaries instead of reading the whole table.

```
                [50]
              /      \
         [20,35]      [70,90]
        /   |   \      /   |   \
     [..] [..] [..]  [..] [..] [..]
```

A search for `id = 42` starts at the root, sees 42 is less than 50, goes left, sees it's between 35 and 50, and so on, in a handful of steps instead of scanning the whole table.

```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    total NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
```

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
-- Seq Scan on orders, checking all 100,000 rows for ~20 matches

CREATE INDEX idx_orders_customer_id ON orders (customer_id);

EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
-- Index Scan using idx_orders_customer_id  (cost=0.29..8.31 rows=20 width=32)
```

Same table, same query, two orders of magnitude cheaper once the index exists.

> **Remember:** an index is a sorted shortcut to a row's location, built as a B-tree. It turns "check every row" into "check a handful of boundaries."

```knowledge-check
{ "questions": [
    { "id": "backend-databases-indexing-btree-q1", "type": "mcq",
      "prompt": "Why is a B-tree index faster than a sequential scan for finding one matching row in a big table?",
      "options": [
        {"id":"a","text":"It walks a tree of sorted keys and skips most of the table, instead of checking every row one by one"},
        {"id":"b","text":"It stores a second full copy of the table in memory"},
        {"id":"c","text":"It compresses the table so it takes up less disk space"},
        {"id":"d","text":"It only works on tables smaller than 1,000 rows"}
      ],
      "correct": "a",
      "explanation": "A B-tree narrows the search at every level, comparing against a handful of boundary values instead of reading every row. That is what turns a full scan into a small number of page reads." }
] }
```

## Selectivity: why an index does not always help

Not every column is worth indexing. Try the same trick on a column with only a few possible values:

```sql
CREATE INDEX idx_orders_status ON orders (status);

EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'paid';
-- Still a Seq Scan! About a quarter of all rows match "paid", so scanning
-- straight through is cheaper than jumping around the index for that many rows.
```

**Selectivity** is distinct values divided by total rows. `customer_id` has 5,000 distinct values across 100,000 rows: high selectivity, a great index candidate, because each lookup skips almost the entire table. `status` has 4 values across those same 100,000 rows: low selectivity, a poor index candidate alone, because a lookup still has to fetch a huge slice of the table.

```sql
SELECT
    count(DISTINCT status)::float / count(*) AS status_selectivity,      -- ~0.00004
    count(DISTINCT customer_id)::float / count(*) AS customer_selectivity -- ~0.05
FROM orders;
```

Rule of thumb: an index pays off when a query returns a small slice of the table, roughly under 10-15%. Above that, Postgres knows a straight scan beats jumping around an index, and it will quietly ignore your index. That's the planner doing its job, not a bug.

This same idea explains every case where an index is a bad idea:

| Situation | Why the index does not help |
|---|---|
| Low-selectivity column alone (a boolean, a small enum) | A lookup still touches most of the table |
| A small table | The whole table already fits in a few pages; the index adds overhead for nothing |
| A column written far more than it's read | Every write has to update every index on that column too |
| A wide text column, indexed whole | The index itself becomes huge; index only a prefix or use a trigram index instead |

> **Remember:** an index only pays for itself when it lets Postgres skip most of the table on a read. A column with only a few possible values usually fails that test on its own.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-indexing-selectivity-q1", "type": "mcq",
      "prompt": "A boolean column is filtered on its own in a WHERE clause. Why is a plain index on that column usually a weak choice?",
      "options": [
        {"id":"a","text":"Postgres cannot build an index on a boolean type at all"},
        {"id":"b","text":"With only two possible values, a lookup still has to fetch a large fraction of the table, so a sequential scan is often cheaper"},
        {"id":"c","text":"Boolean indexes take up more disk space than any other type"},
        {"id":"d","text":"Indexes only work on numeric columns"}
      ],
      "correct": "b",
      "explanation": "Selectivity is distinct values over total rows. A boolean has only two distinct values, so roughly half the table matches either one, which is far above the point where a scan beats an index." }
] }
```

## Reading EXPLAIN ANALYZE

`EXPLAIN ANALYZE` shows you exactly what Postgres did and how long it took. This is the tool you reach for before touching an index at all.

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

- **`cost=A..B`**: the planner's own estimate, in arbitrary units, not milliseconds.
- **`actual time=A..B`**: real measured milliseconds. Only appears with `ANALYZE`, which actually runs the query, so run it inside a transaction you roll back before trying it on a production `DELETE` or `UPDATE`.
- **`rows` estimated vs actual**: a big gap between them means Postgres's statistics are stale. Fix with `ANALYZE orders;`.
- **`Index Cond` vs `Filter`**: `Index Cond` is checked by the index itself, cheap. `Filter` is checked after fetching the row, more expensive. Here, `customer_id` narrows things down through the index, but `status` still has to be checked row by row afterward, because there's no single index covering both.
- **`Rows Removed by Filter`**: rows the index fetched and then threw away. A high number here is a sign a better index would help.

A composite index fixes exactly that last problem:

```sql
CREATE INDEX idx_orders_customer_status ON orders (customer_id, status);
-- now both conditions become Index Cond, and zero rows get removed by the filter
```

> **Remember:** `Index Cond` is cheap (checked by the index); `Filter` is expensive (checked after fetching the row). A high "rows removed by filter" number is your signal to widen the index.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-indexing-explain-q1", "type": "mcq",
      "prompt": "In EXPLAIN ANALYZE output, the estimated row count is 25,000 but the actual row count is 5. What does this gap usually mean?",
      "options": [
        {"id":"a","text":"The query has a syntax error"},
        {"id":"b","text":"The table's statistics are stale, so the planner's guess is off; running ANALYZE on the table refreshes them"},
        {"id":"c","text":"The index is corrupted and needs to be rebuilt"},
        {"id":"d","text":"This gap is normal and never worth investigating"}
      ],
      "correct": "b",
      "explanation": "The planner picks a plan based on statistics gathered by ANALYZE. When those statistics are old, its row estimates drift from reality, and it can pick a worse plan than the one actually available." }
] }
```

## Composite indexes and the leftmost prefix rule

A composite index is one index built over more than one column, in a fixed order. That order is not cosmetic: it decides which queries can use the index at all.

`CREATE INDEX ON orders (customer_id, status)` supports:
- A query filtering on `customer_id` alone.
- A query filtering on `customer_id` and `status` together.

It does **not** support a query filtering on `status` alone, because the index is sorted first by `customer_id`. Skipping straight to a given `status` value would mean jumping all over the index, not scanning a contiguous range, so Postgres can't use it that way. This is the **leftmost prefix rule**: a composite index only helps a query that filters starting from its leftmost column.

Think of it like a phone book sorted by last name, then first name. You can jump straight to "Smith," or to "Smith, John." You cannot jump straight to everyone named "John," because the book isn't sorted by first name at all.

> **Remember:** a composite index `(a, b)` serves queries on `a` alone or `a` and `b` together, never `b` alone. Column order is part of the index's design, not a detail you can swap freely.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-indexing-composite-q1", "type": "mcq",
      "prompt": "An index exists on (customer_id, status). Which query can it actually speed up?",
      "options": [
        {"id":"a","text":"WHERE status = 'paid'"},
        {"id":"b","text":"WHERE customer_id = 42"},
        {"id":"c","text":"Neither query can use this index"},
        {"id":"d","text":"Both queries equally"}
      ],
      "correct": "b",
      "explanation": "The leftmost prefix rule: a composite index on (customer_id, status) is sorted by customer_id first, so only a query that filters on customer_id (alone, or with status added) can use it." }
] }
```

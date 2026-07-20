---
kind: lesson
id_key: interview-prep-45/day-05-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 5 — PostgreSQL Query Optimization"
position: 5
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Yesterday was indexing; today is everything else the query planner does before it even gets to use one. You'll fix real N+1 patterns with JOINs, learn what the planner actually optimizes, and nail the WHERE-vs-HAVING and JOIN-type questions that come up in nearly every SQL round.

## How the query planner thinks

PostgreSQL doesn't execute SQL as written — it parses it into a query tree, then the **planner/optimizer** enumerates candidate execution plans (which index to use, which join algorithm, which join order) and picks the one with the lowest estimated cost, using table statistics gathered by `ANALYZE` (row counts, most-common values, histogram of value distribution).

Three join algorithms you should be able to name and reason about:

- **Nested Loop** — for each row in the outer table, scan the inner table (or an index on it) for matches. Cheap when the outer set is small or the inner side has a good index. Expensive when both sides are large and unindexed — it degrades toward `O(n*m)`.
- **Hash Join** — build an in-memory hash table from the smaller side, then probe it once per row of the larger side. Good for large, unsorted, unindexed joins; needs enough `work_mem` to avoid spilling to disk.
- **Merge Join** — both sides are sorted (or sorted via an explicit sort step) and merged in one pass. Good when both inputs are already sorted, e.g. via an index that matches the join key.

The planner picks based on estimated row counts and available indexes — this is why stale statistics (`ANALYZE` not run recently) can cause it to pick a bad plan even though the "right" plan is available.

## WHERE vs HAVING

`WHERE` filters rows **before** grouping/aggregation; `HAVING` filters groups **after** aggregation. This is a pure ordering-of-operations question and one of the most reliably asked SQL basics.

```sql
-- WHERE: filter rows before they're grouped
SELECT customer_id, SUM(total) AS spend
FROM orders
WHERE status = 'paid'          -- applied per-row, before grouping
GROUP BY customer_id
HAVING SUM(total) > 1000;      -- applied per-group, after aggregation
```

You cannot use an aggregate function in `WHERE` (`WHERE SUM(total) > 1000` is a syntax error) because at the point `WHERE` runs, rows haven't been grouped yet — there's nothing to sum. Conversely, `HAVING status = 'paid'` works but is wasteful: it aggregates every row first, including ones you'll throw away, instead of filtering them out before the (expensive) grouping step. Always push a per-row filter into `WHERE`.

## JOIN types

```sql
-- INNER JOIN: only rows with a match on both sides
SELECT o.id, c.name
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id;

-- LEFT JOIN: all rows from orders, NULLs for customers with no match
SELECT o.id, c.name
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id;

-- RIGHT JOIN: all rows from customers, NULLs for orders with no match (rare in practice — usually rewritten as a LEFT JOIN with tables swapped)
SELECT o.id, c.name
FROM orders o
RIGHT JOIN customers c ON o.customer_id = c.id;

-- FULL OUTER JOIN: all rows from both sides, NULLs where there's no match on either side
SELECT o.id, c.name
FROM orders o
FULL OUTER JOIN customers c ON o.customer_id = c.id;
```

A classic follow-up: **"find customers with zero orders"** — this is a `LEFT JOIN ... WHERE right_side IS NULL`, the standard anti-join pattern:

```sql
SELECT c.id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.id IS NULL;
```

## N+1 in raw SQL — same disease as the ORM version

```python
# N+1: one query for customers, then one query PER customer for their orders
customers = db.execute("SELECT id, name FROM customers WHERE active = true").fetchall()
for c in customers:
    orders = db.execute("SELECT * FROM orders WHERE customer_id = %s", [c["id"]]).fetchall()
    ...
```

Fixed with a single JOIN, then group the results in application code:

```python
rows = db.execute(
    """
    SELECT c.id AS customer_id, c.name, o.id AS order_id, o.total
    FROM customers c
    LEFT JOIN orders o ON o.customer_id = c.id
    WHERE c.active = true
    """
).fetchall()

from collections import defaultdict
by_customer = defaultdict(lambda: {"name": None, "orders": []})
for row in rows:
    entry = by_customer[row["customer_id"]]
    entry["name"] = row["name"]
    if row["order_id"] is not None:
        entry["orders"].append({"id": row["order_id"], "total": row["total"]})
```

This trades N+1 round trips for exactly 1, at the cost of some row duplication over the wire (each order row repeats the customer's name) and a grouping step in Python. For most read paths that's a clear win — measure before assuming it always is; a JOIN that fans out into millions of duplicated rows can be worse than two well-indexed queries.

## Measuring the fix

```sql
-- Before: N+1 pattern timed manually
EXPLAIN ANALYZE SELECT id, name FROM customers WHERE active = true;          -- ~0.5ms
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;                  -- ~0.1ms, times 500 customers = 50ms+ in round trips alone

-- After: single JOIN
EXPLAIN ANALYZE
SELECT c.id, c.name, o.id, o.total
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE c.active = true;
-- One query, ~2-5ms total even with the join — because network round-trip latency (the dominant
-- cost of N+1 at 500 separate queries) is eliminated, not just the per-query execution time.
```

The number that matters in an interview answer isn't query *execution* time — it's round trips. 500 queries at 0.5ms execution each but 2ms network latency each is 1.25 seconds of wall-clock time; one JOIN query is single-digit milliseconds even if its own execution cost is higher than any individual N+1 query.

## Key takeaways

- The planner picks a join algorithm (nested loop, hash, merge) based on estimated cardinality and available indexes — stale statistics can make it pick wrong even when a good plan exists.
- `WHERE` filters rows before grouping; `HAVING` filters groups after aggregation — never put a per-row condition in `HAVING`.
- `LEFT JOIN ... WHERE right.col IS NULL` is the standard anti-join pattern for "find X with no matching Y."
- N+1 in raw SQL is the same bug as N+1 in an ORM — fix it the same way, with a JOIN and application-side grouping.
- The real cost of N+1 is round-trip latency multiplied by query count, not per-query execution time — that's the number to quote when explaining the fix's impact.

## Today's checklist

- [ ] Read: query planner internals
- [ ] Analyze slow queries from your own projects with `EXPLAIN ANALYZE`
- [ ] Write a query with and without JOIN optimization
- [ ] Create queries with N+1 problems
- [ ] Fix using JOINs and measure the improvement
- [ ] Be ready to answer: what is the difference between WHERE and HAVING? Explain the JOIN types.

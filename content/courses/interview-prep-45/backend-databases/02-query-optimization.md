---
kind: lesson
id_key: interview-prep-45/day-05-backend
course: interview-prep-45
section: backend-databases
section_title: "Databases (PostgreSQL)"
section_position: 9
section_group: "Backend"
title: "Query Optimization"
position: 2
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
---

An index only helps if the query around it is written well. This lesson covers what Postgres does with your SQL before it ever touches an index: how it picks a join strategy, the WHERE-vs-HAVING trap, and the N+1 pattern that shows up in nearly every backend interview.

## How the query planner picks a plan

Postgres never runs your SQL as written. It parses it into a tree, then its **planner** looks at several possible ways to execute that tree (which index to use, which join order, which join algorithm) and picks the one it estimates is cheapest, based on statistics gathered by `ANALYZE`: row counts, common values, and a histogram of how values are spread out.

Three join algorithms come up constantly in interviews:

| Algorithm | How it works | Good fit |
|---|---|---|
| **Nested loop** | For each row on one side, scan (or index-lookup) the other side for matches | The outer side is small, or the inner side has a good index |
| **Hash join** | Build an in-memory hash table from the smaller side, then probe it once per row on the larger side | Large, unindexed, unsorted inputs, given enough working memory |
| **Merge join** | Both sides are already sorted (or get sorted), then merged in one pass | Both inputs are already sorted, often via an index |

Stale statistics are why the planner sometimes picks a worse plan even when a better one is available: it's reasoning about row counts that no longer match reality.

> **Remember:** the planner picks a plan from row-count estimates, not from your SQL's shape. Stale statistics (an old `ANALYZE`) are the classic reason it picks the wrong one.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-optimization-planner-q1", "type": "mcq",
      "prompt": "A hash join is generally the right choice when...",
      "options": [
        {"id":"a","text":"Both inputs are already sorted on the join key"},
        {"id":"b","text":"The inputs are large, unsorted, and unindexed, and there's enough working memory to build a hash table from the smaller side"},
        {"id":"c","text":"The outer table has only one row"},
        {"id":"d","text":"The join has no matching rows at all"}
      ],
      "correct": "b",
      "explanation": "A hash join builds an in-memory hash table from the smaller side and probes it once per row on the larger side, which works well precisely when there's no existing sort or index to exploit." }
] }
```

## WHERE filters rows, HAVING filters groups

`WHERE` runs **before** rows are grouped. `HAVING` runs **after** aggregation. This ordering, not the keywords themselves, is what nearly every SQL interview question about the two is really testing.

```sql
SELECT customer_id, SUM(total) AS spend
FROM orders
WHERE status = 'paid'          -- per-row, before grouping
GROUP BY customer_id
HAVING SUM(total) > 1000;      -- per-group, after aggregation
```

`WHERE SUM(total) > 1000` is an error, because at the point `WHERE` runs, rows have not been grouped yet, so there is nothing to sum. `HAVING status = 'paid'` fails too in Postgres, because `status` is not in the `GROUP BY`. Even if you add it to the `GROUP BY`, it's wasteful: the database groups every row, including the ones you'll throw away. Always put a per-row filter in `WHERE`.

The same rule explains a classic `GROUP BY` error. After grouping, each output row stands for many input rows. So every column you select must either be in the `GROUP BY` list or be wrapped in an aggregate like `COUNT`, `SUM` or `AVG`. Postgres rejects the query otherwise. Older MySQL (non-strict mode) runs it and quietly returns a value from some random row in the group, which is worse.

> **Remember:** `WHERE` runs before grouping and can't see an aggregate; `HAVING` runs after grouping and filters the groups themselves. Put per-row filters in `WHERE`.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-optimization-having-q1", "type": "mcq",
      "prompt": "Why does WHERE SUM(total) > 1000 fail with a syntax error?",
      "options": [
        {"id":"a","text":"SUM is spelled wrong in Postgres"},
        {"id":"b","text":"WHERE runs before rows are grouped, so there is nothing yet to sum at that point"},
        {"id":"c","text":"Aggregate functions can never be used in SQL"},
        {"id":"d","text":"WHERE only accepts text comparisons"}
      ],
      "correct": "b",
      "explanation": "WHERE filters individual rows before GROUP BY runs. An aggregate like SUM only makes sense once rows are grouped, which is why that check belongs in HAVING instead." }
] }
```

## Join types, and finding "customers with no orders"

```sql
-- INNER JOIN: only rows that match on both sides
SELECT o.id, c.name FROM orders o INNER JOIN customers c ON o.customer_id = c.id;

-- LEFT JOIN: every row from orders, NULL for customers with no match
SELECT o.id, c.name FROM orders o LEFT JOIN customers c ON o.customer_id = c.id;

-- FULL OUTER JOIN: every row from both sides, NULL wherever there's no match
SELECT o.id, c.name FROM orders o FULL OUTER JOIN customers c ON o.customer_id = c.id;
```

`RIGHT JOIN` exists too, but it's rare in practice: it's almost always rewritten as a `LEFT JOIN` with the tables swapped, which reads more naturally.

A classic follow-up, "find every customer with zero orders," is the standard **anti-join** pattern: left join, then filter for the side that came back empty.

```sql
SELECT c.id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.id IS NULL;
```

> **Remember:** "rows with no match" is a LEFT JOIN plus `WHERE right_side.id IS NULL`. That pattern, not a subquery, is the standard anti-join.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-optimization-join-q1", "type": "mcq",
      "prompt": "What is the standard way to find every customer who has placed zero orders?",
      "options": [
        {"id":"a","text":"INNER JOIN customers to orders, then count"},
        {"id":"b","text":"LEFT JOIN customers to orders, then filter WHERE the order side's key IS NULL"},
        {"id":"c","text":"RIGHT JOIN orders to customers with no filter"},
        {"id":"d","text":"There is no way to express this in SQL"}
      ],
      "correct": "b",
      "explanation": "A LEFT JOIN keeps every customer row even without a matching order, filling the order columns with NULL. Filtering for that NULL isolates exactly the customers with no match: the anti-join pattern." }
] }
```

## N+1 queries: the same disease with or without an ORM

An N+1 pattern is one query to fetch a list, then one more query per item in that list. It happens in raw SQL just as easily as through an ORM.

```python
# N+1: one query for customers, then one MORE query per customer
customers = db.execute("SELECT id, name FROM customers WHERE active = true").fetchall()
for c in customers:
    orders = db.execute("SELECT * FROM orders WHERE customer_id = %s", [c["id"]]).fetchall()
```

The fix is a single JOIN, with the grouping done afterward in application code:

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

This trades 500 round trips for exactly one, at the cost of some duplicated data over the wire (each order row repeats its customer's name) and a small grouping step in Python. For most read paths that's a clear win, but measure rather than assume: a join that fans out into millions of duplicated rows can end up worse than two well-indexed queries.

The number that actually matters here is not query *execution* time, it's round trips. 500 queries at 0.5ms execution but 2ms of network latency each adds up to over a second of wall-clock time. One JOIN query, even if its own execution cost is higher than any single N+1 query, finishes in single-digit milliseconds because it pays that network cost exactly once.

> **Remember:** N+1 is one query, then one more per row of the result. The fix is a single JOIN; the win comes from cutting round trips, not from making any one query faster.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-optimization-n1-q1", "type": "mcq",
      "prompt": "500 customers are fetched, then one extra query runs per customer to get their orders. What is the real cost of this pattern?",
      "options": [
        {"id":"a","text":"The per-query execution time, which is usually the dominant cost"},
        {"id":"b","text":"The network round trip repeated 500 times, which usually dwarfs each query's own execution time"},
        {"id":"c","text":"Nothing; databases handle this pattern efficiently on their own"},
        {"id":"d","text":"The extra disk space used by 500 separate queries"}
      ],
      "correct": "b",
      "explanation": "Each query might execute in under a millisecond, but the round trip to the database is paid 500 times. A single JOIN pays that round-trip cost once, which is why it wins even when its own execution is more expensive than any individual N+1 query." }
] }
```

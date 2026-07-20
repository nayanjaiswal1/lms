---
kind: lesson
id_key: interview-prep-45/day-02-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 2 — Django ORM Internals"
position: 2
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
The Django ORM hides SQL from you until it doesn't — and the interview questions live exactly at that seam. Today you learn what `QuerySet.filter()` actually does, why it's lazy, how to read the SQL it generates, and how to kill the N+1 queries that show up in almost every backend take-home review.

## QuerySets are lazy — nothing runs until you iterate

`Model.objects.filter(...)` does not hit the database. It builds a `QuerySet` object that holds a `Query` (an internal SQL-building AST). The SQL is only compiled and executed when the QuerySet is **evaluated** — which happens on:

- Iteration (`for obj in qs`, `list(qs)`)
- Slicing with a step, or converting to `list()`/`bool()`/`len()`
- `repr()` (which is why `qs` printed in a shell looks like it "ran")
- Calling `.get()`, `.count()`, `.exists()`, `.aggregate()` — these each generate a *different* SQL query, not just evaluate the existing one

```python
qs = User.objects.filter(is_active=True)   # no query yet
qs = qs.filter(created_at__gte=some_date)  # still no query — chains just merge into the same Query object
print(qs.query)                             # generates and prints SQL, but does NOT execute it against the DB
users = list(qs)                            # <-- query actually executes here
```

**Interview trap:** `qs.count()` does *not* reuse the query from a prior `list(qs)` call — each triggers its own round trip unless you cache the QuerySet result. `if qs: ...` calls `__bool__`, which internally does `self._fetch_all()` — so checking truthiness of a QuerySet still evaluates it (though Django optimizes `.exists()` into a cheap `SELECT 1 LIMIT 1` if you call it explicitly instead).

## Reading generated SQL vs writing raw SQL

```python
# ORM
qs = Order.objects.filter(status="paid", total__gt=100).select_related("customer")
print(qs.query)
```

```sql
-- Roughly what Django generates
SELECT "orders_order"."id", "orders_order"."status", "orders_order"."total",
       "orders_customer"."id", "orders_customer"."name"
FROM "orders_order"
INNER JOIN "orders_customer" ON ("orders_order"."customer_id" = "orders_customer"."id")
WHERE ("orders_order"."status" = 'paid' AND "orders_order"."total" > 100)
```

For anything the ORM can't express cleanly (window functions, complex CTEs, vendor-specific hints), drop to raw SQL — but stay inside the ORM's connection/transaction management:

```python
from django.db import connection

def top_customers_by_spend(limit=10):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT customer_id, SUM(total) AS spend
            FROM orders_order
            WHERE status = %s
            GROUP BY customer_id
            ORDER BY spend DESC
            LIMIT %s
            """,
            ["paid", limit],
        )
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]
```

Always use parameterized placeholders (`%s`), never f-strings — that's a straight SQL-injection flag in a code review.

## EXPLAIN ANALYZE from the ORM

```python
qs = Order.objects.filter(status="paid").select_related("customer")
print(qs.explain(analyze=True))
```

This runs `EXPLAIN ANALYZE` against the actual generated SQL and prints PostgreSQL's plan — look for `Seq Scan` on a large table (missing index), `Nested Loop` with a high row estimate mismatch (stale statistics), or `Hash Join` vs `Nested Loop` choice on your `select_related` join.

## select_related vs prefetch_related — the N+1 fix

This pair is asked in nearly every Django interview. The difference is the join strategy:

| | `select_related` | `prefetch_related` |
|---|---|---|
| Works on | Forward FK / OneToOne | Reverse FK / ManyToMany / anything |
| Mechanism | SQL `JOIN`, single query | Separate query per relation, joined in Python |
| Query count | 1 | 2+ (one per prefetched relation) |
| Use when | "One row has one related row" | "One row has many related rows" |

```python
# N+1 problem: 1 query for orders, then 1 query PER order to fetch customer
orders = Order.objects.filter(status="paid")
for order in orders:
    print(order.customer.name)  # <-- hits the DB every iteration

# Fixed with select_related: single JOIN query, customer is already loaded
orders = Order.objects.filter(status="paid").select_related("customer")
for order in orders:
    print(order.customer.name)  # no extra query

# Reverse/M2M relation: prefetch_related runs a second query and stitches results in Python
orders = Order.objects.prefetch_related("line_items")
for order in orders:
    for item in order.line_items.all():  # no extra query — already fetched
        print(item.sku)
```

## Building the demo: 1000 records, compare query counts

```python
# Setup — run once in a management command or shell_plus
import random
from myapp.models import Customer, Order

customers = Customer.objects.bulk_create(
    [Customer(name=f"Customer {i}") for i in range(200)]
)
Order.objects.bulk_create(
    [
        Order(customer=random.choice(customers), status="paid", total=random.randint(10, 500))
        for _ in range(1000)
    ]
)
```

```python
from django.test.utils import CaptureQueriesContext
from django.db import connection

with CaptureQueriesContext(connection) as ctx:
    orders = list(Order.objects.filter(status="paid"))
    for o in orders:
        _ = o.customer.name
print(len(ctx.captured_queries))  # ~ 1 + N

with CaptureQueriesContext(connection) as ctx:
    orders = list(Order.objects.filter(status="paid").select_related("customer"))
    for o in orders:
        _ = o.customer.name
print(len(ctx.captured_queries))  # 1
```

`CaptureQueriesContext` is the standard tool for asserting query counts in tests — pair it with `assertNumQueries` in Django's test framework to catch N+1 regressions in CI, not just in manual profiling.

## Key takeaways

- QuerySets build a lazy SQL AST; nothing executes until iteration, `bool()`, `len()`, or a terminal method like `.get()`/`.count()`/`.exists()`.
- `.count()` and `.exists()` each issue their own optimized query — they don't reuse a previously evaluated QuerySet's results.
- `select_related` = SQL JOIN, one query, forward/one-to-one relations. `prefetch_related` = extra queries stitched in Python, for reverse/many-to-many relations.
- `qs.explain(analyze=True)` runs real `EXPLAIN ANALYZE` against generated SQL — use it before guessing which index is missing.
- Raw SQL via `connection.cursor()` is fine for the ORM's blind spots — always parameterize with `%s`, never string-format user input into a query.
- `CaptureQueriesContext` / `assertNumQueries` turns "I checked N+1 once" into a regression test.

## Today's checklist

- [ ] Read: Django ORM query execution flow
- [ ] Implement: write raw SQL and compare with ORM-generated SQL
- [ ] Implement: run `EXPLAIN ANALYZE` on a complex query
- [ ] Create a model with 1000 records
- [ ] Write a query using `select_related` and `prefetch_related`
- [ ] Compare query counts with `CaptureQueriesContext`
- [ ] Be ready to answer: what happens when you call `Model.objects.filter()`? What is lazy evaluation in the Django ORM?

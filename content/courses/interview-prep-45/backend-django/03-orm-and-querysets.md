---
kind: lesson
id_key: interview-prep-45/day-02-backend
course: interview-prep-45
section: backend-django
section_title: "Django"
section_position: 7
section_group: "Backend"
title: "Django ORM and Querysets"
position: 3
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

The Django ORM hides SQL from you, right up until the moment it doesn't. Almost every Django interview question lives at that seam: what `QuerySet.filter()` actually does, why it waits before running anything, how to read the SQL it builds, and how to kill the N+1 queries that show up in nearly every backend code review.

## Querysets are lazy: nothing runs until you ask for the data

Think of a queryset as a recipe card, not a cooked meal. Writing the recipe down and even editing it doesn't put food on the table. Only when someone actually asks to eat does the cooking happen.

```python
qs = Book.objects.filter(published=True)   # no query yet -- just a recipe
qs = qs.filter(author__country="US")        # still no query -- refines the same recipe
qs = qs.order_by("-created_at")              # still no query

for book in qs:            # <-- THIS triggers the query
    print(book.title)
```

Each `.filter()`/`.order_by()` call returns a *new* queryset rather than mutating one in place, so chaining them just keeps building up the same underlying description. The database is only actually hit when the queryset gets evaluated: on iteration (`for`, `list(qs)`), on slicing with a step, on `len()` or `bool()`/`if qs:`, on `repr()` (which is why a queryset printed in a shell "looks like it ran"), and on terminal methods like `.get()`, `.count()`, `.exists()`, `.first()`, each of which builds and runs its own SQL rather than reusing a previous query.

Two traps worth knowing cold:

- `if qs:` and `len(qs)` both trigger a full query and pull every row into memory just to check truthiness or count. For an existence check, call `.exists()` directly instead: it becomes a cheap `SELECT 1 ... LIMIT 1`.
- Once a queryset is evaluated, it **caches its results**, so looping over it twice only queries once. But calling `.filter(...)` on an already-evaluated queryset builds a brand-new, uncached queryset. Re-filtering instead of reusing the existing result is a common source of accidental duplicate queries.

Because building a queryset never touches the database, you can also assemble one conditionally across several `if` branches, adding a `.filter(...)` in each, and the database still only gets hit once, at the very end, when something finally consumes the result.

> **Remember:** a queryset is a description of a query, not the result. It only runs when you iterate it, count it, check truthiness, or call a terminal method.

```knowledge-check
{ "questions": [
    { "id": "backend-django-orm-lazy-q1", "type": "mcq",
      "prompt": "Why does `if my_queryset:` still hit the database even though you only wanted to check truthiness?",
      "options": [
        {"id":"a","text":"It doesn't; checking a queryset's truthiness never touches the database"},
        {"id":"b","text":"bool(queryset) forces full evaluation, pulling every matching row into memory just to check if the list is non-empty; .exists() is the cheap alternative"},
        {"id":"c","text":"Django caches the result from the last query and reuses it"},
        {"id":"d","text":"Only slicing triggers evaluation, not truthiness checks"}
      ],
      "correct": "b",
      "explanation": "A queryset's __bool__ calls _fetch_all() internally, which runs the full query. .exists() is the version built to answer this specific question cheaply, as a SELECT 1 LIMIT 1." }
] }
```

## Reading the generated SQL, and dropping to raw SQL when you need to

```python
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

For anything the ORM can't express cleanly, window functions, complex CTEs, vendor-specific hints, drop to raw SQL, but stay inside the ORM's own connection and transaction management instead of opening a separate connection:

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

Always pass values through parameterized placeholders (`%s`), never build the query with an f-string. An f-string here is a straight SQL-injection finding in any code review.

To see how Postgres actually plans a query, run it through the ORM's own explain:

```python
qs = Order.objects.filter(status="paid").select_related("customer")
print(qs.explain(analyze=True))
```

This runs `EXPLAIN ANALYZE` against the real generated SQL. Watch for a `Seq Scan` on a large table (usually a missing index), a `Nested Loop` whose estimated row count is far off from the actual count (stale table statistics), or which join strategy Postgres picked for your `select_related` join.

> **Remember:** `qs.query` shows you the SQL a queryset will run; `qs.explain(analyze=True)` shows you how the database actually plans to run it.

```knowledge-check
{ "questions": [
    { "id": "backend-django-orm-rawsql-q1", "type": "mcq",
      "prompt": "Why is `cursor.execute(sql, [param])` safe while building the same query with an f-string is not?",
      "options": [
        {"id":"a","text":"There is no real difference; both are equally safe"},
        {"id":"b","text":"Parameterized placeholders send the value separately from the query structure, so a malicious value can't change what SQL actually runs; an f-string pastes the value directly into the query text"},
        {"id":"c","text":"f-strings are simply slower to execute"},
        {"id":"d","text":"cursor.execute() automatically escapes every character in the entire query"}
      ],
      "correct": "b",
      "explanation": "Parameterized queries keep user-controlled data out of the SQL text itself, which is what actually prevents SQL injection. An f-string mixes untrusted data into the query structure, letting crafted input change the query's meaning." }
] }
```

## select_related vs prefetch_related: the N+1 fix

This pair is asked in nearly every Django interview, and the difference comes down to the join strategy.

| | `select_related` | `prefetch_related` |
|---|---|---|
| Works on | Forward `ForeignKey`/`OneToOne` | `ManyToMany`, reverse `ForeignKey`, anything multi-valued |
| Mechanism | One SQL `JOIN` | A separate query per relation, stitched together in Python |
| Query count | 1 | 2 or more, one per prefetched relation |
| Use when | "One row has one related row" | "One row has many related rows" |

```python
# N+1 problem: 1 query for orders, then 1 query PER order to fetch its customer
orders = Order.objects.filter(status="paid")
for order in orders:
    print(order.customer.name)  # <-- hits the database every iteration

# Fixed with select_related: a single JOIN query, customer is already loaded
orders = Order.objects.filter(status="paid").select_related("customer")
for order in orders:
    print(order.customer.name)  # no extra query

# Reverse/M2M relation: prefetch_related runs a second query and stitches in Python
orders = Order.objects.prefetch_related("line_items")
for order in orders:
    for item in order.line_items.all():  # no extra query -- already fetched
        print(item.sku)
```

The reason `select_related` can't be used for a "many" relation is structural, not a missing feature: you can't `JOIN` a one-to-many relation into a single row per parent without duplicating the parent's own columns once per child. `prefetch_related` avoids that by running a flat, separate query and matching things up afterward in Python. You can combine and nest both in one call: `Book.objects.select_related("author").prefetch_related("tags", "reviews__reviewer")`, where the double underscore prefetches a relation of a relation.

> **Remember:** in one sentence, N+1 is "one query for the list, plus one more query per row for something related to it." `select_related` collapses that into one JOIN for single-valued relations; `prefetch_related` collapses it into a fixed, small number of queries for multi-valued relations.

```knowledge-check
{ "questions": [
    { "id": "backend-django-orm-nplus1-q1", "type": "mcq",
      "prompt": "A loop over orders reads order.customer.name, and customer is a ForeignKey. Which fix collapses this into a single query?",
      "options": [
        {"id":"a","text":".prefetch_related(\"customer\")"},
        {"id":"b","text":".select_related(\"customer\"), which JOINs the customer row into the same query"},
        {"id":"c","text":"Calling .exists() before the loop"},
        {"id":"d","text":"There is no way to avoid one query per order for a ForeignKey"}
      ],
      "correct": "b",
      "explanation": "customer is a forward, single-valued relation (ForeignKey), which is exactly what select_related is for: one JOIN, one query total, instead of one extra query per row." }
] }
```

## Custom queryset methods and managers

Encapsulate a reusable filter as a queryset method instead of scattering the same `.filter(status="published", deleted_at__isnull=True)` across the codebase every time you need it.

```python
from django.db import models

class BookQuerySet(models.QuerySet):
    def published(self):
        return self.filter(status="published", deleted_at__isnull=True)

    def by_author(self, author):
        return self.filter(author=author)

    def with_review_stats(self):
        return self.annotate(
            avg_rating=models.Avg("reviews__rating"),
            review_count=models.Count("reviews"),
        )

class BookManager(models.Manager.from_queryset(BookQuerySet)):
    def get_queryset(self):
        # applied to every query through this manager, including .filter()/.all()
        return super().get_queryset().select_related("author")

class Book(models.Model):
    title = models.CharField(max_length=255)
    status = models.CharField(max_length=20, default="draft")
    deleted_at = models.DateTimeField(null=True, blank=True)
    author = models.ForeignKey("Author", on_delete=models.CASCADE)

    objects = BookManager()
```

`Manager.from_queryset(BookQuerySet)` is the idiomatic way to make custom queryset methods usable both directly on the manager (`Book.objects.published()`) and chained after any other queryset method (`Book.objects.by_author(a).published()`). Writing the methods straight on a `Manager` subclass instead loses that chainability, since a manager method returns whatever type it explicitly returns, not automatically another manager you can keep chaining off of.

> **Remember:** put reusable filters on a custom `QuerySet`, wired up via `Manager.from_queryset(...)`. That keeps them chainable everywhere, instead of copy-pasting the same filter across the codebase.

```knowledge-check
{ "questions": [
    { "id": "backend-django-orm-manager-q1", "type": "mcq",
      "prompt": "Why use Manager.from_queryset(BookQuerySet) instead of defining published() directly as a method on a plain Manager subclass?",
      "options": [
        {"id":"a","text":"It's required; a plain Manager cannot have any custom methods at all"},
        {"id":"b","text":"It keeps the method chainable both on the manager and after any other queryset method, since a plain Manager method loses that chaining"},
        {"id":"c","text":"It runs the query faster"},
        {"id":"d","text":"It automatically adds caching to every query"}
      ],
      "correct": "b",
      "explanation": "from_queryset makes the custom methods available on the resulting QuerySet type itself, so you can chain Book.objects.by_author(a).published(). A method defined only on the Manager can't be chained after another queryset method that way." }
] }
```

## bulk_create and its limits

`bulk_create` builds one, or a few batched, `INSERT` statements for many model instances instead of issuing one `INSERT` per `.save()`.

```python
Book.objects.bulk_create([
    Book(title="Clean Code", author=author, status="published"),
    Book(title="Refactoring", author=author, status="published"),
    Book(title="DDIA", author=author, status="published"),
], batch_size=500)
```

What interviewers expect you to know about its edges:

- **`save()` is never called.** No `pre_save`/`post_save` signals fire, and any custom `save()` override is skipped entirely.
- **`pk` isn't always populated back on the instances you passed in**, on databases that don't support returning generated IDs from a bulk insert. Postgres and modern SQLite do populate `pk` since Django 4.0.
- **`batch_size` matters.** Without it, Django sends one `INSERT` covering every row, which can hit a database's parameter limit or just become one huge statement; batching splits the work into chunks.
- **It doesn't handle conflicts by default.** A duplicate key aborts the whole batch (or the batch containing it), unless you pass `update_conflicts=True` with `unique_fields`/`update_fields` (Django 4.1+) to turn it into an upsert.

> **Remember:** `bulk_create` skips `save()` entirely, so any logic living in a custom `save()` override or a `post_save` signal never runs for those rows.

```knowledge-check
{ "questions": [
    { "id": "backend-django-orm-bulkcreate-q1", "type": "mcq",
      "prompt": "A model has a post_save signal that sends a welcome email. You create 500 users with bulk_create. What happens to the emails?",
      "options": [
        {"id":"a","text":"All 500 emails are sent, exactly as if .save() had been called 500 times"},
        {"id":"b","text":"None are sent, because bulk_create never calls save() and so never fires post_save signals"},
        {"id":"c","text":"Only the first email in the batch is sent"},
        {"id":"d","text":"bulk_create raises an error whenever a post_save signal exists"}
      ],
      "correct": "b",
      "explanation": "bulk_create builds INSERT statements directly, bypassing save() and every signal that hangs off of it. Any logic that must run per row needs to run explicitly, not rely on save()-triggered signals." }
] }
```

## Finding and fixing an N+1 query in practice

The bug, as it typically shows up in a codebase or an interview snippet:

```python
# N+1: 1 query for books, then 1 additional query PER book for its author
def book_list_view(request):
    books = Book.objects.filter(status="published")
    return render(request, "books.html", {
        "books": [{"title": b.title, "author": b.author.name} for b in books]
        # b.author triggers a query every iteration -- that's the +N
    })
```

Diagnose it before guessing at a fix, using Django Debug Toolbar's SQL panel in development, or `CaptureQueriesContext` in a shell or test:

```python
from django.test.utils import CaptureQueriesContext
from django.db import connection

with CaptureQueriesContext(connection) as ctx:
    orders = list(Order.objects.filter(status="paid"))
    for o in orders:
        _ = o.customer.name
print(len(ctx.captured_queries))  # roughly 1 + N

with CaptureQueriesContext(connection) as ctx:
    orders = list(Order.objects.filter(status="paid").select_related("customer"))
    for o in orders:
        _ = o.customer.name
print(len(ctx.captured_queries))  # 1
```

The fix mirrors the diagnosis:

```python
def book_list_view(request):
    books = Book.objects.filter(status="published").select_related("author")
    return render(request, "books.html", {
        "books": [{"title": b.title, "author": b.author.name} for b in books]
        # b.author now reads from the already-joined row -- 1 query total
    })
```

If the view also needs each book's tags (`ManyToMany`), add `.prefetch_related("tags")`: that turns "1 plus N" (books) into 2 total queries (books, and all tags for all books in one `IN (...)` query), instead of "1 plus N plus M".

The fastest way to prove a fix actually worked, and to catch a regression before it ships, is `CaptureQueriesContext` paired with Django's `assertNumQueries` in a test: assert the exact query count for the view or function, and any future change that reintroduces an N+1 fails the test immediately, instead of only showing up as a slow endpoint in production weeks later.

> **Remember:** count queries before declaring a fix works, and pin that count with `assertNumQueries` in a test. Eyeballing the code and assuming it's fixed is how N+1 regressions slip back in.

```knowledge-check
{ "questions": [
    { "id": "backend-django-orm-testnplus1-q1", "type": "mcq",
      "prompt": "What is the most reliable way to catch an N+1 regression in CI before it ships?",
      "options": [
        {"id":"a","text":"Manually reviewing the diff for any .filter() calls"},
        {"id":"b","text":"A test using assertNumQueries (or CaptureQueriesContext) that pins the exact expected query count for the code path"},
        {"id":"c","text":"Running the app locally once and checking it feels fast"},
        {"id":"d","text":"Relying on production monitoring to catch it after deploy"}
      ],
      "correct": "b",
      "explanation": "A query-count assertion in a test fails immediately if a future change removes a select_related/prefetch_related and reintroduces N+1, catching it in CI instead of as a slow endpoint discovered later in production." }
] }
```

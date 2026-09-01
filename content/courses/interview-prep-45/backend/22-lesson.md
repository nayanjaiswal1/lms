---
kind: lesson
id_key: interview-prep-45/day-22-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Django ORM Querysets"
position: 22
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
The N+1 query problem is the single most common Django interview exercise. Every senior candidate is expected to spot it in a code snippet and fix it without a hint. Today covers how querysets actually execute (lazy evaluation), custom querysets and managers, `select_related`/`prefetch_related`, `bulk_create`, and hands-on N+1 elimination.

## Queryset internals: lazy evaluation

A Django `QuerySet` doesn't hit the database when you build it. It's a lazily-evaluated description of a query, built up by chaining `.filter()`, `.exclude()`, `.order_by()`, etc. Each of those methods returns a *new* queryset (querysets are immutable in this sense) rather than mutating and executing.

```python
qs = Book.objects.filter(published=True)   # no query yet
qs = qs.filter(author__country="US")        # still no query — refines the same lazy queryset
qs = qs.order_by("-created_at")              # still no query

for book in qs:            # <-- THIS triggers the query
    print(book.title)
```

A queryset actually hits the database on: iteration (`for`, list/tuple conversion), slicing with a step or negative index, `len()`, `bool()`/`if qs:`, `repr()` (which is why the Django shell "runs" a queryset, since it's printing it), and terminal methods like `.get()`, `.count()`, `.exists()`, `.first()`.

Two traps interviewers check for:

- `if qs:` and `len(qs)` both trigger a full query and load results into memory. For an existence check, `.exists()` is a `SELECT 1 ... LIMIT 1`, far cheaper.
- Once evaluated, a queryset **caches its results**, so iterating it twice only queries once. But `qs.filter(...)` off an already-evaluated queryset creates a fresh, uncached queryset. This is a classic source of accidental duplicate queries when code re-filters instead of reusing.

## Custom queryset methods and managers

Encapsulate reusable filters as queryset methods instead of scattering `.filter(status="published", deleted_at__isnull=True)` across the codebase.

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

`Manager.from_queryset(BookQuerySet)` is the idiomatic way to get custom queryset methods usable both on the manager (`Book.objects.published()`) and chained after any other queryset method (`Book.objects.by_author(a).published()`). Writing the methods directly on a `Manager` subclass loses that chainability, since a manager's methods return whatever they explicitly return, not automatically another manager.

## select_related vs prefetch_related

**What is select_related vs prefetch_related?** This is the question that appears in nearly every Django interview.

- **`select_related`**: for `ForeignKey`/`OneToOne` (single-valued "forward" relations). Does a SQL `JOIN` and pulls the related row's columns into the *same* query. One query total.
- **`prefetch_related`**: for `ManyToMany` and reverse `ForeignKey` (multi-valued relations). Runs a **separate** query for the related objects, then joins them in Python by matching foreign keys. Two (or more) queries total, but each query stays flat: you can't `JOIN` a "many" relation into one row per parent without duplicating parent data per child.

```python
# select_related: 1 query, JOINs author into the same SELECT
books = Book.objects.select_related("author").filter(status="published")
for book in books:
    print(book.author.name)   # no extra query — already joined

# prefetch_related: 2 queries — one for books, one for all their tags at once
books = Book.objects.prefetch_related("tags").filter(status="published")
for book in books:
    print([t.name for t in book.tags.all()])   # no extra query — prefetched
```

You can combine and nest both: `Book.objects.select_related("author").prefetch_related("tags", "reviews__reviewer")`. The double-underscore in `reviews__reviewer` prefetches a relation *of* a relation.

## bulk_create

**How does bulk_create work?** It builds one (or a few, batched) `INSERT` statement for multiple model instances instead of issuing one `INSERT` per `.save()`.

```python
Book.objects.bulk_create([
    Book(title="Clean Code", author=author, status="published"),
    Book(title="Refactoring", author=author, status="published"),
    Book(title="DDIA", author=author, status="published"),
], batch_size=500)
```

What interviewers expect you to know about its limits:

- **`save()` is not called.** No `pre_save`/`post_save` signals fire, and any custom `save()` override logic is skipped.
- **On most backends, no per-object `pk` is returned** on databases that don't support `RETURNING` in bulk (older MySQL); Postgres and modern SQLite do populate `pk` on the passed-in instances since Django 4.0+.
- **`batch_size` matters.** Without it, Django sends one INSERT with all rows, which can hit a database's parameter limit or just be a huge single statement; batching splits it into chunks.
- **Doesn't handle conflicts by default.** Use `update_conflicts=True` with `unique_fields`/`update_fields` (Django 4.1+) for an upsert, otherwise a duplicate key aborts the whole batch (or the batch containing it).

## Implementation: finding and fixing an N+1 query

The bug, as it typically shows up in a codebase or an interview snippet:

```python
# N+1: 1 query for books, then 1 additional query PER book for its author
def book_list_view(request):
    books = Book.objects.filter(status="published")
    return render(request, "books.html", {
        "books": [{"title": b.title, "author": b.author.name} for b in books]
        # b.author triggers a query every iteration — that's the +N
    })
```

Diagnose it first instead of guessing, using Django Debug Toolbar's SQL panel, or in a shell/test:

```python
from django.test.utils import CaptureQueriesContext
from django.db import connection

with CaptureQueriesContext(connection) as ctx:
    list(book_list_view_queryset())
print(len(ctx.captured_queries))   # N+1 shows up as len(books) + 1
```

The fix:

```python
def book_list_view(request):
    books = Book.objects.filter(status="published").select_related("author")
    return render(request, "books.html", {
        "books": [{"title": b.title, "author": b.author.name} for b in books]
        # b.author now reads from the already-joined row — 1 query total
    })
```

If the view also needs each book's tags (`ManyToMany`), add `.prefetch_related("tags")`. That turns 1+N (books) into 2 total queries (books, and all tags for all books in one `IN (...)` query) instead of 1+N+M. The general diagnostic habit interviewers want to see: count queries before assuming a fix worked, and never eyeball the code and declare victory.

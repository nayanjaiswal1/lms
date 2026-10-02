---
kind: lesson
id_key: production-debugging/lesson-performance-measure-first
course: production-debugging
section: django-performance
section_title: "Performance"
section_position: 1
section_group: "Django"
title: "Debugging slow pages: measure first"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

"The page is slow" is a symptom, not a diagnosis. Performance bugs are the ones where guessing costs the most: you can spend a day adding caches and indexes to code that only needed one line of queryset. The skill this section trains is turning a vague complaint into a number you can watch go down.

## Turn the complaint into a measurement

A useful performance investigation starts with three questions. What exactly is slow (one page, one endpoint, one customer)? How slow, compared with what? And what changed? A ticket rarely answers them, so your first job is to reproduce the slowness yourself with data that looks like the reporter's. A customer with two orders and a customer with two hundred can behave completely differently.

Once you can reproduce it, pick something to measure that will still be meaningful after you change the code. Wall-clock time on your laptop is noisy. The number of database statements a request runs is exact, repeatable, and usually what the slowness is made of.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-perf-measure-q1", "type": "mcq",
      "prompt": "A ticket says a page is slow only for some customers. What is the best first step?",
      "options": [
        {"id":"a","text":"Add caching in front of the page"},
        {"id":"b","text":"Reproduce it with data shaped like the affected customers and measure something repeatable"},
        {"id":"c","text":"Add indexes to every column the page reads"},
        {"id":"d","text":"Ask for a bigger database instance"}
      ],
      "correct": "b",
      "explanation": "Until you can reproduce the slowness and measure it, every change is a guess. Slow-for-some-customers usually means the cost depends on the data (how many rows a customer has), so the reproduction needs that shape." }
] }
```

## Count queries, not milliseconds

Django will tell you every statement it runs: the debug toolbar, the `django.db.backends` logger, `connection.queries`, or `CaptureQueriesContext` in a test. Load the page once with a small amount of data and once with a lot, and compare the counts. If the count grows with the amount of data, the code is doing work per row that could be done once for all rows. That shape has a name, N+1, and it is the most common cause of pages that get slower as customers get older.

```python
from django.db import connection
from django.test.utils import CaptureQueriesContext

with CaptureQueriesContext(connection) as ctx:
    client.get("/orders/")
print(len(ctx), "queries")
for q in ctx.captured_queries[:5]:
    print(q["sql"][:120])
```

A count that does not grow is a good sign; a count that does is a defect, whatever the timings say. It also gives you the assertion for the regression test you will write at the end.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-perf-count-q1", "type": "mcq",
      "prompt": "You load a page with 3 rows and it runs 7 queries; with 30 rows it runs 61. What does that tell you?",
      "options": [
        {"id":"a","text":"The database is under-provisioned"},
        {"id":"b","text":"The code runs a fixed number of queries per row (roughly 2 per row), which is an N+1 pattern"},
        {"id":"c","text":"The page needs a longer cache timeout"},
        {"id":"d","text":"Nothing, query counts do not matter"}
      ],
      "correct": "b",
      "explanation": "The count grows linearly with the rows shown: (61 - 7) / 27 = 2 extra queries per row. Work that scales with row count is work the queryset should have done once for all rows." }
] }
```

## Laziness is where the cost hides

Django querysets are lazy: nothing hits the database until something evaluates them, and the results are cached on the queryset only after a full evaluation. Related objects are lazy too: `order.customer` runs a query the first time you touch it, for every order. In templates this is invisible, because `{{ order.customer.name }}` looks like reading an attribute. The same laziness bites in a subtler way when you call `count()`, `exists()` and then iterate: each is its own query on an unevaluated queryset.

Read code with this question in mind: at which line does each queryset actually run, and how many times? The fixes are usually small (`select_related`, `prefetch_related`, evaluating once), but you only find the right line by tracing evaluation, not by reading the model definitions.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-perf-lazy-q1", "type": "mcq",
      "prompt": "On an unevaluated queryset qs, which of these sends a new SQL query each time it is called?",
      "options": [
        {"id":"a","text":"qs.count() and qs.exists()"},
        {"id":"b","text":"Only iterating over qs"},
        {"id":"c","text":"None of them, querysets are cached from creation"},
        {"id":"d","text":"Only qs.filter(...) because it changes the SQL"}
      ],
      "correct": "a",
      "explanation": "count() and exists() each run their own statement unless the queryset has already been evaluated. Iterating evaluates it once and caches the rows; after that len(qs) and bool(qs) are free." }
] }
```

In the labs that follow, the ticket gives you a symptom and a customer-shaped hint. The workflow is always the same: reproduce, count, find the line that evaluates, fix it there, and write a test that fails on the old code because the count is higher than it should be.

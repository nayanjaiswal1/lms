---
kind: lesson
id_key: interview-prep-45/note-celery-redis-dns-django-orm
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Celery, Redis Eviction Policies, DNS/Routing, Django QuerySets"
position: 98
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

## Celery vs synchronous processing

Synchronous: the client waits for the entire request-response cycle, including any slow work inside it — fine for fast operations, causes timeouts and bad UX once something inside is slow (email send, report generation, ML inference).

Celery offloads that slow work to background worker processes via a message broker (Redis/RabbitMQ). The request handler enqueues a task and returns immediately; a worker picks it up separately. Trade-off: you now need a way to report task status back to the client (polling, websockets, or webhook) since the response no longer carries the result.

## Redis eviction policies

Apply once `maxmemory` is hit:

| Policy | Behavior |
|---|---|
| `noeviction` | Errors on write instead of evicting anything |
| `allkeys-lru` / `allkeys-lfu` | Evict least-recently / least-frequently used, across **all** keys |
| `volatile-lru` / `volatile-lfu` / `volatile-ttl` | Same, but only considers keys that have a TTL set |
| `allkeys-random` | Evict a random key |

Pick based on how Redis is being used: pure cache → an `allkeys-*` policy is safe, since everything is disposable. Redis mixing cache data with data you actually need to keep (session state, queues) → a `volatile-*` policy, so only the explicitly-TTL'd (cache) keys are eligible for eviction and persistent keys are never silently dropped.

## DNS / routing tables / SQL GROUP BY

Three unrelated things that get asked back-to-back as a "systems fundamentals" round:

- **DNS** — hostname → IP resolution. Hierarchical lookup (root → TLD → authoritative nameserver), cached at OS/browser/resolver level according to each record's TTL.
- **Routing table** — maps network destinations to a next-hop; routers use it to decide where to forward a packet next.
- **SQL `GROUP BY`** — aggregates rows that share a column value into one row per group. Any selected column that isn't in the `GROUP BY` clause must be wrapped in an aggregate function (`COUNT`, `SUM`, `AVG`, ...) — otherwise it's either a DB error (Postgres) or an undefined/arbitrary value (older MySQL).

## Django `filter()` vs `order_by()`

- `filter(**kwargs)` narrows the queryset — becomes a `WHERE` clause.
- `order_by(*fields)` sorts it — becomes `ORDER BY`; prefix a field with `-` for descending.

Both are **lazy** — chaining `.filter().order_by()` builds up the query without touching the database. The query only actually runs when the queryset is evaluated: iterated over, sliced then iterated, or forced with `list(qs)`. This is why you can build a queryset conditionally across several `if` branches and only pay for one query at the end.

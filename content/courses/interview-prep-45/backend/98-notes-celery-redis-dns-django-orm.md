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

In synchronous processing, the client waits for the entire request-response cycle, including any slow work inside it. That's fine for fast operations, but it causes timeouts and bad user experience once something inside the request is slow, such as sending an email, generating a report, or running ML inference.

Celery offloads that slow work to background worker processes via a message broker (Redis or RabbitMQ). The request handler enqueues a task and returns immediately; a separate worker process picks the task up later and runs it. The trade-off is that you now need a way to report task status back to the client, since the original HTTP response no longer carries the result. The usual options are polling an endpoint for status, pushing updates over a websocket, or calling back to a webhook once the task finishes.

## Redis eviction policies

These policies apply once `maxmemory` is hit and Redis needs to free space for a new write.

| Policy | Behavior |
|---|---|
| `noeviction` | Errors on write instead of evicting anything |
| `allkeys-lru` / `allkeys-lfu` | Evict least-recently / least-frequently used, across **all** keys |
| `volatile-lru` / `volatile-lfu` / `volatile-ttl` | Same, but only considers keys that have a TTL set |
| `allkeys-random` | Evict a random key |

Which one to pick depends on how Redis is being used. If Redis is a pure cache, an `allkeys-*` policy is safe, since everything stored in it is disposable and can be regenerated from the source of truth. If Redis is mixing cache data with data you actually need to keep, such as session state or queue contents, use a `volatile-*` policy instead: only the keys you've explicitly given a TTL (the cache entries) become eligible for eviction, and persistent keys are never silently dropped under memory pressure.

## DNS, routing tables, and SQL GROUP BY

These are three unrelated things that tend to get asked back-to-back in a "systems fundamentals" interview round, precisely because they're each small enough to cover quickly.

**DNS** resolves a hostname to an IP address through a hierarchical lookup: root nameservers point to TLD nameservers, which point to the authoritative nameserver for the domain. The result is cached at the OS, browser, and resolver level according to each record's TTL, which is why a DNS change can take time to propagate even after the authoritative record is updated.

**A routing table** maps network destinations to a next-hop address. Routers consult their routing table to decide where to forward each packet next, one hop at a time, until the packet reaches its destination network.

**SQL `GROUP BY`** aggregates rows that share a column value into one row per group. Any selected column that isn't listed in the `GROUP BY` clause must be wrapped in an aggregate function such as `COUNT`, `SUM`, or `AVG`. Skipping this is either a hard error (Postgres rejects the query) or silently returns an undefined, arbitrary value for that column (older MySQL in non-strict mode).

## Django `filter()` vs `order_by()`

`filter(**kwargs)` narrows the queryset; it becomes a `WHERE` clause in the generated SQL. `order_by(*fields)` sorts the queryset instead, becoming an `ORDER BY` clause, where prefixing a field name with `-` gives descending order.

Both methods are **lazy**. Chaining `.filter().order_by()` builds up a description of the query without touching the database at all. The query only actually runs when the queryset is evaluated: iterated over in a loop, sliced and then iterated, or forced eagerly with `list(qs)`. Concretely, this means you can build up a queryset conditionally across several `if` branches, adding a `.filter(...)` in each one, and the database still only gets hit once, at the end, when something finally consumes the result.

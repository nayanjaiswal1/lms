---
kind: lesson
type: system_design
id_key: interview-prep-45/day-01-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "URL Shortener"
position: 1
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

## Why interviewers ask this

The URL shortener is the "FizzBuzz" of system design interviews. It's deliberately simple, so the interviewer can watch how you structure an ambiguous problem: how you scope requirements, do back-of-envelope math, pick a key-generation strategy, and reason about read-heavy traffic. Fumble this one and harder problems (feed, chat, Netflix) are off the table. Treat it as a chance to demonstrate a repeatable framework, not to memorize a diagram.

## Requirements

### Functional
- Given a long URL, generate a short, unique alias (e.g. `https://sho.rt/aZ9kLm`).
- Redirecting to `sho.rt/{code}` returns an HTTP redirect to the original URL.
- Users may optionally request a custom alias.
- Links can expire (default or user-set TTL).
- Basic click analytics: total clicks, maybe referrer/timestamp.

### Non-functional
- **High availability.** A broken redirect service breaks every link ever shared, so uptime matters more than perfect consistency.
- **Low latency.** Redirects must feel instant (< 100 ms server-side).
- **URL uniqueness.** No two long URLs silently collide on the same short code.
- **Not easily guessable.** Avoid sequential codes people can enumerate.
- Scale to billions of URLs and tens of thousands of redirects per second.

## Capacity estimates

Assume 100M new URLs/month and a 100:1 read:write ratio (typical for shortener-style systems).

- **Writes/sec:** 100,000,000 / (30 × 24 × 3600) ≈ **38 writes/sec** average; design for 5-10x peak, so 200-400/sec.
- **Reads/sec:** 38 × 100 ≈ **3,800 redirects/sec** average, peak maybe 20,000/sec.
- **Storage:** each row is roughly 500 bytes (long URL + code + metadata). 100M/month × 5 years × 12 × 500 B ≈ 100M × 60 × 500 B ≈ **3 TB** over 5 years, small enough to shard lightly or even keep in one well-indexed table with read replicas.
- **Cache sizing (80/20 rule):** if 20% of links get 80% of traffic, caching the hottest ~20% of a day's active codes (say 20M entries × 500 B ≈ 10 GB) fits comfortably in a Redis cluster.

## API sketch

```
POST /api/v1/shorten
  body: { long_url, custom_alias?, expires_at? }
  resp: { short_code, short_url, expires_at }

GET /{short_code}
  -> 301/302 redirect to original long_url

GET /api/v1/{short_code}/stats
  resp: { short_code, long_url, click_count, created_at, last_accessed_at }

DELETE /api/v1/{short_code}   (owner only)
```

301 vs 302: **302 (temporary)** is usually correct for a shortener. It stops browsers from caching the redirect forever, which keeps click analytics accurate and lets you change or expire the destination later. 301 saves origin load because the browser caches it, but you lose click tracking and flexibility in exchange.

## Data model

```
urls
  id              bigint PK
  short_code      varchar(10) UNIQUE INDEX
  long_url        text
  user_id         bigint NULL (FK -> users)
  created_at      timestamp
  expires_at      timestamp NULL
  click_count     bigint DEFAULT 0

clicks (optional, for analytics — append-only, often a separate store)
  id              bigint PK
  short_code      varchar(10) INDEX
  clicked_at      timestamp
  referrer        text NULL
  ip_hash         varchar(64) NULL
```

Keep `click_count` as an eventually-consistent counter, incremented asynchronously via a queue or a periodic batch job, rather than an update-per-redirect. A synchronous `UPDATE` on every redirect turns your hot read path into a hot write path and creates row-lock contention on popular links.

## High-level architecture

```
Client
  |
  v
Load Balancer
  |
  +--> Write Service (POST /shorten) --> Key Generation Service --> Primary DB
  |                                                                     |
  +--> Read Service (GET /{code})  <--  Cache (Redis)  <----------------+
                                            |
                                     (cache miss) --> Read Replica DB
```

- **Write path:** client submits a long URL, the service generates and validates a short code, writes to the primary DB, and returns the short URL.
- **Read path:** redirect requests hit the load balancer and check cache first. On a hit, redirect immediately. On a miss, read from a DB replica, populate the cache, then redirect.
- Cache-aside (lazy loading) is the right pattern here. Reads vastly outnumber writes, and a cold cache self-heals from the DB.

## Component deep dives

### Key generation: base-62 encoding vs random ID

**Option A: random string generation.** Generate 7 random base-62 characters (`[a-zA-Z0-9]`), check for collision in the DB, retry on conflict.
- Pros: simple, no coordination between servers, unpredictable (secure-ish).
- Cons: collision probability grows with scale, requiring a uniqueness check (extra DB round trip) on every write. Retries under high write volume add tail latency.

**Option B: base-62 encode an auto-incrementing ID.** Use a distributed ID generator (DB sequence, Snowflake, or a pre-allocated range per server) to get a unique 64-bit integer, then base-62 encode it into a short string.
- 62 characters (`0-9a-zA-Z`) means 7 characters gives 62^7 ≈ 3.5 trillion combinations, comfortably more than we'll ever need.
- Pros: guaranteed uniqueness with **no collision check**; sequential generation is cheap.
- Cons: sequential/incrementing IDs are guessable and enumerable unless you shuffle or offset them (XOR with a secret, for example, or Snowflake IDs, which interleave timestamp, machine ID, and sequence to avoid a single point of ID allocation).

**Interview-favored answer:** pre-generate a pool of unique keys offline (a **Key Generation Service**, KGS) using an ID sequence, and hand blocks of keys (say, 1,000 at a time) out to app servers so writes never contend on a single counter. Mark keys "used" only after a successful insert. This removes the collision-check round trip from the write path entirely and avoids a single hot sequence.

### Custom aliases

Custom aliases go through the same `short_code` column but skip key generation. Just check availability with a unique constraint (`INSERT ... ON CONFLICT DO NOTHING`, return a conflict error if taken).

### Redirect service

Stateless, horizontally scaled behind the load balancer. Cache-first lookup means most instances never touch the DB. Use a CDN or edge cache for extremely hot links (viral URLs) to avoid a "hot key" problem even in Redis.

## Scaling & trade-offs

- **Database choice:** a relational DB (Postgres/MySQL) is fine up to a very large scale because access is by primary key (`short_code`) with no complex joins. Move to horizontal sharding (by hash of `short_code`) only once a single primary can't keep up with write throughput or storage.
- **Read replicas** absorb the 100:1 read-heavy load cheaply; the cache absorbs even more.
- **Cache eviction:** LRU is fine. Cold, rarely-clicked links naturally fall out and re-populate from the DB on next access.
- **Analytics** should not block the redirect. Fire-and-forget an event onto a queue (Kafka/SQS) and let a separate consumer update `click_count` and write to a `clicks` table asynchronously.
- **Consistency vs availability:** favor availability. A slightly stale click count or a few-second delay before a new link is cache-visible is acceptable; a failed redirect is not.

## Likely follow-up questions — with answers

**Q: How do you prevent short-code collisions at scale without a check on every write?**
A: Use a pre-generated key pool (KGS) so uniqueness is guaranteed by construction, or base-62 encode a globally unique, monotonically-assigned ID (Snowflake-style: timestamp + shard ID + sequence) so no two servers ever produce the same code.

**Q: How would you handle a link that suddenly goes viral (millions of hits/minute)?**
A: A single Redis key becomes a hot key. Mitigate with a CDN/edge cache in front of the redirect service for GET requests, local in-process caching on each app server (short TTL) to reduce Redis calls, and/or replicating that specific hot key across multiple Redis nodes.

**Q: How do you support link expiration efficiently instead of scanning the whole table?**
A: Store `expires_at`, check it on cache miss during read (lazy expiration), and run a low-priority background job that periodically deletes expired rows in batches (active expiration) so storage doesn't grow unbounded. It's the same pattern Redis itself uses internally.

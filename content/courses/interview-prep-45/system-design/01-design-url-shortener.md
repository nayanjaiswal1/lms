---
kind: lesson
type: system_design
id_key: interview-prep-45/day-01-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a URL Shortener"
position: 1
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

A URL shortener turns a long link into a short one, like turning `https://example.com/blog/2026/09/a-very-long-post-title` into `sho.rt/aZ9kLm`. Visiting the short link redirects you to the long one.

Interviewers love this question because it is simple enough to finish in 40 minutes, but it still forces you to scope requirements, do real math, pick a key-generation strategy, and think about a read-heavy system. Treat it as your warm-up: the same framework (requirements, estimates, API, data model, high-level design, deep dive, trade-offs) repeats in every design in this course.

## Requirements

Start every design by splitting what the system must do (functional) from how well it must do it (non-functional). This keeps you from jumping straight to a diagram before you know what you're building.

**Functional requirements**
- Given a long URL, generate a short, unique code (`sho.rt/aZ9kLm`).
- Visiting the short link redirects to the original URL.
- Users can optionally request a custom alias.
- Links can expire, either by default or a user-set date.
- Basic click stats: total clicks, maybe referrer and timestamp.

**Non-functional requirements**
- High availability: if the redirect service goes down, every shared link breaks. Uptime matters more than perfect consistency.
- Low latency: a redirect should feel instant, under 100ms on the server.
- No two long URLs should silently collide on the same short code.
- Short codes should not be easy to guess in sequence.
- The system must handle billions of URLs and tens of thousands of redirects per second.

> **Remember:** in every system design interview, say the functional and non-functional requirements out loud before you draw anything. It shows you're scoping the problem, not guessing at a diagram.

```knowledge-check
{ "questions": [
    { "id": "system-design-url-shortener-requirements-q1", "type": "mcq", "prompt": "Why do non-functional requirements matter as much as functional ones in a URL shortener?", "options": [
        {"id": "a", "text": "They don't, only functional requirements affect the design"},
        {"id": "b", "text": "They decide trade-offs like availability over consistency, which shapes every later design choice"},
        {"id": "c", "text": "They are only relevant for the final trade-offs section"},
        {"id": "d", "text": "They are the same for every system, so they can be skipped"}
    ], "correct": "b", "explanation": "Picking availability over consistency here is what later justifies caching, eventual-consistency click counts, and read replicas." }
] }
```

## Estimates

Rough numbers, done out loud, tell you what kind of system you're building. Assume 100 million new URLs a month and a 100:1 read-to-write ratio, which is typical: people click links far more often than they create them.

- **Writes per second:** 100,000,000 / (30 × 24 × 3600) ≈ 38 writes/sec on average. Design for 5-10x that at peak, so 200-400/sec.
- **Reads per second:** 38 × 100 ≈ 3,800 redirects/sec on average, maybe 20,000/sec at peak.
- **Storage:** each row is about 500 bytes (long URL plus metadata). Over 5 years: 100M/month × 60 months × 500 bytes ≈ 3 TB. Small enough to fit in one well-indexed table with read replicas.
- **Cache size:** if 20% of links get 80% of the traffic (a common pattern), caching a day's hottest 20 million codes at 500 bytes each is about 10 GB, which fits easily in a Redis cluster.

> **Remember:** the read:write ratio is the single number that should drive your whole design. A 100:1 ratio means "optimize the read path first" before anything else.

## API

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

One real decision hides in that redirect line: 301 or 302? A 302 ("temporary redirect") is usually right for a shortener. Browsers won't cache it forever, so you keep accurate click counts and can still change or expire the destination later. A 301 ("permanent redirect") saves you server load because browsers cache it, but you lose click tracking. Say this trade-off out loud if asked.

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

Don't update `click_count` on every redirect with a synchronous `UPDATE`. That turns your hot read path into a hot write path, and popular links start fighting over the same row lock. Instead, treat `click_count` as an eventually-consistent number: fire an event onto a queue and let a separate worker update the count in the background.

```knowledge-check
{ "questions": [
    { "id": "system-design-url-shortener-datamodel-q1", "type": "mcq", "prompt": "Why shouldn't a redirect synchronously increment click_count in the database?", "options": [
        {"id": "a", "text": "Because click counts don't matter to the business"},
        {"id": "b", "text": "Because it turns the hot read path into a hot write path and causes row-lock contention on popular links"},
        {"id": "c", "text": "Because Postgres cannot increment a counter column"},
        {"id": "d", "text": "Because click_count must always be exactly accurate"}
    ], "correct": "b", "explanation": "Redirects happen far more often than link creation. Adding a synchronous write to the busiest path in the system slows everyone down for the sake of a number that's fine to be a few seconds stale." }
] }
```

## High-level design

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

Picture two separate lanes on a highway. The write lane is quiet: someone submits a long URL, the service picks a short code, writes it to the database, and hands back the short link. The read lane is the busy one: every redirect checks the cache first. A hit means an instant redirect. A miss means one query to a read replica, then the cache is filled so the next person gets a hit.

This pattern, check the cache first and fall back to the database, is called **cache-aside**. It fits here because reads vastly outnumber writes, and a cold cache heals itself the moment someone requests a missing code.

## Deep dives

### How do you generate a short code without collisions?

**Option A: random string, then check for a collision.** Generate 7 random characters from `[a-zA-Z0-9]` (62 possible characters per slot), then check the database for a clash and retry if one exists.
- Simple, and codes are unpredictable.
- The problem: as the table fills up, more of your random guesses collide, so writes slow down under a growing number of retries.

**Option B: base-62 encode a number that's already unique.** Get a unique, ever-increasing number (a database sequence, or a distributed ID generator) and encode it in base 62. Seven base-62 characters give you 62⁷ ≈ 3.5 trillion possible codes.

```python
ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

def encode_base62(num: int) -> str:
    if num == 0:
        return ALPHABET[0]
    digits = []
    base = len(ALPHABET)
    while num:
        num, rem = divmod(num, base)
        digits.append(ALPHABET[rem])
    return "".join(reversed(digits))
```

Base-62 encoding guarantees uniqueness by construction, with no collision check needed. The trade-off: a plain incrementing ID is guessable (code `aaaaaab` is obviously one more than `aaaaaaa`). Fix that by handing out IDs in shuffled blocks instead of one global counter.

The strongest answer in an interview: a **Key Generation Service (KGS)**. It pre-generates a big pool of unique keys ahead of time and hands blocks of, say, 1,000 keys to each app server. Every server picks from its own block, so no two servers ever fight over the same counter, and no write ever needs a collision check.

> **Remember:** a Key Generation Service removes the collision check from the write path entirely, instead of hoping random strings don't clash.

```knowledge-check
{ "questions": [
    { "id": "system-design-url-shortener-keygen-q1", "type": "mcq", "prompt": "What is the main advantage of base-62 encoding a unique ID over generating a random string and checking for collisions?", "options": [
        {"id": "a", "text": "Base-62 codes are always shorter"},
        {"id": "b", "text": "It guarantees uniqueness by construction, so no collision check or retry is needed on write"},
        {"id": "c", "text": "Random strings cannot be stored in a database"},
        {"id": "d", "text": "Base-62 encoding is required by HTTP"}
    ], "correct": "b", "explanation": "Since the underlying number is already unique, encoding it never produces a duplicate, which removes an expensive collision-check round trip from every write." }
] }
```

### What happens when a link goes viral?

A viral link turns one Redis key into a hot key that gets hammered by millions of reads a minute. Three fixes, and they stack:
- Put a CDN or edge cache in front of the redirect service, so most requests never even reach your servers.
- Add a short-lived, in-process cache on each app server so not every request round-trips to Redis.
- Replicate that one hot key across multiple Redis nodes so no single node becomes the bottleneck.

### How do expired links get cleaned up without scanning the whole table?

Two mechanisms, used together. On a cache miss, check `expires_at` and treat an expired link as not found (lazy expiration). Separately, run a low-priority background job that deletes expired rows in small batches (active expiration), so the table doesn't grow forever. Redis uses this same combination internally.

## Trade-offs and follow-up questions

- **Relational vs sharded database.** A single Postgres or MySQL instance handles this fine for a long time, since every lookup is by primary key with no joins. Shard by a hash of `short_code` only once one primary can't keep up with write volume or storage.
- **Consistency vs availability.** This system should favor availability. A redirect that fails is a real problem; a click count that's a few seconds stale is not.
- **Analytics off the hot path.** Never let click tracking block a redirect. Fire an event onto a queue and let a separate consumer update counts and write detailed click rows asynchronously.

**Q: How do you prevent short-code collisions at scale without checking on every write?**
A: Use a pre-generated key pool (the KGS above), or base-62 encode a globally unique, monotonically increasing ID so no two servers can ever produce the same code.

**Q: How would you handle a link that suddenly goes viral?**
A: CDN/edge caching in front of the redirect service, a short local cache on each app server, and replicating the hot key across more than one Redis node.

**Q: How do you expire links without scanning the whole table?**
A: Lazy expiration on read (check `expires_at` on a cache miss) plus a background job that deletes expired rows in batches.

```knowledge-check
{ "questions": [
    { "id": "system-design-url-shortener-tradeoffs-q1", "type": "mcq", "prompt": "Why does a URL shortener favor availability over strict consistency?", "options": [
        {"id": "a", "text": "Because a broken redirect breaks every shared link, while a slightly stale click count costs nothing"},
        {"id": "b", "text": "Because Postgres cannot guarantee consistency"},
        {"id": "c", "text": "Because availability is always more important than consistency in every system"},
        {"id": "d", "text": "Because redirects don't need a database at all"}
    ], "correct": "a", "explanation": "The cost of an unavailable redirect (a broken link everywhere it was shared) is far higher than the cost of a click count being a few seconds out of date." }
] }
```

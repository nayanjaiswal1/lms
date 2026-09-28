---
kind: lesson
id_key: interview-prep-45/hld-06-caching
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Caching and CDNs"
position: 6
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Imagine you keep a photocopy of your most-used library book on your desk, so you don't walk to the library every time you need to check a fact. That copy is faster to reach, but now you have two copies of the same information, and if the library updates its book, your desk copy is out of date until you notice. That is exactly what a cache is: a fast copy of data kept close to whoever needs it, with the constant risk of going stale.

Caching is the cheapest speed boost you'll ever get in a system, and it's also the most common source of quiet, confusing bugs in production. In interviews it comes up twice: once when you draw Redis on the board, and again a bit later when the interviewer asks "so how does the cache get updated when the data changes?" That second question is the one that tells the interviewer whether you've actually operated a cache, or only drawn one.

## Where caches live

A system usually has several caches stacked on top of each other, not just one. Naming which layer you mean is half the battle.

| Layer | Example | Typical time before expiry | How it's kept fresh |
|---|---|---|---|
| Client / browser | `Cache-Control: max-age`, service worker | minutes to days | Filenames that change when content changes |
| CDN / edge | CloudFront, Cloudflare, Fastly | minutes to days | A purge request, or filenames that change |
| Reverse proxy | nginx / Varnish page cache | seconds to minutes | Time-based expiry, or a purge request |
| Application (in-process) | A local map kept inside one server's memory | seconds | Time-based expiry only; each server has its own copy, so there's no single place to clear them all |
| Distributed cache | Redis, Memcached | minutes to hours | Deleted directly whenever the real data changes |
| Database | Postgres's internal buffer pool | — | Handled automatically by the database itself |
| Precomputed result | A feed stored in Redis, a summary table | until recomputed | Recomputed whenever the underlying event happens |

Two rules for deciding where to put a cache.

**Cache as close to the user as the data's need for freshness allows.** A product photo can sit safely in a browser for a whole year, as long as its filename changes whenever the photo does. A live stock price cannot sit anywhere for more than a second.

**An in-process cache, one stored in a single server's own memory, cannot be cleared reliably.** With 20 servers running, you have 20 separate copies, and no single button that clears all of them at once. Only use this kind of cache for data where a short, bounded amount of staleness is genuinely fine, like feature flags or configuration values.

> **Remember:** cache close to the user, but only as close as the data's freshness allows. A stock price and a product photo do not need the same expiry time.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-layers-q1", "type": "mcq",
      "prompt": "Why is a cache stored in each server's own memory a poor fit for data that must update the instant it changes?",
      "options": [
        {"id":"a","text":"In-process caches are too slow"},
        {"id":"b","text":"Every server holds its own separate copy, so there is no single place to clear them all; you'd need to reliably tell every server at once, and any server that missed the message keeps serving old data"},
        {"id":"c","text":"In-process caches can only store plain text, not structured data"},
        {"id":"d","text":"They use up database connections"}
      ],
      "correct": "b",
      "explanation": "Clearing a cache reliably needs one single place in charge of it. A shared Redis gives you that; a separate copy in each server's memory does not. A per-server cache is only safe when a short time-based expiry is an acceptable amount of staleness." }
] }
```

## The four caching patterns

**Cache-aside**, also called lazy loading, is the default choice, the one you should reach for unless you have a specific reason not to. Here, your application code owns the cache directly.

```python
def get_user(user_id):
    key = f"user:{user_id}"
    cached = redis.get(key)
    if cached is not None:
        return json.loads(cached)          # hit

    user = db.query("SELECT * FROM users WHERE id = %s", user_id)  # miss
    if user is not None:
        redis.setex(key, 300, json.dumps(user))                    # populate with a TTL
    return user

def update_user(user_id, changes):
    db.update("users", user_id, changes)
    redis.delete(f"user:{user_id}")        # invalidate, don't rewrite — see below
```

Only data that's actually been requested gets cached, and if the cache goes down entirely, the system just gets slower instead of breaking outright. The cost is that every miss still has to wait for the database, and there's a small window between saving to the database and deleting the old cache entry where another reader could put the stale value right back in.

**Write-through** writes to the cache and the database together, at the same time, as part of the same request. The cache is never out of date, but every single write now pays for both, and you might end up caching data nobody ever reads again.

**Write-behind**, also called write-back, writes to the cache, tells the caller it's done, and saves to the database later, in batches. Writes are very fast this way, which is great for things like counters, but if the cache crashes before that batch is saved, that data is gone. Only use this where losing a little data is genuinely acceptable, or where it can be rebuilt from elsewhere.

**Refresh-ahead** refreshes popular keys just before their expiry time runs out, so a real user request never has to wait through a cache miss. This works well for a small, predictable set of hot keys, and wastes effort if you guess wrong about which keys are hot.

| Pattern | Speed reading | Speed writing | How stale can it get | Risk of losing data |
|---|---|---|---|---|
| Cache-aside | Fast when found, slow on a miss | Only the database | A small window | None |
| Write-through | Always fast | Both database and cache | Never | None |
| Write-behind | Always fast | Only the cache | Never, inside the cache | **Yes** |
| Refresh-ahead | Always fast | Only the database | Limited and predictable | None |

**When you write new data, delete the old cache entry. Do not overwrite it directly.** Here's why: if two writers update the cache at almost the same time, their updates can land in the wrong order, leaving the *older* value stuck in the cache permanently. Deleting the entry instead forces the very next read to go fetch the real, current value from the database. If you need to close even the small gap left by a delete, use a "delayed double delete": delete the cache entry, write to the database, then delete the cache entry again a few hundred milliseconds later.

> **Remember:** cache-aside is the default. On a write, delete the cached key instead of overwriting it, so the next read always pulls the true value from the database.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-patterns-q1", "type": "mcq",
      "prompt": "When updating a row, why is deleting the matching cache key generally safer than overwriting it with the new value directly?",
      "options": [
        {"id":"a","text":"Deleting is a faster operation than overwriting"},
        {"id":"b","text":"Two writers updating the cache at nearly the same time can land in the wrong order, leaving the older value stuck in the cache forever; a delete instead forces the next read to fetch the real value from the source of truth"},
        {"id":"c","text":"Redis does not allow overwriting an existing key"},
        {"id":"d","text":"Deleting always frees up more memory, which is always the better outcome"}
      ],
      "correct": "b",
      "explanation": "Picture writer A reading the old value first, then writer B updating both the database and the cache to a new value, and finally writer A's slightly delayed cache update overwriting it back to the old value. Now the cache disagrees with the database, permanently. Deleting removes that possibility entirely; the worst case is one extra cache miss." }
] }
```

## Eviction, TTLs, and hit rate

Picture a small fridge that's already completely full. New milk arrives, so something has to come out to make room. Do you throw out whatever has sat there longest without being touched, or whatever gets used the least often? That choice is called an eviction policy, and a cache faces the exact same decision whenever it runs out of memory.

**Eviction policies decide what gets dropped first when memory runs out:**

| Policy | What it drops | Best used for |
|---|---|---|
| **LRU** (least recently used) | Whatever hasn't been touched in the longest time | General use; this is the usual default |
| **LFU** (least frequently used) | Whatever gets touched the fewest times overall | A stable set of hot keys, where you want to survive one big sweep through cold data |
| FIFO (first in, first out) | Whatever was added first | Rarely the right choice |
| Random | A randomly chosen key | Surprisingly decent, and very cheap to compute |
| Time-based only | Only keys that have an expiry set | When some keys must never be evicted, ever |

In Redis, you'll usually name `allkeys-lru` or `allkeys-lfu`. LFU's advantage is that one big analytical job sweeping through a million cold keys won't push out your genuinely hot data, because touching something only once never builds up enough frequency to matter.

**Expiry times (TTLs, meaning "time to live") do two jobs.** They limit how stale data can get, and they act as a safety net if your code ever forgets to clear a cache entry on a write. Always set one, even on keys you also delete explicitly by hand. A cache entry with no expiry and one missed update becomes a permanently wrong answer.

**Add a small random amount to every TTL, called jitter.** If 10,000 keys are all set with the exact same 300-second expiry at the exact same moment, they all expire in the very same second, and every one of those 10,000 requests hits your database at once. Setting the expiry to `300 + random(0, 60)` seconds spreads that load out instead.

**Hit rate is the single most important number to watch.** A cache that answers correctly only half the time is barely helping. A hit rate above 95% is where the real speed gain lives. Track hits, misses, evictions, and memory used; a rising number of evictions is an early warning that the data you actually need no longer fits, and your hit rate is about to fall off a cliff.

A useful rule of thumb for sizing a cache: roughly 20% of your keys usually account for about 80% of requests, so estimate the size of that hot 20%, not the size of your entire dataset.

> **Remember:** LRU throws out what hasn't been touched in a while; LFU throws out what's rarely touched at all. LFU survives a big sweep through cold data; LRU does not.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-eviction-q1", "type": "mcq",
      "prompt": "A nightly batch job reads through every single user record once. Under which eviction policy is it LEAST likely to push out the hot keys real users depend on?",
      "options": [
        {"id":"a","text":"LRU, because the scanned keys become the most recently touched and push out the hot set"},
        {"id":"b","text":"LFU, because each scanned key is only touched once and never builds up enough frequency to displace the genuinely hot keys"},
        {"id":"c","text":"FIFO"},
        {"id":"d","text":"No eviction policy at all"}
      ],
      "correct": "b",
      "explanation": "This is the classic reason to choose LFU. Under LRU, one sequential sweep through a million cold records marks all of them as \"most recently used\" and pushes out the actual working set, so the next morning starts with a nearly empty, cold cache." }
] }
```

## The three failure modes: stampede, penetration, avalanche

Bringing these up before the interviewer asks is a strong sign that you've actually operated a cache in the real world.

**1. Cache stampede, also called a thundering herd.** Picture a shop's doors opening at 9am with 5,000 people waiting outside, and every single one of them rushing through the same one door at once. That's what happens when one popular cache key expires: thousands of requests miss the cache at the same moment and all hit the database for that same row simultaneously. The database can fall over under that load.

The usual fixes, in order of preference:
- **Request coalescing**, sometimes called single-flight: the very first request that misses takes a short lock, and every other request waits briefly, then rechecks the cache instead of also hitting the database.
- **Probabilistic early refresh**: as a key's expiry time gets closer, each reader has a small and rising chance of refreshing it early, so on average exactly one of them ends up doing the work ahead of time.
- **Serve stale while refreshing in the background**: hand back the expired value immediately, and quietly refresh it behind the scenes. This is the standard behaviour CDNs use.

**2. Cache penetration** happens when requests ask for keys that don't exist in the database at all, often because someone is deliberately probing with random IDs in a loop. Every single one of those requests misses the cache *and* misses the database.

The fix is to cache the fact that something doesn't exist, storing something like "no such user" with a short expiry, and optionally put a Bloom filter in front of the cache. A Bloom filter is a small, cheap structure that can quickly and confidently say "this definitely does not exist," which is exactly the question being abused here.

**3. Cache avalanche** happens when a large chunk of the cache disappears all at once, either because many keys expire together or because the cache itself restarts, and the full weight of production traffic lands on a cold database with nothing cached to soften it.

The fixes are the jitter on TTLs mentioned earlier, warming the cache up before a restarted server is marked ready to receive traffic, keeping a backup or replicated copy of the cache so a restart isn't a total cold start, and putting a circuit breaker (covered in a later lesson) in front of the database, so an overload turns into some errors instead of a complete collapse.

> **Remember:** a stampede is everyone rushing one expired key at once. Penetration is repeated requests for keys that never existed. An avalanche is the whole cache disappearing at once. Each one needs its own fix.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-failures-q1", "type": "mcq",
      "prompt": "An attacker repeatedly requests IDs that don't exist, so every single request misses both the cache and the database. What is this called, and what is the standard fix?",
      "options": [
        {"id":"a","text":"Cache stampede; fix it with a lock so only one request refills the value"},
        {"id":"b","text":"Cache penetration; cache the fact that the value doesn't exist with a short expiry, and optionally put a Bloom filter in front of the cache"},
        {"id":"c","text":"Cache avalanche; fix it by adding jitter to the expiry times"},
        {"id":"d","text":"Cache invalidation; fix it by deleting keys whenever data is written"}
      ],
      "correct": "b",
      "explanation": "Penetration is exactly this miss-then-miss pattern for keys that genuinely don't exist. Caching a \"not found\" result stops the repeated database hits, and a Bloom filter can answer \"definitely not present\" without touching the database at all." }
] }
```

## CDNs and edge caching

Picture ordering a book online. Instead of shipping every single copy from one warehouse on the other side of the world, the seller keeps copies in local warehouses on every continent, so your copy only has to travel 50 kilometres instead of 15,000. A CDN, short for Content Delivery Network, does exactly this for web content: it stores copies of your files on servers physically close to users all around the world. For anything large and mostly unchanging, like images, video, and JavaScript files, a CDN is a core part of the design, not something you bolt on afterward.

**Here's how a request flows through one.** DNS, or a technique called anycast, sends the user to the nearest edge location. If that location already has the file cached, it serves it directly in 10 to 30 milliseconds, instead of the 150 milliseconds a round trip to a far-away server would take. If it doesn't have the file yet, it asks a regional layer behind it, which asks your own server if it doesn't have it either, then caches the result on the way back so future requests are fast. That regional layer exists so your own server only has to serve each new file once, not once per edge location around the world.

**A CDN can either pull or be pushed to.** A pull CDN fetches a file the first time someone asks for it; simple, and it maintains itself, at the cost of the very first user paying the full delay. A push CDN has files loaded onto it ahead of time by you; useful for large files and launches where you know exactly what's coming.

**A handful of HTTP headers control all of this:**

```
Cache-Control: public, max-age=31536000, immutable      # hashed asset: app.4f2b9c.js
Cache-Control: public, max-age=60, stale-while-revalidate=300   # HTML/API: fresh-ish, never a stampede
Cache-Control: private, no-store                        # per-user or sensitive
ETag: "a1b2c3"        →  client sends If-None-Match  →  304 Not Modified (no body)
Vary: Accept-Encoding, Accept-Language                  # each variant is a separate cache entry
```

An ETag is a short fingerprint of a file's content; a client can ask "has this changed since I last saw fingerprint X?" and get back an empty "not modified" reply if it hasn't.

**Clearing files at the edge is the hard part, and the answer is almost always to change the filename.** A file named `app.4f2b9c.js`, where that string is a hash of its own content, never needs to be updated once it's cached; it can sit there for a year. Deploying a new build simply produces a new filename. A "please clear this file everywhere" request is possible too, but it's slower, limited in how often you can call it, and takes a moment to reach every location; use it for exceptions, not as your main strategy.

Be careful with the `Vary` header: varying the cache based on a header with many possible values, like the raw `User-Agent` string, multiplies the number of separate cache entries needed and can quietly destroy your hit rate.

**Beyond plain files**, a CDN can also cache short-lived API responses, run small pieces of code near the user for personalisation, hand out signed, temporary links for private files (so the CDN carries the bytes while your own server only ever approves permission), and shield a small origin server from a very large audience.

> **Remember:** a content-hashed filename turns "clear this file everywhere" into "give the new version a new name," which needs no clearing step at all.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-06-cdn-q1", "type": "mcq",
      "prompt": "What is the most reliable way to make a JavaScript file cacheable for a year at the CDN, while still being able to ship updates instantly?",
      "options": [
        {"id":"a","text":"Set a one-year expiry and call the purge API on every deploy"},
        {"id":"b","text":"Put a hash of the file's content in its filename, and serve it as unchanging: a new build automatically produces a new filename, so there is nothing to clear"},
        {"id":"c","text":"Set a 60-second expiry so updates spread quickly"},
        {"id":"d","text":"Turn off CDN caching for JavaScript entirely"}
      ],
      "correct": "b",
      "explanation": "A content-hashed filename turns clearing the cache into a naming problem, which is always more reliable than clearing it everywhere on demand. A clear-cache request takes a moment to reach every location and is limited in frequency; a new filename is instant everywhere by design." }
] }
```

## Quick recap

```
Patterns : cache-aside (default) · write-through (fresh) · write-behind (fast, lossy)
           · refresh-ahead (hot keys)
Rule     : on write, DELETE the key — never update it
TTL      : always set one (safety net) + add jitter (avoid synchronised expiry)
Eviction : LRU default · LFU when scans would flush the hot set
Failures : stampede (lock / stale-while-revalidate) · penetration (cache NULL / Bloom)
           · avalanche (jitter + warming + circuit breaker)
Metrics  : hit rate, eviction rate, memory used, p99 latency
CDN      : hashed immutable URLs > purge API; stale-while-revalidate for HTML/API;
           signed URLs for private media; origin shield for small origins
```

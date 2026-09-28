---
kind: lesson
type: system_design
id_key: interview-prep-45/day-09-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Social Media Feed (Twitter/X)"
position: 8
estimated_minutes: 80
source:
    - 45-day-interview-roadmap.md
---

A social feed shows you posts from people you follow, roughly newest first. This is the classic "design Facebook/Instagram/Twitter" question, and it's asked constantly because it forces one real decision under conflicting constraints: reads vastly outnumber writes, feed loads must feel instant, and "who sees what, in what order" is both a product problem and an engineering one. Whichever platform the interviewer names, the design underneath is the same, so this lesson covers the general feed and then the extra pieces (search, viral spikes, explicit sharding) that show up once the interviewer says "at Twitter scale."

## Requirements

**Functional requirements**
- Users post text, image, or video content, up to some length limit.
- Users follow other users.
- A user's home feed shows posts from people they follow, roughly newest-first.
- Users can like, comment, and (for Twitter-style feeds) retweet.
- The feed supports infinite scroll.
- Search posts by keyword or hashtag, and show trending topics (Twitter-specific).

**Non-functional requirements**
- Read-heavy: feed reads happen orders of magnitude more often than posts are written.
- Feed load latency under 200ms for the first page.
- Eventual consistency is fine for counts (a like count lagging a second is okay); a post disappearing is not.
- High availability over strict consistency: a slightly stale feed beats an error page.
- The system must survive a single post or account going viral without degrading for everyone else.

> **Remember:** the read:write ratio is the number that should drive almost every choice in this design: aggressive caching, precomputed feeds, and read replicas all exist because of it.

```knowledge-check
{ "questions": [
    { "id": "system-design-feed-requirements-q1", "type": "mcq", "prompt": "Why does a social feed favor availability over strict consistency?", "options": [
        {"id": "a", "text": "Consistency is impossible to achieve at any scale"},
        {"id": "b", "text": "A slightly stale feed or like count is a minor UX issue, while an error page loses the user entirely"},
        {"id": "c", "text": "Feeds never need to be correct"},
        {"id": "d", "text": "Availability and consistency are the same thing"}
    ], "correct": "b", "explanation": "The cost of showing a feed that's a few seconds behind is tiny compared to the cost of the feed failing to load at all, so the design deliberately accepts eventual consistency." }
] }
```

## Estimates

Assume 200 million daily active users, each posting rarely but reading often.
- **Posts/day:** if 5% of DAU post daily, that's 10M posts/day, about 116/sec average, 350/sec at peak.
- **Feed reads/day:** each DAU opens the feed about 10 times/day, so 2B reads/day, about 23,000/sec average, 70,000/sec at peak.
- **Read:write ratio:** roughly 200:1. This one number justifies nearly every design choice below.
- **Follower spread:** most users have a few hundred follows; a celebrity might have 50 million followers. This spread, not the average, is what creates the "celebrity problem" covered in the deep dive.
- **Storage:** 10M posts/day × 1 KB of metadata ≈ 10 GB/day. Media goes to blob storage and a CDN, not the database, and easily dwarfs the metadata by 100x.

At Twitter's larger, published scale (300M DAU, 500M tweets/day), the fan-out multiplier matters more than the raw numbers: one tweet from a 50-million-follower account, if pushed to every follower's timeline, is 50 million writes from a single post. That single fact is why celebrity accounts need special handling, not just more servers.

## API

```
POST /posts                { text, media_urls[] }               -> { post_id, created_at }
GET  /feed?cursor=&limit=20                                       -> { posts[], next_cursor }
POST /posts/{id}/like                                              -> { like_count }
POST /posts/{id}/comments  { text }                                -> { comment_id }
GET  /posts/{id}/comments?cursor=                                  -> { comments[], next_cursor }
POST /follows               { target_user_id }
GET  /search?q=&cursor=                                            -> { posts[], next_cursor }
GET  /trending?region=
```

Use cursor-based pagination, not offset-based. `OFFSET 50000` forces the database to scan and discard 50,000 rows, and it breaks under concurrent inserts, since items shift between pages while someone's scrolling. The cursor is just the last-seen post's `(created_at, post_id)`, encoded opaquely.

## Data model

```
users            id, username, follower_count, following_count
posts            id (snowflake), author_id, text, media_urls, created_at
follows          follower_id, followee_id, created_at   PK(follower_id, followee_id)
likes            post_id, user_id, created_at            PK(post_id, user_id)
comments         id, post_id, author_id, text, created_at

-- the precomputed feed (fan-out on write), keyed for fast range reads
feed_items       user_id, post_id, author_id, created_at   -- one row per (feed owner, post)
                 PK(user_id, created_at, post_id)           -- sorted for cheap pagination

-- search index, a separate system, never the primary DB
post_search      post_id, tokens[], author_id, created_at, engagement_score
```

`feed_items` is a denormalized, per-user timeline: one row for every post that should appear in a given user's feed. A Redis sorted set (`ZADD feed:{user_id} {timestamp} {post_id}`) or a wide-column store like Cassandra fits this pattern better than a relational table, since the access pattern is simple range reads by `user_id` at high write volume.

At Twitter scale, use a **Snowflake-style ID** for posts: timestamp bits, shard bits, and a sequence number packed into one integer. This gives you globally unique, roughly time-sortable IDs with no single point of contention, and the ID itself tells you which shard to route to.

```knowledge-check
{ "questions": [
    { "id": "system-design-feed-datamodel-q1", "type": "mcq", "prompt": "Why use a Snowflake-style ID instead of a simple auto-increment column for posts at Twitter scale?", "options": [
        {"id": "a", "text": "Auto-increment IDs take up more storage"},
        {"id": "b", "text": "It avoids a single point of contention, stays roughly time-sortable, and encodes shard routing directly in the ID"},
        {"id": "c", "text": "Snowflake IDs are required by every relational database"},
        {"id": "d", "text": "Auto-increment cannot generate unique values across multiple servers under any circumstances"}
    ], "correct": "b", "explanation": "A single auto-increment counter becomes a bottleneck and a single point of failure once many servers are writing concurrently; a Snowflake ID solves both problems and adds shard routing for free." }
] }
```

## High-level design

```
Post service --> writes post to Posts DB --> publishes "post_created" event
                                                     |
                                          Fan-out worker (async)
                                                     |
                        looks up follower list, pushes post_id into each follower's feed_items
                        (Redis sorted set / Cassandra) — SKIPPED for celebrity accounts

Feed read path:
Client --> Feed API --> read feed_items[user_id] (Redis) --> hydrate post details from
           Post cache (Redis) / Posts DB --> merge in real-time query for celebrity
           follows the user has --> return page
```

At larger scale, add a search indexer and a trending aggregator reading off the same "post_created" event:

```
                            +-------------------------+--+----------------------+
                            |                          |                        |
                     Fan-out worker            Search indexer (async)   Trending aggregator
                    (skips celebrities)        (tokenize, push to          (sliding-window
                                                 Elasticsearch)             count of hashtags)
```

## Deep dives

### Fan-out on write vs. fan-out on read: the core decision

**Fan-out on write (push):** the moment a user posts, immediately push it into every follower's precomputed feed. A feed read becomes one cheap lookup. This wins for the common case, a user with a normal follower count, because it moves cost to write time, which is rare, and keeps reads, which happen roughly 200 times more often, fast.

**Fan-out on read (pull):** a feed read dynamically queries "give me recent posts from everyone I follow" and merges on the fly. No write amplification, but every read is now an expensive fan-in query across hundreds of relationships.

**The hybrid, what production systems actually run:** fan-out on write for normal users, and for celebrity or high-follower accounts (say, above 100,000 followers), skip the fan-out entirely, since pushing one post to 50 million `feed_items` rows is a write storm. Instead, merge their posts into the feed at read time: fetch the precomputed feed, separately check "any new posts from celebrities I follow" (a small, cacheable list), and interleave by timestamp.

> **Remember:** fan-out on write makes reads cheap and writes expensive; fan-out on read is the reverse. The hybrid picks whichever is cheap for each account, based on follower count.

```knowledge-check
{ "questions": [
    { "id": "system-design-feed-fanout-q1", "type": "mcq", "prompt": "Why do production feed systems use fan-out on read specifically for celebrity accounts, instead of applying it everywhere?", "options": [
        {"id": "a", "text": "Because fan-out on read is always faster"},
        {"id": "b", "text": "Because pushing one post to millions of followers' feeds at write time would be a write storm, while normal accounts have too few followers for that to matter"},
        {"id": "c", "text": "Because celebrity accounts post less often"},
        {"id": "d", "text": "Because fan-out on write doesn't work for text posts"}
    ], "correct": "b", "explanation": "The hybrid exists because the cost of fan-out on write scales with follower count. Below a threshold it's cheap; above it, it becomes a write storm that fan-out on read avoids." }
] }
```

### What about search, trending topics, and a viral post?

**Search doesn't belong in the primary transactional store.** Posts are asynchronously indexed into Elasticsearch (or a similar inverted-index engine), keyed by tokenized text, hashtags, and author. Search queries hit that index, not the posts database, which decouples search scaling (needs relevance scoring and inverted indexes) from write-path scaling (needs low-latency sharded writes). Accept a few seconds of indexing lag as the cost.

**Trending topics** are a streaming aggregation problem: maintain a sliding-window count of hashtag occurrences, using something like Redis `ZINCRBY` with time-bucketed keys, or a stream processor for larger scale. Decay older buckets, so trending reflects "spiking right now," not "popular historically." Without decay, an always-popular topic (a celebrity's name) would permanently occupy the trending list.

**A post going viral**, say jumping from 10,000 to 10 million impressions in minutes, stresses three layers at once. The fan-out system needs to dynamically promote the post to the read-merge path once engagement crosses a threshold, if it wasn't already there. The cache layer hits a hot-key problem, one post ID gets hammered, fixed with a local in-process cache on top of Redis or by replicating the hot key across multiple cache nodes. And like/retweet counters need to be incremented asynchronously through a counting service rather than a synchronous write per like, to avoid every fan hammering the same row lock.

### How do you shard so a post goes to the right place, and stays findable?

Shard posts and `feed_items` by `author_id` (or the shard bits already embedded in a Snowflake ID), using **consistent hashing** rather than `hash(user_id) % N`. A plain modulo remaps almost every key the moment N changes; consistent hashing only remaps the keys landing in a newly added node's range, which keeps resharding cheap. This makes "get a user's own posts" cheap, at the cost of a home timeline needing posts from many authors across many shards, which is exactly why the precomputed `feed_items` table exists: it pays the cost of gathering across shards once, at fan-out time, instead of on every read.

### Two things every feed design has to handle explicitly

**The cold-start problem.** A brand-new user follows nobody, so their feed is empty. Standard fixes: show trending or popular content as filler, prompt onboarding to follow suggested accounts, and backfill `feed_items` from a new followee's recent posts synchronously at follow-time, rather than waiting for the async fan-out worker.

**Ranking beyond chronological.** Pure `ORDER BY created_at DESC` is simple but buries good older posts. Algorithmic ranking scores each candidate post on recency, how often you interact with that author, and engagement velocity, then reorders the same candidate set the fan-out mechanism already produced. Ranking sits on top of fan-out, it never replaces the need for a candidate set to rank in the first place.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Fan-out hybrid (push + celebrity read-merge) | Fast reads for the common case, survives celebrity posts | Two code paths to build, test, and reason about |
| Feed storage in Redis sorted sets | Fast reads and writes | Memory-bound; cap feed length and evict old items |
| Shard by author_id with consistent hashing | Cheap "user's own posts" queries, cheap resharding | Home timeline needs the precomputed fan-out table to avoid a scatter-gather query |
| Separate search index (Elasticsearch) | Search scales independently of the write path | Indexing lag of a few seconds; two systems to keep in sync |
| Async counters for likes/retweets | Survives hot-row contention during a viral spike | Counts are eventually consistent, briefly stale under load |

**Q: A user with 50 million followers posts. Walk through what happens differently than for a normal user.**
A: The fan-out worker sees the follower count cross the threshold and skips the per-follower push entirely. The post is written once to the posts database and cache. Every follower's feed read does a lightweight merge: fetch their precomputed feed, separately check "recent posts from celebrities I follow," and interleave by timestamp.

**Q: How do you handle a user unfollowing someone right after a big fan-out just happened?**
A: The precomputed feed already has that author's recent posts in it. Either lazily filter them at read time by checking current follow status, or accept a short staleness window. Most products accept a few minutes of staleness here rather than pay for a full feed purge, since it's a minor visual glitch, not a correctness bug.

**Q: A post gets deleted. What has to happen across the system?**
A: The primary row is soft-deleted, not removed immediately, for audit and moderation. A deletion event propagates asynchronously to the search index (removed), the fan-out feed items (lazily filtered at read time, since deletes are rare relative to reads), and any cached copies (invalidated by post ID).

**Q: How do you shard so that adding capacity later doesn't mean moving all the data?**
A: Consistent hashing instead of a plain modulo. Only the keys landing in the newly added node's range get remapped, which minimizes data movement during a reshard.

```knowledge-check
{ "questions": [
    { "id": "system-design-feed-tradeoffs-q1", "type": "mcq", "prompt": "What is the practical cost of using consistent hashing instead of hash(user_id) % N for sharding?", "options": [
        {"id": "a", "text": "There is no cost, it is strictly better in every way"},
        {"id": "b", "text": "It adds some implementation complexity (a hash ring or virtual nodes) in exchange for only remapping a small fraction of keys when the shard count changes"},
        {"id": "c", "text": "It makes reads slower than a plain modulo"},
        {"id": "d", "text": "It only works for numeric keys"}
    ], "correct": "b", "explanation": "Consistent hashing trades a bit of extra implementation complexity for dramatically less data movement during a reshard, which is exactly the property that matters at scale." }
] }
```

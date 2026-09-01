---
kind: lesson
type: system_design
id_key: interview-prep-45/day-09-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Social Media Feed"
position: 9
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today's system is the news feed, the archetypal "design Facebook/Instagram feed" question. It's asked constantly because it forces a real decision under conflicting constraints: reads vastly outnumber writes, users expect near-instant feed loads, and "who sees what, in what order" is both a product and an engineering problem. Fan-out strategy is the crux of the whole design.

## Requirements

**Functional**
- Users post text/image/video content.
- Users follow other users.
- A user's home feed shows posts from people they follow, roughly newest-first.
- Users can like and comment on posts.
- Feed supports pagination/infinite scroll.

**Non-functional**
- Read-heavy: feed reads happen orders of magnitude more often than posts are written.
- Feed load latency target: under 200ms for the first page.
- Eventual consistency is acceptable (a like count lagging by a second is fine); a post disappearing is not.
- High availability over strict consistency: an outdated feed beats an error page.

## Capacity estimates

Assume 200M daily active users (DAU), each posting rarely but reading often.
- Posts/day: 200M users, 5% post daily, so 10M posts/day ≈ 116 posts/sec average, ~350/sec peak.
- Feed reads/day: each DAU opens the feed ~10 times/day, so 2B feed reads/day ≈ 23,000 reads/sec average, ~70,000/sec peak.
- Read:write ratio ≈ 200:1. This single number justifies almost every design decision below: aggressive caching, precomputed feeds, read replicas.
- Average follower count: most users have a few hundred follows; a celebrity may have 50M followers. This spread, the "celebrity problem," is the other design-defining number.
- Storage: 10M posts/day × 1 KB metadata = 10 GB/day metadata. Media (images/video) goes to blob storage/CDN, not the DB, and dominates storage, easily 100x the metadata size.

## API sketch

```
POST /posts                { text, media_urls[] }               -> { post_id, created_at }
GET  /feed?cursor=&limit=20                                       -> { posts[], next_cursor }
POST /posts/{id}/like                                              -> { like_count }
POST /posts/{id}/comments  { text }                                -> { comment_id }
GET  /posts/{id}/comments?cursor=                                  -> { comments[], next_cursor }
POST /follows               { target_user_id }
```

Use cursor-based pagination, not offset: offset pagination degrades badly (`OFFSET 50000` scans and discards 50,000 rows) and breaks under concurrent inserts (items shift between pages). The cursor is the last seen post's `(created_at, post_id)` tuple, encoded opaquely.

## Data model

```
users            id, username, ...
posts            id, author_id, text, media_urls, created_at
follows          follower_id, followee_id, created_at   PK(follower_id, followee_id)
likes            post_id, user_id, created_at            PK(post_id, user_id)
comments         id, post_id, author_id, text, created_at

-- the precomputed feed (fan-out on write), keyed for fast range reads
feed_items       user_id, post_id, author_id, created_at   -- one row per (feed owner, post)
                 PK(user_id, created_at, post_id)           -- sorted for cheap pagination
```

`feed_items` is a denormalized, per-user timeline. A Redis sorted set (`ZADD feed:{user_id} {timestamp} {post_id}`) or a wide-column store (Cassandra) works even better than relational for this write pattern: high write fan-out, simple range reads by user_id.

## High-level architecture

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

## Component deep dives

**Fan-out on write (push) vs fan-out on read (pull).** This is the core decision.
- *Fan-out on write*: when a user posts, immediately push the post into every follower's precomputed feed. Feed reads become a single cheap lookup (`ZRANGE feed:{user_id}`). Great for the common case (users with normal follower counts) because it moves cost to write time, which is rare, and keeps reads, which happen 200x more, fast.
- *Fan-out on read*: feed reads dynamically query "give me recent posts from everyone I follow" and merge on the fly. No write amplification, but every read is now an expensive fan-in query across hundreds of follow relationships.
- *Hybrid (what production systems actually do)*: fan-out on write for normal users; for celebrity/high-follower accounts (say, >100K followers), skip the fan-out, since pushing one post to 50M feed_items rows would be a write storm, and instead merge their posts into the feed at read time. The read path becomes: fetch precomputed feed_items, separately query "any new posts from the celebrities I follow," and merge by timestamp.

**Cold start / new user problem.** A brand-new user follows nobody yet (empty feed) or follows a handful of people with no fan-out history yet. Standard mitigations: show trending/popular content as filler, prompt onboarding to follow suggested accounts based on signup context, and backfill feed_items from the followees' recent posts (last N) synchronously at follow-time rather than waiting for the async fan-out worker to catch up.

**Ranking: chronological vs algorithmic.** Chronological is simple (`ORDER BY created_at DESC`) but underperforms on engagement, since old, high-quality posts get buried. Algorithmic ranking scores each candidate post by a weighted combination of recency, author affinity (how often you interact with this author), and predicted engagement (likes/comments velocity), then reorders the fan-out candidate set. This is applied on top of the fan-out mechanism, not instead of it; you still need a candidate set to rank.

**Pagination under a merged/ranked feed.** Cursor-based pagination gets trickier once ranking isn't purely time-ordered. A common trick is to paginate on a stable score+timestamp composite, or to generate and cache a ranked page-set per session so scrolling doesn't re-rank and shuffle already-seen items.

**Cache invalidation for likes/comments.** Counts are hot and mutate constantly. Store them denormalized on the post (`like_count` column) updated via an async counter service (Redis `INCR`, periodically flushed to the DB) rather than running `COUNT(*)` on every read.

## Scaling & trade-offs

| Layer | Approach | Trade-off |
|---|---|---|
| Feed storage | Redis sorted sets per user | Fast, but memory-bound; cap feed length (e.g., last 1000 items), evict older |
| Feed storage (durable) | Cassandra / wide-column | Higher write throughput at scale, more ops complexity than Redis |
| Celebrity posts | Read-time merge | Avoids write storm, adds read-time latency for celebrity-heavy feeds |
| Post content | CDN for media, DB/cache for metadata | Media dominates storage/bandwidth; never serve blobs from the app DB |
| Consistency | Eventual (feed lag of seconds is fine) | A "like" might briefly show a stale count, an acceptable trade for availability |

## Likely follow-up questions — with answers

**Q: A user with 50M followers posts. Walk me through what happens differently than a normal user.**
A: The fan-out worker detects the author's follower count exceeds a threshold and skips per-follower push entirely. The post is written once to the Posts DB/cache. Followers' feed reads perform a lightweight merge step: fetch their precomputed feed_items, separately check "recent posts from celebrities I follow" (a small, cacheable list per user), and interleave by timestamp before returning the page.

**Q: How do you handle a user unfollowing someone right after a big fan-out just happened?**
A: The precomputed feed already contains that author's recent posts. On unfollow, either lazily filter them out at read time (check follow-status of each post's author against a fast follow-index cache) or leave a short-lived staleness window. Most feed products accept a few seconds/minutes of staleness here rather than paying for a full feed_items purge, since it's a minor UX blip, not a correctness bug.

**Q: How would you test that the feed is truly eventually consistent and not silently dropping posts?**
A: Instrument the fan-out worker with delivery tracking: an event log of "post X should reach N followers" vs "post X was pushed to feed_items for N' followers," and alert on divergence. Add idempotent fan-out (dedup by post_id+follower_id) so retries after partial failure don't double-insert, and a reconciliation job that periodically re-derives a sample of feeds from source-of-truth follow and post data to catch drift.

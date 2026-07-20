---
kind: lesson
type: system_design
id_key: interview-prep-45/day-10-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 10 — Design Twitter/X"
position: 10
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Twitter/X is the classic "design a large-scale social system" interview — it builds directly on yesterday's feed design but adds search, viral-content handling, and explicit sharding, which is why it's a favorite for senior-level rounds. Today you go one level deeper than the feed lesson: full tweet storage strategy, search infra, and how a single system survives a tweet going viral to 100M impressions in an hour.

## Requirements

**Functional**
- Post a tweet (280 chars + media), follow/unfollow, home timeline, user timeline.
- Search tweets by keyword/hashtag.
- Like, retweet, reply.
- Trending topics.

**Non-functional**
- Massive read:write skew (same as feed — reads dominate).
- Low write latency for tweet creation (<200ms).
- Timeline read latency <200ms at p99.
- High availability; eventual consistency acceptable for counts/timelines.
- Must survive a single tweet or account going viral without degrading the whole system.

## Capacity estimates

Assume 300M DAU, 500M tweets/day globally (X's real published order of magnitude).
- Writes: 500M / 86,400 ≈ 5,800 tweets/sec average, ~15,000/sec peak (events, sports, breaking news).
- Reads: timeline views ~300M users × 15 opens/day = 4.5B reads/day ≈ 52,000 reads/sec average, 150,000+/sec peak.
- Read:write ratio ≈ 10:1 on raw counts but the *fan-out* multiplier is what matters: one tweet from a 50M-follower account, if pushed to every follower's timeline, is 50M writes from a single tweet — this is why celebrity fan-out must be handled specially (see Day 9).
- Storage: 500M tweets/day × ~300 bytes (text + metadata, media excluded) = 150 GB/day of tweet metadata; at 5 years retention that's ~270 TB — this alone forces sharding of the tweet store.

## API sketch

```
POST /tweets            { text, media_urls[], reply_to? }        -> { tweet_id, created_at }
GET  /timeline/home?cursor=&limit=20                               -> { tweets[], next_cursor }
GET  /timeline/user/{user_id}?cursor=
POST /tweets/{id}/like
POST /tweets/{id}/retweet
GET  /search?q=&cursor=                                            -> { tweets[], next_cursor }
GET  /trending?region=
```

## Data model

```
tweets            id (snowflake), author_id, text, media_urls, reply_to_id, created_at
users             id, username, follower_count, following_count
follows           follower_id, followee_id
timeline_items    user_id, tweet_id, created_at   -- precomputed home timeline (fan-out)
likes             tweet_id, user_id
retweets          tweet_id, user_id, created_at

-- search index (separate system, not the primary DB)
tweet_search      tweet_id, tokens[], author_id, created_at, engagement_score
```

**Tweet ID generation** matters at this scale: use a Snowflake-style ID (timestamp bits + shard/worker bits + sequence bits) rather than an auto-increment column. This gives globally unique, roughly time-sortable IDs without a single point of contention, and the ID itself encodes enough to route to the correct shard.

## High-level architecture

```
Write path:
Client --> Tweet Service --> assign snowflake ID --> write to sharded Tweets DB
                                                    --> publish "tweet_created" event
                                                          |
                            +-------------------------+--+----------------------+
                            |                          |                        |
                     Fan-out worker            Search indexer (async)   Trending aggregator
                    (skips celebrities,      (tokenize, push to          (sliding-window
                     see Day 9 hybrid)         Elasticsearch)             count of hashtags)

Read path (home timeline):
Client --> Timeline Service --> read timeline_items (Redis) --> merge celebrity posts
           at read time --> hydrate tweet content (cache-first) --> return page
```

## Component deep dives

**Fan-out on write vs read (recap + Twitter-scale specifics).** Same hybrid as the general feed design: fan-out on write for normal accounts (push tweet_id into every follower's `timeline_items`), fan-out on read for celebrity accounts. At Twitter's actual scale, this hybrid is not optional — it's the only way the write path survives.

**Sharding the tweet store.** Shard by `author_id` (or by the shard bits embedded in the snowflake tweet ID) so a user's own tweets colocate — cheap for "get user's tweet history." The trade-off: a home timeline needs tweets from many authors across many shards, which is exactly why the precomputed `timeline_items` table exists — it avoids doing a scatter-gather query across shards on every timeline read. Read amplification is paid once, at fan-out time, not on every read.

**Search.** Full-text search does not belong in the primary transactional store. Tweets are asynchronously indexed into Elasticsearch (or a similar inverted-index engine) keyed by tokenized text, hashtags, and author. Search queries hit Elasticsearch, not the tweets DB. This decouples search scaling (which needs different infra — inverted indexes, relevance scoring) from write-path scaling (which needs low-latency sharded writes). Accept a small indexing lag (seconds) as the consistency cost.

**Trending topics.** A streaming aggregation problem: maintain a sliding-window count of hashtag/keyword occurrences (e.g., using Redis `ZINCRBY` with time-bucketed keys, or a stream processor like Flink/Kafka Streams for larger scale). Decay older buckets so trending reflects "spiking now," not "popular historically" — a naive all-time counter would let old dominant topics (like a person's name) permanently occupy the trending list.

**Handling viral content.** A single tweet crossing from 10K to 10M impressions in minutes stresses multiple layers simultaneously: the fan-out system (if not already using the celebrity read-merge path, promote the tweet dynamically once engagement crosses a threshold), the cache layer (hot-key problem — one tweet_id gets hammered; mitigate with local in-process caching on top of Redis, or replicate the hot key across multiple cache nodes), and the like/retweet counters (batch/async increment via a counting service rather than a synchronous DB write per like, to avoid row-lock contention on one hot row).

**Database sharding strategy, explicitly.** Shard tweets and timeline_items by user_id (consistent hashing across shard nodes so adding shards doesn't require a full re-shuffle). Keep a separate, smaller "social graph" service (follows) that can be sharded independently, since its access pattern (who follows whom) differs from tweet storage's pattern. Use a routing/lookup layer (or embed shard info in the ID itself, as snowflake IDs do) so any service can find the correct shard without a central directory becoming a bottleneck.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Snowflake IDs | No single-point contention, roughly sortable, shard-routable | Requires coordinated worker/shard ID allocation |
| Fan-out hybrid | Fast normal-case reads, survives celebrity posts | Two code paths to maintain and test |
| Separate search index | Search scales independently, doesn't burden write path | Indexing lag; two systems to keep in sync |
| Shard by author_id | Cheap "user's tweets" queries | Timeline reads need the precomputed fan-out table to avoid scatter-gather |
| Async counters for likes | Survives viral hot-row contention | Counts are eventually consistent, briefly stale under load |

## Likely follow-up questions — with answers

**Q: How do you shard so that resharding later (adding capacity) doesn't require moving all the data?**
A: Use consistent hashing (or a directory-based shard map with virtual nodes) instead of `hash(user_id) % N`, where N changing remaps almost every key. Consistent hashing only remaps the keys that land in the newly added node's range, minimizing data movement during a reshard.

**Q: A tweet gets deleted. What has to happen across the system?**
A: The primary tweets row is marked deleted (soft delete, not physically removed immediately, for audit/moderation). A deletion event propagates asynchronously to: the search index (remove/mark from Elasticsearch), the fan-out timeline_items (either lazily filtered at read time by checking tweet status, or eagerly purged via a background job — lazy filtering is cheaper given how rarely deletes happen relative to reads), and any cached copies (invalidate by tweet_id).

**Q: How would you rank search results, not just match them?**
A: Combine text relevance (Elasticsearch's BM25 score) with a recency decay factor and an engagement signal (likes/retweets, log-scaled so viral tweets don't completely dominate). This is computed either at query time as a composite score, or precomputed periodically and stored as an `engagement_score` field the query can sort/filter on for speed.

## Key takeaways

- Snowflake-style IDs solve two problems at once: unique ID generation without central contention, and implicit shard routing.
- The fan-out hybrid (write for normal accounts, read-merge for celebrities) from Day 9 is not optional at Twitter scale — it's the core write-path design.
- Search is a separate system (Elasticsearch) fed asynchronously — never run full-text search against the primary transactional store.
- Shard by author_id for cheap per-user queries; pay the fan-out cost once at write time so timeline reads don't need scatter-gather across shards.
- Viral content stresses cache hot-keys and counter contention specifically — plan for local caching layers and async batched counters, not just "add more read replicas."
- Consistent hashing (not naive modulo) is the answer whenever a follow-up asks about resharding without full data movement.

## Today's checklist

- [ ] Write functional requirements: tweets, timeline, followers.
- [ ] Write non-functional requirements: latency, consistency targets.
- [ ] Design tweet storage with fan-out on write vs read, and the celebrity hybrid.
- [ ] Design search as a separate async-indexed system.
- [ ] Explain how the design survives a viral tweet.
- [ ] Define the database sharding strategy (key choice + consistent hashing).

---
kind: lesson
type: system_design
id_key: interview-prep-45/day-11-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 11 — Search Autocomplete System"
position: 11
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Autocomplete (typeahead search) is asked because it's small enough to fully design in 45 minutes yet touches a data structure (the trie), a ranking problem, and a hard latency constraint (sub-100ms, on every keystroke). It's a great test of whether you can pick the right precomputation strategy instead of reaching for "just query the DB."

## Requirements

**Functional**
- As a user types a prefix, return the top-K most relevant completions.
- Suggestions should reflect popularity/frequency of past searches.
- Update suggestions as new queries come in (not static forever).

**Non-functional**
- Latency: under 100ms per keystroke (ideally under 50ms) — this is a UX-critical constraint, not a nice-to-have.
- High read QPS (fired on nearly every keystroke of every active user).
- Freshness: trending queries should surface within minutes to hours, not require a full daily rebuild.
- Availability over strict consistency — a slightly stale suggestion list beats a slow/failed one.

## Capacity estimates

Assume a search product with 500M searches/day.
- Each search query averages ~20 characters typed → roughly 20 autocomplete requests per search (one per keystroke, though clients typically debounce/throttle this).
- Raw keystroke events: 500M × 20 = 10B/day ≈ 116,000/sec average, but client-side debouncing (only fire after ~150-200ms pause, or every 2-3 characters) cuts this by 5-10x in practice — still tens of thousands of QPS.
- Unique historical queries to index: assume 100M unique query strings, average 20 bytes each = 2 GB raw text — small enough to fit a trie or a precomputed top-K table entirely in memory.
- Update volume: new/incremented queries per day ~500M events need to feed back into rankings, but this can be batched (e.g., hourly) rather than applied per-query in real time.

The key number: query *volume* is huge, but the *unique query space* is small enough to precompute and cache aggressively. That asymmetry drives the whole design.

## API sketch

```
GET /autocomplete?prefix=piz&limit=10
  -> { suggestions: ["pizza near me", "pizza hut", "pizza recipe", ...] }
```

That's essentially the whole external API — the complexity is entirely in how the backend serves it fast and keeps it fresh.

## Data model

**Trie (in-memory serving structure)** — each node represents one character; each node caches its own top-K most frequent completions so a lookup doesn't need to walk the full subtree at request time.

```
TrieNode
  children: map[char]TrieNode
  top_k: [(query_string, frequency)]   -- precomputed, sorted desc, size K (e.g., 10)
```

**Backing store for raw frequency data** (source of truth, rebuilt from periodically):

```
query_frequency
  query_text   TEXT
  count        BIGINT
  last_seen    TIMESTAMPTZ
PRIMARY KEY (query_text)
```

## High-level architecture

```
Search logs / query events --> Aggregation job (batch, e.g. hourly Spark/Flink job)
                                     |
                          updates query_frequency counts
                                     |
                          Trie builder job --> builds new trie snapshot
                                     |
                          pushes snapshot to Trie-serving nodes (in-memory, sharded by prefix)
                                     |
Client keystroke --> Autocomplete API --> route to shard owning this prefix --> return top_k
                                        --> (cache hot prefixes in a CDN/edge cache too)
```

## Component deep dives

**The trie, and why each node precomputes top-K instead of ranking at query time.** A naive trie lookup walks to the prefix's node then does a subtree traversal collecting all completions to rank them — that traversal is what kills the latency budget for common short prefixes ("a", "th") that fan out into millions of completions. The fix: precompute and cache the top-K results *at each node* during the (offline) trie-build step. A query-time lookup then costs O(prefix length) to reach the node, plus O(1) to return the cached top-K — no traversal, no live ranking. This is the single most important design decision in the whole system.

**Ranking signal.** Simplest: raw historical frequency. Better: a decayed frequency (`score = count * decay(time_since_last_seen)`) so a topic that was popular a year ago but has gone cold drops out of suggestions, while genuinely trending queries rise fast. Optionally blend in personalization (user's own search history) as a secondary re-rank on top of the global top-K, applied client-side or in a thin personalization layer, not baked into the shared trie.

**Real-time updates without rebuilding the whole trie.** Two-tier approach: the main trie snapshot rebuilds periodically (e.g., hourly, from batched aggregated counts — cheap and consistent). For queries that spike faster than that cadence (breaking news, trending topics), maintain a small, separately-updated "hot" structure (a bounded in-memory count-min sketch or a simple hash map of trending terms updated in near-real-time) that gets merged into the returned suggestions at query time as an overlay on top of the base trie's top-K. This avoids the cost of rebuilding a multi-GB trie on every new query while still surfacing genuinely fast-moving trends.

**Storage and scalability.** The full trie for a large query space is memory-bound, not disk-bound — it needs to live in RAM for latency. Shard the trie by first N characters of the prefix (e.g., first 1-2 letters route to different serving nodes) so no single node holds the entire structure and query load spreads across shards. Replicate each shard for availability and read throughput. Rebuilding: build the new trie snapshot offline on a builder node, then hot-swap it into serving nodes (blue/green deploy of the in-memory structure) so there's no downtime and no query-time cost from the rebuild.

**Handling the empty/short-prefix problem.** A one or two character prefix ("a", "th") matches an enormous number of queries. Precomputed top-K solves the ranking cost, but you should also rate-limit or debounce client requests for very short prefixes since the suggestions are low-value (too broad) and expensive to keep maximally fresh — many products simply don't fire autocomplete until 2+ characters are typed.

## Scaling & trade-offs

| Choice | Benefit | Cost |
|---|---|---|
| Precomputed top-K per trie node | O(prefix length) query latency | Rebuild cost when frequencies change; some staleness between rebuilds |
| Batch (hourly) trie rebuild | Simple, consistent, cheap | Not truly real-time — mitigated by the hot-term overlay |
| Sharding by prefix | Distributes load and memory across nodes | Cross-shard queries impossible (fine — a prefix only ever needs one shard) |
| In-memory serving | Meets the <100ms budget | Memory cost scales with unique query space; must fit per shard |
| Edge/CDN caching of very common prefixes | Cuts backend load and latency further | Cache invalidation adds a bit of staleness on top of trie staleness |

## Likely follow-up questions — with answers

**Q: How do you keep the trie fresh without rebuilding it constantly?**
A: Two-tier updates — a periodic (e.g., hourly) full rebuild from batched frequency aggregation for the stable long tail, plus a lightweight, frequently-updated "trending" overlay (count-min sketch or bounded hash map) for queries spiking faster than the rebuild cadence. The API merges both at response time, so genuinely new trends surface within minutes while the bulk of the structure stays cheap to maintain.

**Q: The trie for the full query space doesn't fit in one machine's memory. What do you do?**
A: Shard by prefix (e.g., first character or first two characters route to different nodes), so each serving node only holds a fraction of the trie. A request for prefix "piz" is routed by a thin routing layer to the shard responsible for "p" (or "pi"), which fully resolves the query without needing data from other shards.

**Q: How would you personalize suggestions per user without breaking the shared trie's precomputation?**
A: Keep the shared trie's top-K global and un-personalized — that's what makes precomputation cheap and shareable across all users. Apply personalization as a thin re-ranking step after fetching the global top-K: boost or inject items from the user's own recent search history (a small, per-user cache, not part of the trie), merged client-side or in a lightweight per-request layer.

## Key takeaways

- Precompute top-K completions at each trie node during an offline build step — this is what makes query-time latency O(prefix length) instead of requiring a live subtree ranking scan.
- Query volume is huge, but the unique query space is small and fits in memory — that asymmetry is why this is a caching/precomputation problem, not a live-query problem.
- Freshness comes from a two-tier update strategy: periodic full rebuild plus a fast-updating overlay for trending terms.
- Shard the trie by prefix to fit memory and distribute load; a query only ever needs one shard.
- Rank by decayed frequency, not raw lifetime count, so stale-but-once-popular queries fade out.
- Personalization is a re-ranking layer on top of the shared global trie, not a per-user trie.

## Today's checklist

- [ ] Write functional requirements: prefix matching, ranking.
- [ ] Write non-functional requirements: latency budget, freshness target.
- [ ] Design the trie structure with precomputed top-K per node.
- [ ] Design the ranking algorithm (frequency + decay).
- [ ] Handle real-time/trending updates without full rebuilds.
- [ ] Discuss storage sharding and scalability of the in-memory trie.

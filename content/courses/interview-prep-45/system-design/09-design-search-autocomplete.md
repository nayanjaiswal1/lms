---
kind: lesson
type: system_design
id_key: interview-prep-45/day-11-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Search Autocomplete System"
position: 9
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

Autocomplete (typeahead) shows suggestions as you type, like Google guessing "pizza near me" after you type "piz". It's a favorite interview question because it's small enough to fully design in 45 minutes, yet it touches a real data structure (the trie), a ranking problem, and a hard latency limit: it fires on almost every keystroke, so it has to be fast.

## Requirements

**Functional requirements**
- As a user types a prefix, return the top-K most relevant completions.
- Suggestions reflect how popular a query has actually been.
- Suggestions update as new searches come in; they aren't frozen forever.

**Non-functional requirements**
- Latency under 100ms per keystroke, ideally under 50ms. This is a hard UX limit, not a nice-to-have.
- Very high read volume, since it fires on nearly every keystroke of every active user.
- Freshness: a trending query should surface within minutes to hours, not wait for a full daily rebuild.
- Availability over strict consistency: a slightly stale suggestion list beats a slow or failed one.

> **Remember:** autocomplete has to be fast enough that the user never notices it's a network call at all. That single constraint is what rules out "just query the database" as an answer.

```knowledge-check
{ "questions": [
    { "id": "system-design-autocomplete-requirements-q1", "type": "mcq", "prompt": "Why is a sub-100ms latency requirement unusually strict for autocomplete compared to most other API endpoints?", "options": [
        {"id": "a", "text": "It isn't strict, 100ms is a normal API latency target"},
        {"id": "b", "text": "Because it fires on nearly every keystroke, so any lag is immediately visible to the user as the UI feels laggy"},
        {"id": "c", "text": "Because databases cannot respond faster than 100ms"},
        {"id": "d", "text": "Because autocomplete only runs once per search"}
    ], "correct": "b", "explanation": "Unlike a page load that happens once, autocomplete requests fire continuously as someone types, so any lag compounds into a visibly sluggish experience." }
] }
```

## Estimates

Assume a search product with 500 million searches a day, and each typed query averages about 20 characters, meaning roughly 20 potential autocomplete requests per search.

- **Raw keystroke events:** 500M × 20 = 10 billion/day, about 116,000/sec average. Client-side debouncing, only firing after a short pause or every few characters, cuts this 5-10x in practice, still tens of thousands of requests per second.
- **Unique query space:** assume 100 million unique query strings, about 20 bytes each, 2 GB of raw text. Small enough to fit an entire trie, or a precomputed top-K table, in memory.
- **Update volume:** roughly 500M query events a day need to feed back into rankings, but this can be batched (hourly, say) rather than applied instantly.

The number that matters most: query *volume* is enormous, but the unique query *space* is small enough to precompute and hold entirely in memory. That gap between "huge traffic" and "small unique data" is what makes this design possible.

## API

```
GET /autocomplete?prefix=piz&limit=10
  -> { suggestions: ["pizza near me", "pizza hut", "pizza recipe", ...] }
```

That's essentially the whole external contract. Every bit of complexity lives in how the backend serves this fast and keeps it fresh, which is what the rest of this lesson covers.

## Data model

The serving structure is a **trie**: a tree where each node represents one character, so walking from the root spells out a prefix. Picture climbing a tree letter by letter, "p" then "i" then "z", and each branch you take narrows down to fewer and fewer matching words. Each node also caches its own top-K most frequent completions, so a lookup never has to explore the rest of the tree below it.

```
TrieNode
  children: map[char]TrieNode
  top_k: [(query_string, frequency)]   -- precomputed, sorted desc, size K (e.g., 10)
```

The trie is rebuilt from a source-of-truth table that tracks how often each query has actually been searched:

```
query_frequency
  query_text   TEXT
  count        BIGINT
  last_seen    TIMESTAMPTZ
PRIMARY KEY (query_text)
```

## High-level design

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

Search activity feeds a batch job that periodically recomputes frequency counts, a separate job builds a fresh trie snapshot from those counts, and that snapshot gets pushed out to the servers actually answering requests. The path a user's keystroke takes is short and entirely in-memory: hit the API, route to the shard that owns this prefix, return the cached top-K.

## Deep dives

### Why does every trie node precompute its own top-K, instead of ranking at query time?

This is the single most important decision in the whole design. A naive trie lookup walks down to the prefix's node, then explores the entire subtree below it to collect and rank every possible completion. For a short, common prefix like "a" or "th", that subtree can hold millions of words, and ranking all of them at request time blows straight through your latency budget.

The fix: do that ranking once, offline, while building the trie, and cache the answer directly on the node. A query then costs O(prefix length) to walk down to the right node, plus O(1) to return the cached list. No live ranking, no subtree walk, on the request path at all.

> **Remember:** precomputing the top-K per node is what turns "rank millions of completions" into "look up a cached answer." Do the expensive work once, offline, not on every keystroke.

```knowledge-check
{ "questions": [
    { "id": "system-design-autocomplete-trie-q1", "type": "mcq", "prompt": "Why can't autocomplete rank completions at query time for a short prefix like \"a\"?", "options": [
        {"id": "a", "text": "Short prefixes are technically invalid input"},
        {"id": "b", "text": "A short prefix can match millions of completions, and ranking all of them live would blow the latency budget"},
        {"id": "c", "text": "The trie data structure cannot handle prefixes shorter than 3 characters"},
        {"id": "d", "text": "Ranking at query time is actually fine and commonly done"}
    ], "correct": "b", "explanation": "The whole point of precomputing top-K per node is to avoid exactly this: exploring a huge subtree and ranking it within a single request's time budget." }
] }
```

### How do you rank completions, and keep them fresh without rebuilding everything?

The simplest ranking signal is raw historical frequency. A better one decays frequency over time (`score = count * decay(time_since_last_seen)`), so a query that was popular a year ago fades out while genuinely trending queries rise quickly. Personalization, boosting a user's own recent searches, is applied as a thin re-ranking step on top of the shared global top-K, not baked into the trie itself, which keeps the trie shareable across every user.

Freshness is solved with two tiers, not one. The main trie snapshot rebuilds on a slower, predictable cadence, say hourly, from batched aggregated counts: cheap and consistent, but not instant. For anything spiking faster than that, like breaking news, maintain a small, separately-updated "hot" structure, a bounded count-min sketch or a simple hash map of trending terms updated in near real time, and merge it into the response at query time as an overlay on top of the trie's cached top-K. This avoids rebuilding a multi-gigabyte trie every time one query spikes, while still surfacing genuinely fast-moving trends within minutes.

### How does one server hold a query space that doesn't fit in memory?

The trie needs to live entirely in RAM to hit the latency target, which means it's memory-bound, not disk-bound. Once the full query space is too big for one machine, shard the trie by the first character or two of the prefix, so different servers each hold only a slice of the structure. A request for "piz" routes to whichever shard owns prefixes starting with "p" (or "pi"), and that one shard fully answers it without needing data from anywhere else. Replicate each shard for availability and extra read throughput. When it's time to rebuild, build the new snapshot on a separate builder node and hot-swap it into the serving nodes, the in-memory equivalent of a blue/green deploy, so there's no downtime and no query pays a rebuild cost.

Very short prefixes ("a", "th") are both the highest-traffic case and the least useful one, since the results are too broad to be helpful. Many products simply don't fire autocomplete until the user has typed at least two characters, which also cuts a meaningful amount of load.

## Trade-offs and follow-up questions

| Choice | Benefit | Cost |
|---|---|---|
| Precomputed top-K per trie node | O(prefix length) query latency | Rebuild cost when frequencies change; some staleness between rebuilds |
| Batch (hourly) trie rebuild | Simple, consistent, cheap | Not truly real-time, fixed by the hot-term overlay |
| Sharding by prefix | Spreads load and memory across nodes | A prefix only ever needs one shard, so cross-shard queries are simply never needed |
| In-memory serving | Meets the sub-100ms budget | Memory cost scales with the unique query space and must fit per shard |
| Edge/CDN caching of common prefixes | Cuts backend load and latency further | Adds a small extra layer of staleness on top of the trie's own |

**Q: How do you keep the trie fresh without rebuilding it constantly?**
A: A two-tier approach: a periodic full rebuild (hourly, say) from batched frequency aggregation covers the stable long tail cheaply, plus a lightweight, frequently-updated trending overlay covers anything spiking faster than that cadence. The API merges both at response time.

**Q: The trie for the full query space doesn't fit on one machine. What do you do?**
A: Shard by prefix, first character or first two characters, so each serving node holds only a fraction of the trie. A thin routing layer sends each request to the one shard that can fully answer it.

**Q: How would you personalize suggestions per user without breaking the shared trie's precomputation?**
A: Keep the shared trie's top-K global and un-personalized, since that's what makes the precomputation cheap and reusable across every user. Apply personalization afterward, as a thin re-ranking step that boosts items from a small, per-user cache of recent searches.

```knowledge-check
{ "questions": [
    { "id": "system-design-autocomplete-tradeoffs-q1", "type": "mcq", "prompt": "Why is personalization applied as a re-ranking step on top of the shared trie, instead of baking each user's history directly into the trie?", "options": [
        {"id": "a", "text": "Personalization is not actually useful for autocomplete"},
        {"id": "b", "text": "Baking per-user data into the trie would mean building a separate trie per user, losing the shared, cheap precomputation that makes the system fast"},
        {"id": "c", "text": "Tries cannot store more than one ranking per node"},
        {"id": "d", "text": "Re-ranking is always faster than precomputation"}
    ], "correct": "b", "explanation": "The whole design depends on one shared, precomputed structure serving every user cheaply. Personalizing the trie itself would multiply the memory and rebuild cost by the number of users." }
] }
```

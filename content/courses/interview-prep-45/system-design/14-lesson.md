---
kind: lesson
id_key: interview-prep-45/day-14-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Checkpoint 2"
position: 14
estimated_minutes: 36
source:
    - 45-day-interview-roadmap.md
---
This is a consolidation day, not a new exercise. You've now designed six systems (Job Queue, Social Media Feed, Twitter/X, Search Autocomplete, File Storage, Netflix). The goal today is to compress them into reusable patterns you can pull out under interview pressure, and to self-test whether you actually retained the reasoning, not just the diagrams. Interviewers notice when a candidate re-derives the same trade-off analysis fluently across different systems versus when they memorized one system's answer.

## Why review days exist

Six systems in six days builds breadth, but breadth without consolidation decays fast: you'll misremember which trade-off belonged to which system. The fix is to extract the transferable decisions. The same handful of patterns reappear across almost every real-world system design question, just recombined. Spend today building your own mental index of those patterns instead of six disconnected case studies.

## The patterns that recurred across this week

**1. Read:write ratio drives caching and precomputation aggressiveness.**
- Job Queue: writes (enqueue) and reads (dequeue) are roughly balanced. No aggressive read caching needed; the design instead focuses on delivery guarantees.
- Feed / Twitter: reads outnumber writes 100-1000:1. This single ratio justified fan-out-on-write and precomputed timelines.
- Autocomplete: read volume (keystrokes) is enormous relative to the unique query space that needs updating, which justified precomputing top-K per trie node.
- **Takeaway to reuse:** always compute this ratio early in any interview and let it explicitly drive your caching/precomputation decisions instead of caching "because caching is good."

**2. Fan-out on write vs fan-out on read is the same trade-off, reused.**
- Feed and Twitter both hit this directly: push data to every reader at write time (fast reads, expensive/bursty writes) vs. compute at read time (cheap writes, expensive reads).
- The resolution was always a hybrid gated by a threshold (celebrity accounts skip fan-out-on-write). Recognize this pattern the moment a system has a "some entities are read by way more people than average" shape.

**3. Separate the durable source of truth from the fast serving structure.**
- File Storage: metadata DB (source of truth) vs. blob storage (bytes) vs. sync cursor (serving state).
- Autocomplete: `query_frequency` table (source of truth) vs. in-memory trie (serving structure, periodically rebuilt).
- Netflix: raw uploaded video (source) vs. encoded variants plus CDN cache (serving structure).
- **Takeaway to reuse:** whenever a system needs both correctness/durability and low-latency reads, expect two stores, one authoritative and slow-changing, one derived and fast, connected by an async pipeline rather than making one store do both jobs.

**4. Idempotency and content-addressing solve "what if this happens twice."**
- Job Queue: idempotent handlers plus dedup keys turn at-least-once delivery into exactly-once effects.
- File Storage: content-addressed chunk hashes make resume and dedup fall out for free. Uploading the same bytes twice is naturally a no-op.
- **Takeaway to reuse:** any time a follow-up asks "what if the network duplicates/retries this," the answer is almost always deterministic keys (hash of content, or an explicit idempotency key) checked before the side effect runs.

**5. Explicit CAP trade-offs, stated out loud, per system.**
- Netflix: availability over consistency, never block playback on progress sync.
- Feed/Twitter: availability over consistency, a stale like count or a few seconds of feed lag is fine.
- Job Queue: at-least-once delivery is itself a consistency/availability trade-off, choosing to risk duplicate execution rather than risk silently dropping work.
- **Takeaway to reuse:** name the trade-off explicitly in every design ("I'm choosing availability here because X"). Interviewers are listening for whether you know you're making a choice, not just whether you land on a defensible one.

**6. Sharding key choice determines what's cheap and what's expensive.**
- Twitter: sharding tweets by author_id makes "user's own tweets" cheap and "everyone I follow" expensive (solved by precomputed fan-out, not by the shard key).
- File Storage: sharding metadata by owner_id makes "my files" cheap; cross-user sharing needs a separate lookup.
- **Takeaway to reuse:** picking a shard key is picking which query pattern is fast. Always state which access pattern you're optimizing for and what becomes a cross-shard query as a result.

## Self-check — quiz yourself before moving on

Answer these without looking back at the lesson files. If you hesitate on any, revisit that day.

1. Why does at-least-once delivery combined with idempotent handlers behave like exactly-once, without ever actually guaranteeing exactly-once delivery?
2. What specific problem does the celebrity/hybrid fan-out solve, and at what threshold would you switch a normal account's posts to read-time merging?
3. Why is precomputing top-K suggestions at each trie node the key design decision in autocomplete, rather than just "using a trie"?
4. In the file storage design, what does `ref_count` on the `chunks` table protect against, and why would deleting a file without it be dangerous?
5. Name two systems this week that explicitly favored availability over consistency, and describe the concrete user-facing consequence of that choice in each.
6. Why does sharding tweets/files by owner/author id make "my own content" queries cheap but "content from everyone I follow" queries expensive, and what pattern from this week fixes that?

## Where the six systems differed (don't over-generalize)

Not everything is reusable; know the differences too:
- Job Queue is the only system this week where ordering guarantees were a first-class design axis (partition-key-based ordering) rather than an afterthought.
- Netflix is the only system dominated by raw bandwidth/egress capacity math rather than request/query throughput. The capacity estimate that mattered most was Tbps, not QPS.
- Autocomplete is the only system where the entire correctness structure (the trie) lives in memory as the primary serving path, not as a cache in front of a database.

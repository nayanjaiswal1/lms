---
kind: lesson
id_key: interview-prep-45/day-21-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Checkpoint 3"
position: 21
estimated_minutes: 36
source:
    - 45-day-interview-roadmap.md
---
Second consolidation day. This week covered Uber, Spotify, Google Docs, Airbnb, WhatsApp, and Ticketmaster, a noticeably different cluster than week one: geospatial matching, real-time collaboration, and hard consistency under contention replace the read-heavy feed/CDN problems from before. Today's job is the same as Day 14's: extract transferable patterns and self-test, not re-derive each system from scratch.

## Why review days exist

Same reasoning as Day 14: six systems compress into a handful of reusable decisions. This week's cluster is unified by a theme the previous week barely touched: strong consistency and real-time coordination under contention (booking a ride, editing a doc simultaneously, buying the last seat) instead of "how do we serve read-heavy traffic fast." Notice which lever you reach for changes accordingly.

## The patterns that recurred across this week

**1. Geospatial matching needs a spatial index, not a full table scan.**
- Uber: matching riders to nearby available drivers is fundamentally a "find the K nearest points" problem. The standard answer is a geospatial index, geohashing (encode lat/long into a string prefix, so nearby locations share prefixes) or a quadtree/R-tree, combined with an in-memory store (Redis geospatial commands are a common concrete choice) so driver locations, which change every few seconds, don't require re-indexing a disk-backed structure on every update.
- Airbnb's search-by-location (find listings within a map viewport) hits a lighter version of the same problem: bounding-box or geohash-prefix queries against a spatial index, refreshed far less often than Uber's live driver positions since listings don't move.
- **Takeaway to reuse:** whenever a system needs "nearest N" or "within this area" queries, name a spatial index explicitly (geohash/quadtree/R-tree). Don't default to a relational `WHERE lat BETWEEN...AND long BETWEEN...` scan, which doesn't scale.

**2. Real-time collaboration needs either OT or CRDTs, and the interview wants you to know the trade-off exists.**
- Google Docs: concurrent edits from multiple users to the same document are reconciled either via Operational Transformation (transform each incoming operation against concurrent operations so they compose correctly regardless of arrival order, what Docs historically used) or CRDTs (Conflict-free Replicated Data Types, data structures mathematically guaranteed to converge regardless of operation order, increasingly the modern choice, e.g., Yjs/Automerge).
- **Takeaway to reuse:** "how do concurrent edits merge" is a distinct sub-problem from "how do edits sync/transport." Transport can be a simple WebSocket fan-out; the merge algorithm (OT vs CRDT) is the actual hard part and is what the interviewer wants named.

**3. Messaging systems trade delivery guarantees against ordering and end-to-end privacy.**
- WhatsApp: message delivery needs at-least-once guarantees (never silently drop a message) with client-side deduplication (message IDs), ordering per-conversation (not globally), and, distinctively, end-to-end encryption, meaning the server relays ciphertext it cannot read. That constrains server-side features: no server-side search/indexing of message content, and message queuing for offline recipients still keyed by opaque IDs.
- This is the same at-least-once-plus-idempotency pattern from Week 1's Job Queue, applied to a person-to-person delivery context instead of a worker-execution context.
- **Takeaway to reuse:** recognize "at-least-once delivery + client dedup" as the same solved pattern across queues, feeds, and messaging. You're not re-deriving it, you're reapplying it.

**4. Hard consistency under contention needs atomic conditional writes, not "just use a transaction" hand-waving.**
- Ticketmaster: double-booking prevention via optimistic concurrency (compare-and-swap on the seat row) or Redis `SETNX`-with-TTL.
- Uber: assigning a driver to a rider has the same shape. Two ride requests should never atomically claim the same driver; the assignment step needs the same conditional-update guarantee.
- Airbnb: booking the same listing for overlapping dates needs the same atomicity, typically enforced via a DB constraint (exclusion constraint on date ranges) rather than purely application logic.
- **Takeaway to reuse:** any time a follow-up asks "what if two requests race for the same resource," the answer is an atomic conditional write at the data layer (compare-and-swap, unique/exclusion constraint, or a distributed lock with TTL as a last resort), never "wrap it in a transaction" alone, since a transaction doesn't prevent two separate transactions from both reading "available" before either commits.

**5. Presence/liveness (who's online, where's the driver right now) is a high-frequency-write, low-durability-need problem.**
- Uber's live driver location and WhatsApp's online/last-seen presence share a shape: very frequent updates (every few seconds), where losing an update is fine because the next one supersedes it almost immediately. Both point to an in-memory, TTL-based store (Redis) rather than a durable relational write path. Persisting every location ping to a transactional DB would be enormous write amplification for data that's stale within seconds anyway.
- **Takeaway to reuse:** separate "needs to be correct forever" (a completed ride, a sent message) from "just needs to be roughly current" (driver location, online status). They belong in different storage tiers with very different durability guarantees.

**6. Fairness under extreme demand needs an explicit admission/queueing layer, not just rate limiting.**
- Ticketmaster's waiting room is the clearest example: converting "500,000 requests racing for 5,000 rows" into a controlled admission rate matched to real downstream throughput, keeping contention off the hot path entirely.
- **Takeaway to reuse:** rate limiting alone punishes/rejects excess traffic; a waiting room/queue sequences it fairly instead of rejecting it. Know the difference and when a system needs the latter (extreme, short-lived demand spikes on scarce inventory).

## Self-check: quiz yourself before moving on

1. Why is a full table scan with a lat/long range filter insufficient for Uber-style nearest-driver matching, and what data structure replaces it?
2. What's the actual difference between what OT and CRDTs solve, versus what a WebSocket transport layer solves, in a Google Docs–style system?
3. Why can't WhatsApp's server do full-text search across message content, given its stated design goal of end-to-end encryption?
4. Give the concrete mechanism (not just "use a transaction") that prevents two riders from being assigned the same driver, or two guests from double-booking the same Airbnb dates.
5. Why do driver locations and WhatsApp presence status belong in an in-memory TTL store rather than the durable relational database that holds completed rides/messages?
6. What does a waiting room accomplish that a plain rate limiter does not?

## Where the six systems differed (don't over-generalize)

- Google Docs is the only system this week (and across both weeks so far) where the core hard problem is a merge/reconciliation algorithm (OT/CRDT) rather than a storage or delivery problem.
- WhatsApp is the only system where a stated non-functional requirement (end-to-end encryption) actively removes a capability the server would otherwise have (content-based search/indexing). A useful reminder that non-functional requirements sometimes constrain rather than just describe scale.
- Ticketmaster is the only system this week where the majority of incoming requests are expected and designed to fail fast (100:1 contention). Most systems are designed to serve as many requests successfully as possible; this one is designed to fairly reject most of them.

This week's unifying thread, in one sentence: contention and coordination (spatial matching, concurrent editing, booking races, message ordering) rather than last week's read-heavy/caching theme. When a new prompt lands, that's the first thing worth deciding: which theme is this actually testing, before you reach for a toolkit built for the other one.

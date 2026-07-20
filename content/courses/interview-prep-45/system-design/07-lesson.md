---
kind: lesson
id_key: interview-prep-45/day-07-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 7 — Weekly Review"
position: 7
estimated_minutes: 36
source:
    - 45-day-interview-roadmap.md
---

## Why this review matters

You've now designed six systems in six days. The point of a review day isn't to redraw every diagram — it's to compress the week into a small set of transferable patterns you can recall under interview pressure, and to test yourself without the answer key open. Pattern recognition is what actually gets you through a 45-minute live interview; memorized diagrams don't transfer to a system you haven't seen before.

## The framework you should now run on autopilot

Every design this week followed the same shape. If this isn't automatic yet, drill it before moving on:

1. **Clarify scope** — functional requirements (what it does) and non-functional requirements (availability, latency, consistency trade-offs).
2. **Estimate scale** — back-of-envelope math for requests/sec, storage, and read:write ratio. This number should drive your architecture choices, not be a throwaway line.
3. **Define the API** — the contract between client and system; forces you to nail down what data flows where.
4. **Design the data model** — schema, indexes, and which field is the natural sharding/partition key.
5. **Draw the high-level architecture** — boxes and arrows, then narrate the request path through them.
6. **Deep-dive 2-3 components** — whatever the interviewer steers toward; this is where most of the signal comes from.
7. **Discuss trade-offs and scaling** — what breaks first, and how you'd fix it.

## Recap: what each design taught you

| Day | System | Core lesson |
|---|---|---|
| 1 | URL Shortener | Read-heavy systems should optimize the read path first; base-62 encoding of a unique ID beats random-string-plus-collision-check. |
| 2 | Rate Limiter | Token bucket allows healthy bursts while capping sustained abuse; atomicity (Lua/`INCR`) prevents race conditions under concurrency. |
| 3 | Notification Service | Decouple "accept the trigger" from "deliver the message" via a queue; exponential backoff + DLQ is the standard retry pattern. |
| 4 | Chat Application | Stateful WebSocket gateways need a shared connection registry for routing; ordering is enforced per-conversation via partitioned queues. |
| 5 | Analytics Pipeline | Lambda architecture: fast-approximate stream path + slow-exact batch path; event time vs processing time solves late-arriving data. |
| 6 | Multi-tenant SaaS | Isolation is a spectrum (shared schema -> separate schema -> dedicated DB); enforce it at the DB layer (RLS), not just in app code. |

## Cross-cutting patterns to internalize

- **Cache-aside** appears everywhere reads outnumber writes (URL shortener, feed, autocomplete later this course) — check cache, fall back to DB, populate cache on miss.
- **Message queues decouple producers from consumers** — notifications, chat, analytics all use this to absorb bursts and isolate failures. Whenever a request needs a slow downstream call (email provider, video encoder, ML model), your instinct should be "does this need to happen synchronously in the request path, or can it be queued?"
- **Partition by the entity that needs ordering** — conversation_id for chat, user_id for rate limits — this is the general answer to "how do you keep order in a distributed system": co-locate the events that must stay ordered on the same partition/shard.
- **Consistency vs availability is a per-feature decision, not a global one** — a redirect favors availability (day 1), a payment would favor consistency; state which side you're choosing and why, every time.
- **Push isolation down to the lowest layer that can enforce it** — Row-Level Security for tenant isolation, atomic Redis operations for rate limits — don't rely on application code discipline for anything security- or correctness-critical.

## Self-test — answer these without looking back

1. Why is a Key Generation Service better than checking for collisions on every write in a URL shortener?
2. Walk through what happens, end to end, when the Redis counter store for a rate limiter goes down mid-traffic-spike. What's your failure mode and why?
3. A notification's status is `sent` but not `delivered` after 10 minutes — what are the possible causes, and how does your architecture help you distinguish them?
4. In the chat design, why does partitioning the message broker by `conversation_id` (not `user_id`) matter for group chats?
5. Explain the difference between event time and processing time, and why a real-time analytics dashboard is allowed to be "wrong" temporarily.
6. Name the three multi-tenancy models and the concrete trade-off (cost vs isolation) between each.

If any of these take you more than 30 seconds to answer, go back and re-read that day's lesson before moving to week 2.

## Key takeaways
- The 7-step framework (scope, estimate, API, data model, architecture, deep-dive, trade-offs) should now be muscle memory, not a checklist you consult.
- Every system this week reused the same handful of primitives: cache-aside, message queues, partition-for-ordering, and pushing isolation/correctness down to the infrastructure layer.
- Back-of-envelope capacity estimates aren't decoration — they're what justifies "why Redis," "why Kafka," "why sharding," in your answer.
- Stating your consistency-vs-availability choice explicitly, per feature, is a strong signal interviewers look for.
- Use the self-test above as a real gate — don't move to week 2's systems until you can answer all six from memory.

## Today's checklist
- [ ] URL Shortener: Completed
- [ ] Rate Limiter: Completed
- [ ] Notification Service: Completed
- [ ] Chat Application: Completed
- [ ] Analytics Pipeline: Completed
- [ ] Multi-tenant SaaS: Completed

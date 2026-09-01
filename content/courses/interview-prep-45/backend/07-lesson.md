---
kind: lesson
id_key: interview-prep-45/day-07-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Checkpoint 1"
position: 7
estimated_minutes: 27
source:
    - 45-day-interview-roadmap.md
---
No new material today: this is a consolidation pass on Days 1-6. The goal isn't re-reading; it's proving to yourself, out loud or on a whiteboard, that you can reconstruct each topic without looking it up. If you stumble on any of the recall prompts below, that's the signal to go back to that day's lesson before moving on to Week 2.

## Self-check: Django request lifecycle

Without looking back, answer these out loud:

- Draw the middleware chain for `MIDDLEWARE = [A, B, C]` wrapping a view: which order do request-phase vs response-phase code run in, and why?
- Where does CSRF validation happen relative to your view code on a POST request?
- What does `functools.wraps` fix, and what breaks without it?

## Self-check: Django ORM internals

- Why does `if my_queryset:` still hit the database?
- Explain the N+1 problem in one sentence, then explain why `select_related` fixes it for a `ForeignKey` but `prefetch_related` is required for a reverse `ForeignKey` or `ManyToMany`.
- What's the fastest way to prove, in a test, that a code change didn't reintroduce N+1?

## Self-check: FastAPI async

- What specifically breaks if you call a blocking synchronous function inside an `async def` route?
- Walk through what `asyncio.gather` buys you over awaiting three calls sequentially, with real numbers (e.g. three 200ms calls).
- Why is `BackgroundTasks` not a substitute for a durable task queue?

## Self-check: PostgreSQL indexing

- Define index selectivity and explain why a boolean column is usually a bad index candidate on its own.
- In a composite index `(a, b)`, which queries can use it and which can't? Why?
- In `EXPLAIN ANALYZE` output, what does a large gap between estimated and actual row counts tell you, and what's the fix?

## Self-check: PostgreSQL query optimization

- Explain the difference between `WHERE` and `HAVING` with an example that would fail if you swapped them.
- Name the three join algorithms Postgres can choose and give one condition that favors each.
- What is the real bottleneck in an N+1 pattern: query execution time or something else?

## Self-check: Redis caching

- Explain cache-aside end to end: what happens on read, what happens on write, and why delete-on-write beats update-on-write.
- What is a cache stampede and name one mitigation.
- Why is a single-instance Redis lock not a correctness guarantee across a failover? What's the alternative when correctness actually matters?

## Revision tasks

Go through your notes from each day and, for anything you couldn't answer above cold, do a focused 10-minute re-read of just that section, not the whole lesson. Then pick your two weakest topics from the six days and spend the remaining time re-implementing one piece of code from each from memory (the middleware, the N+1 fix, the rate limiter, whichever you're shakiest on) without looking at your original solution.

## Key takeaways

- If you can't reconstruct an answer without notes, it's not interview-ready yet. That's what this review is for.
- N+1 and cache invalidation are the two bugs that show up disguised as different questions across every backend interview. Make sure both are automatic.
- The recurring theme across this week: understand what happens *under* the abstraction (middleware chain, QuerySet laziness, event loop, B-tree, query planner, cache invalidation). That's what separates "I've used this" from "I understand this."

---
kind: lesson
id_key: interview-prep-45/day-14-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Checkpoint 2"
position: 14
estimated_minutes: 27
source:
    - 45-day-interview-roadmap.md
---
Week 2 review, Days 8 through 13. Same format as Day 7: work through each recall prompt without notes first, and only go back to the original lesson for anything you can't reconstruct cleanly. This is also the halfway checkpoint for the whole 45-day roadmap, so the "review all 12 system designs" task below is bigger than a normal weekly pass.

## Self-check: Celery and task queues

- Explain Celery's delivery guarantee (at-least-once, not exactly-once) and what that implies about how you must write every task.
- Walk through the idempotency-key pattern: where does the dedup check happen, and why before the side effect rather than after?
- What does `task_acks_late=True` change about worker-crash behavior, and what does it require of your task code as a trade-off?

## Self-check: REST API design

- What does Richardson Maturity Level 2 actually require, and why is Level 3 (HATEOAS) rarely fully implemented?
- Explain idempotency for PUT vs POST with a concrete example of why it matters for retry safety.
- Why does cursor pagination scale better than offset pagination on a large, actively-written table?

## Self-check: API versioning and error handling

- Give three examples of a breaking API change and three examples of a safe additive change.
- Why should a version boundary live at the serialization layer rather than being duplicated through business logic?
- What's wrong with letting an unhandled exception's stack trace reach the client, and what should happen instead?

## Self-check: FastAPI background tasks

- Name two concrete things that break if you use `BackgroundTasks` for a task that absolutely must complete.
- What problem does moving job state from an in-memory dict to Redis actually solve, and what problem does it not solve on its own?
- What does Celery's `self.update_state(state="PROGRESS", ...)` give you that a hand-rolled Redis progress key doesn't?

## Self-check: AWS S3 and storage

- Walk through the full presigned-URL upload flow: what does your server do, what does the client do, and what does S3 enforce?
- What changed about S3's consistency model in December 2020, and what's the general concept it illustrates?
- Categorize `SlowDown` vs `AccessDenied` as S3 errors: which do you retry, and why?

## Self-check: Docker and containerization

- Why does instruction order in a Dockerfile affect build speed, concretely?
- Explain what a multi-stage build actually removes from the final image, using the `psycopg2`/`build-essential` example.
- What's the practical difference between `depends_on` alone and `depends_on: condition: service_healthy`?

## Revision tasks: halfway checkpoint

You're at the midpoint of the 45-day roadmap. Beyond the per-day recall above:

- Review all 12 system designs you've worked through so far across both weeks (backend deep dives plus whatever system-design track ran in parallel). For each, be able to state in under two minutes: the core trade-off, the bottleneck, and how you'd scale it 10x.
- Pick your **weakest 3** designs from that set and do a full re-practice: redraw the design, restate the trade-offs, and identify the one follow-up question you'd be least prepared for.
- Cross-reference this week against last week: Celery's idempotency (Day 8) and REST's idempotent-methods (Day 9) are the same underlying concept from two directions. Make sure you can articulate that connection, since interviewers sometimes ask it explicitly to check for depth versus memorization.

## Key takeaways

- Idempotency is the throughline of this entire week: it shows up in Celery tasks, HTTP methods, and S3 presigned uploads. If you only solidify one concept this review, make it that one.
- The recurring "durability vs speed" trade-off (BackgroundTasks vs Celery, in-memory vs Redis job state, offset vs cursor pagination) is a pattern-matching skill worth practicing explicitly, not just memorizing per-topic.
- At the halfway point, system-design fluency matters as much as topic recall. Being able to redraw and re-justify a design from memory is the real bar, not recognizing it when shown.

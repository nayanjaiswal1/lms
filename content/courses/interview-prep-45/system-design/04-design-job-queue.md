---
kind: lesson
type: system_design
id_key: interview-prep-45/day-08-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Job Queue System"
position: 4
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

A job queue is the system behind "process this in the background": Sidekiq, Celery, SQS, and every button in a real product that says "we'll email you when it's ready." A producer enqueues a job, a worker picks it up later and runs it. This question tests whether you understand delivery guarantees, retry logic, and what happens to ordering once you have more than one worker.

## Requirements

**Functional requirements**
- Producers enqueue jobs with a payload, like "resize image X" or "send email Y."
- Workers pull jobs, run them, and report success or failure.
- Failed jobs retry with backoff, up to a maximum number of attempts.
- Jobs can be scheduled to run in the future.
- Jobs support priorities: high, default, low.
- Jobs that fail permanently land in a dead letter queue for a human to inspect.

**Non-functional requirements**
- At-least-once delivery: never silently drop a job.
- Thousands of workers can pull from the same queues at once.
- Enqueueing must be fast; a producer should never block waiting on a job to run.
- Someone can see queue depth, failure rate, and inspect a stuck job.
- Job handlers must be idempotent, since at-least-once delivery means a job can run twice.

> **Remember:** "at-least-once" is a promise about delivery, not about your handler's side effects. Making the handler safe to run twice is your job, not the queue's.

```knowledge-check
{ "questions": [
    { "id": "system-design-jobqueue-requirements-q1", "type": "mcq", "prompt": "Why must job handlers be written to be idempotent (safe to run more than once)?", "options": [
        {"id": "a", "text": "Because idempotent code is always faster"},
        {"id": "b", "text": "Because at-least-once delivery means a worker crash or retry can cause the same job to run twice"},
        {"id": "c", "text": "Because the queue itself guarantees exactly-once execution"},
        {"id": "d", "text": "Idempotency is only needed for payment systems"}
    ], "correct": "b", "explanation": "A distributed queue with independent producers and consumers can't guarantee exactly-once delivery. The realistic guarantee is at-least-once, so the handler has to tolerate duplicates itself." }
] }
```

## Estimates

Assume a mid-size product with 50 million jobs a day.
- **Average rate:** 50,000,000 / 86,400 ≈ 580 jobs/sec.
- **Peak (3x during business hours):** roughly 1,750 jobs/sec.
- **Storage:** at 1 KB per job and a 7-day retention window for debugging, that's about 350 GB, comfortable for a single Postgres instance or a Kafka topic with retention.
- **Worker fleet:** if a job takes 200ms on average, one worker handles 5 jobs/sec. Sustaining 1,750 jobs/sec needs about 350 concurrent workers; provision 500+ for headroom.

Say this arithmetic out loud in an interview. It's what justifies picking a DB-backed queue over Kafka, or the other way around, later.

## API

```
POST /jobs
  body: { queue: "emails", payload: {...}, priority: "default", scheduled_at?: ISO8601, max_attempts?: 5 }
  -> { job_id, status: "queued" }

GET /jobs/{job_id}
  -> { job_id, status, attempts, last_error, created_at, updated_at }

POST /jobs/{job_id}/cancel   (only if still queued, not yet leased)

GET /queues/{queue}/stats
  -> { depth, in_flight, failed_last_hour, dlq_count }

POST /dlq/{job_id}/requeue
```

Workers never call this HTTP API to fetch jobs. They speak the broker's native pull protocol directly: Redis `BLPOP`, SQS `ReceiveMessage`, or a database `SELECT ... FOR UPDATE SKIP LOCKED`. The HTTP surface above exists for producers and for humans operating the system.

## Data model

```
jobs
  id              UUID PK
  queue           TEXT           -- "emails", "thumbnails", "webhooks"
  payload         JSONB
  status          TEXT           -- queued | in_progress | succeeded | failed | dead
  priority        SMALLINT       -- 0 = high ... 2 = low
  attempts        INT DEFAULT 0
  max_attempts    INT DEFAULT 5
  scheduled_at    TIMESTAMPTZ    -- when it becomes eligible to run
  locked_by       TEXT NULL      -- worker id, set on lease
  locked_at       TIMESTAMPTZ NULL
  last_error      TEXT NULL
  created_at      TIMESTAMPTZ
  updated_at      TIMESTAMPTZ

INDEX (queue, status, priority, scheduled_at)   -- the "give me the next job" query
```

If you use a broker like Redis, SQS, or Kafka instead of a DB-backed queue, this table becomes the job's status and audit record in Postgres, while the broker holds the lightweight queue of message pointers. Many real systems, including Sidekiq and SQS-backed setups, run this exact hybrid: a fast broker for delivery, a durable database for state.

## High-level design

```
Producer --> [API / enqueue call] --> Broker (Redis/SQS/Kafka) --+--> Job metadata store (Postgres)
                                                                   |
Worker pool <--- pull/lease -----------------------------------+
   |
   +--> execute handler --> success: ack, mark succeeded
                          --> failure: nack, increment attempts, requeue with backoff or move to DLQ

Scheduler (cron-like) --> polls "scheduled_at <= now() AND status = queued" --> pushes into broker
```

Three moving pieces do three different jobs: the **broker** delivers, the **metadata store** tracks state and audit history, and **workers** execute. Some systems collapse the broker and metadata store into one database-backed queue, simpler to run but with a lower throughput ceiling. Others split them, Kafka for delivery and Postgres for state, trading two systems to keep in sync for a much higher ceiling.

## Deep dives

### Why is leasing better than locking a row forever?

A worker doesn't hold a database lock for the entire time it processes a job. That would block visibility into the job and make crash recovery painful. Instead it uses a **visibility timeout**: `UPDATE jobs SET status='in_progress', locked_by=$1, locked_at=now() WHERE id=$2 AND status='queued'`. If the worker crashes mid-job, a reaper process periodically finds jobs whose `locked_at` is older than the visibility timeout and requeues them. SQS calls this a visibility timeout; Sidekiq calls it a watchdog. Same idea, different name.

> **Remember:** a job stuck at "in_progress" past its visibility window isn't stuck, it's waiting for the reaper to notice and hand it to someone else.

```knowledge-check
{ "questions": [
    { "id": "system-design-jobqueue-leasing-q1", "type": "mcq", "prompt": "What happens to a job when the worker processing it crashes mid-execution?", "options": [
        {"id": "a", "text": "The job is lost permanently"},
        {"id": "b", "text": "A reaper process notices the lease has expired (locked_at is past the visibility timeout) and requeues the job for another worker"},
        {"id": "c", "text": "The database automatically retries it within milliseconds"},
        {"id": "d", "text": "The job stays in_progress forever with no way to recover it"}
    ], "correct": "b", "explanation": "Because the worker never held a permanent lock, a background reaper can detect the stale lease and safely hand the job to a different worker, which is exactly why handlers must be idempotent." }
] }
```

### How does retry and the dead letter queue work?

Retry with exponential backoff plus jitter: `delay = base * 2^attempts + random_jitter`, capped at something reasonable like 15 minutes. Jitter matters because without it, every failed job retries at the exact same instant and can re-trigger the very outage it's recovering from.

After `max_attempts`, move the job to `status = 'dead'` and stop retrying automatically. A human or automated process inspects dead jobs, fixes the root cause, and requeues them through `POST /dlq/{id}/requeue`. Never retry forever: a permanently broken payload retried endlessly wastes capacity and can hide a real outage inside your dashboards.

### How do priorities and ordering actually work?

The cheapest way to implement priority is separate queues per level (`queue:high`, `queue:default`, `queue:low`), with workers polling high before default before low, using weighted round-robin so low-priority jobs don't starve completely. A single queue with a priority sort column gets expensive to sort on every dequeue under real load.

Full global ordering across a sharded, multi-worker queue is expensive and rarely needed. If one specific ordering guarantee matters (say, "events for the same user must process in order"), use a partition key: Kafka partitions, or pinning a key to one worker, so everything for that key lands on the same worker in order while different keys still run in parallel.

## Trade-offs and follow-up questions

| Choice | Pro | Con |
|---|---|---|
| DB-backed queue (Postgres `SKIP LOCKED`) | Simple to run, transactional with business data, easy DLQ | Throughput ceiling in the low thousands/sec; polling adds latency |
| Redis-backed (Sidekiq-style) | Very high throughput, low latency, simple primitives | Durability depends on persistence config; not a great long-term audit log |
| Managed broker (SQS) | No ops burden, built-in visibility timeout and DLQ | Vendor lock-in, per-message cost at scale, at-least-once only |
| Kafka | Massive throughput, replay, ordering per partition | Heavier to run, overkill for a simple task queue |

Pick based on scale: under roughly 1,000 jobs/sec, a DB-backed queue or Redis is the pragmatic choice. Above that, or if you need to replay events at the stream level, reach for Kafka.

**Q: How do you guarantee exactly-once processing when the network can duplicate delivery?**
A: You don't guarantee it at the delivery layer, you guarantee it at the application layer with an idempotency key. The handler checks a dedup row (`INSERT ... ON CONFLICT DO NOTHING`, keyed on a deterministic key derived from the job) before doing the actual work. Delivery stays at-least-once; the effect becomes exactly-once.

**Q: A worker crashes mid-job. What happens to that job?**
A: It stays `in_progress` with a `locked_at` timestamp. A reaper scans for jobs whose lease has expired and requeues them, incrementing attempts and resetting status. This is exactly why handlers must be idempotent, since the job may partially run twice.

**Q: How do you stop one noisy queue from starving the others?**
A: Separate queues per tenant or job type, with weighted round-robin polling or dedicated worker pools per queue, plus rate-limiting on the producer side if one source is flooding the system.

```knowledge-check
{ "questions": [
    { "id": "system-design-jobqueue-tradeoffs-q1", "type": "mcq", "prompt": "Above roughly what throughput does the interview-favored answer shift from a DB-backed or Redis queue toward Kafka?", "options": [
        {"id": "a", "text": "10 jobs/sec"},
        {"id": "b", "text": "Around 1,000 jobs/sec, or when you need to replay the stream"},
        {"id": "c", "text": "There is no such threshold, always use Kafka"},
        {"id": "d", "text": "1 million jobs/sec exactly"}
    ], "correct": "b", "explanation": "Below that range a simpler DB-backed or Redis queue is the pragmatic choice; Kafka earns its extra operational cost once throughput or replay needs grow past it." }
] }
```

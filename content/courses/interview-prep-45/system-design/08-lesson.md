---
kind: lesson
type: system_design
id_key: interview-prep-45/day-08-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 8 — Job Queue System"
position: 8
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today you design a distributed job queue — the system behind Sidekiq, Celery, SQS, and every "process this asynchronously" button in a real product. Interviewers ask this because it tests whether you understand delivery guarantees (at-least-once vs exactly-once), retry logic, and how ordering breaks down once you have more than one worker. It's a deceptively deep topic disguised as a simple CRUD-looking system.

## Requirements

**Functional**
- Producers enqueue jobs with a payload (e.g., "resize image X", "send email Y").
- Workers pull jobs, execute them, and report success/failure.
- Failed jobs retry with backoff, up to a max attempt count.
- Jobs can be scheduled for future execution (`scheduled_at`).
- Jobs support priorities (e.g., `high`, `default`, `low`).
- Permanently failed jobs land in a dead letter queue (DLQ) for inspection.

**Non-functional**
- At-least-once delivery (never silently drop a job).
- Horizontal scalability of workers — thousands of workers pulling from the same queues.
- Low enqueue latency (producers shouldn't block).
- Visibility: someone can see queue depth, failure rate, and inspect a stuck job.
- Idempotent job handlers (a design requirement we push onto the API, since at-least-once implies duplicates).

## Capacity estimates

Assume a mid-size product: 50M jobs/day.
- Average rate: 50,000,000 / 86,400 ≈ 580 jobs/sec.
- Peak (3x average during business hours): ~1,750 jobs/sec.
- Average payload: 1 KB → 50M × 1 KB = 50 GB/day of job data if retained for replay/audit.
- If jobs are retained 7 days for debugging: 350 GB — fits comfortably in a single Postgres instance or a Kafka topic with retention.
- Worker fleet: if a job takes 200ms average, one worker handles 5 jobs/sec. To sustain 1,750 jobs/sec you need ~350 concurrent workers (with headroom, provision 500+).

These numbers exist to justify architecture choices below — don't skip the arithmetic in the interview, say it out loud.

## API sketch

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

Workers don't call an HTTP API to fetch jobs — they use the broker's native pull/poll protocol (Redis `BLPOP`, SQS `ReceiveMessage`, or a DB `SELECT ... FOR UPDATE SKIP LOCKED`). The HTTP surface above is for producers and operators only.

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

If you use a broker like Redis/SQS/Kafka instead of a DB-backed queue, the "table" above becomes the job's metadata record in Postgres for status tracking and the DLQ, while the broker itself holds the ephemeral queue of message pointers. Many real systems (Sidekiq, SQS) do exactly this hybrid: lightweight broker for delivery, DB for durable job state.

## High-level architecture

```
Producer --> [API / enqueue call] --> Broker (Redis/SQS/Kafka) --+--> Job metadata store (Postgres)
                                                                   |
Worker pool <--- pull/lease -----------------------------------+
   |
   +--> execute handler --> success: ack, mark succeeded
                          --> failure: nack, increment attempts, requeue with backoff or move to DLQ

Scheduler (cron-like) --> polls "scheduled_at <= now() AND status = queued" --> pushes into broker
```

Three moving pieces: the **broker** (delivery), the **metadata store** (state/audit/DLQ), and **workers** (execution). Some systems collapse broker + metadata into one DB-backed queue (simpler ops, lower throughput ceiling); others split them (Kafka for delivery, Postgres for state) for higher throughput at the cost of two systems to keep consistent.

## Component deep dives

**Delivery guarantee — at-least-once, not exactly-once.** True exactly-once delivery is not achievable in a distributed system with independent producer/consumer failures — you always get at-least-once (with dedup) or at-most-once (with loss). The practical answer: make handlers idempotent. Store a `dedup_key` (e.g., `send_email:user_id:template_id:day`) and have the handler check/insert it atomically before doing work. This turns "at-least-once delivery" into "effectively exactly-once side effects."

**Leasing, not locking forever.** A worker doesn't hold a row lock while it processes a job (that would block visibility and crash-recovery). Instead it does a visibility timeout: `UPDATE jobs SET status='in_progress', locked_by=$1, locked_at=now() WHERE id=$2 AND status='queued'`. If the worker crashes mid-job, a reaper process periodically finds jobs where `locked_at < now() - visibility_timeout` and requeues them. SQS calls this the "visibility timeout"; Sidekiq calls it a "watchdog."

**Retry with exponential backoff + jitter.** `delay = base * 2^attempts + random_jitter`, capped at some max (e.g., 15 min). Jitter prevents thundering-herd retries when a downstream dependency (say, an email provider) comes back up after an outage — without jitter, every failed job retries at the exact same instant and re-triggers the outage.

**Dead letter queue.** After `max_attempts` is exceeded, move the job to `status = 'dead'` and stop retrying automatically. A human or automated process inspects DLQ jobs, fixes the root cause (bad payload, downstream bug), and requeues via `POST /dlq/{id}/requeue`. Never retry forever — infinite retries on a permanently broken job (e.g., malformed payload) waste capacity and can mask real outages in dashboards.

**Priorities.** Cheapest implementation: separate queues per priority (`queue:high`, `queue:default`, `queue:low`) and have workers poll high before default before low (weighted round-robin to avoid low-priority starvation). Avoid a single queue with a "priority" sort column under high contention — sorting on every dequeue under load is slower than just having separate queues.

**Ordering.** Full global ordering across a sharded/multi-worker queue is expensive and rarely needed. If a specific ordering guarantee is required (e.g., "events for the same user must process in order"), use a partition key (Kafka partitions, or a per-key single-worker assignment) so all jobs for that key land on the same worker/partition and process sequentially, while different keys parallelize freely.

## Scaling & trade-offs

| Choice | Pro | Con |
|---|---|---|
| DB-backed queue (Postgres `SKIP LOCKED`) | Simple ops, transactional with business data, easy DLQ | Throughput ceiling in the low thousands/sec; polling adds latency |
| Redis-backed (Sidekiq-style) | Very high throughput, low latency, simple pub/sub primitives | In-memory — durability depends on persistence config (AOF/RDB); not a great long-term audit log |
| Managed broker (SQS) | No ops burden, built-in visibility timeout, DLQ | Vendor lock-in, per-message cost at scale, at-least-once only |
| Kafka | Massive throughput, replay, ordering per partition | Heavier operationally, overkill for a simple task queue, consumer offset management adds complexity |

Pick based on scale: under ~1K jobs/sec, DB-backed or Redis is the pragmatic answer. Above that, or if you need replay/audit at the event-stream level, reach for Kafka.

## Likely follow-up questions — with answers

**Q: How do you guarantee exactly-once processing if the network can duplicate delivery?**
A: You don't guarantee it at the delivery layer — you guarantee it at the application layer via idempotency keys. The handler checks a dedup table/row (`INSERT ... ON CONFLICT DO NOTHING` keyed on a deterministic idempotency key derived from the job) before executing the side effect. Delivery stays at-least-once; the *effect* becomes exactly-once.

**Q: A worker crashes mid-job. What happens to that job?**
A: It stays `in_progress` with a `locked_at` timestamp. A reaper (cron or background loop) scans for jobs whose `locked_at` is older than the visibility timeout and requeues them (increment attempts, reset status to `queued`). This is why handlers must be idempotent — the job may partially execute twice.

**Q: How do you prevent one noisy queue from starving others?**
A: Separate queues per tenant/type with weighted round-robin worker polling, or dedicated worker pools per queue (isolate by autoscaling group). Rate-limit enqueue on the producer side if one tenant is flooding the system.

## Key takeaways

- Real-world queues give at-least-once delivery; exactly-once *effects* come from idempotent handlers plus a dedup key, not from the broker.
- Leasing with a visibility timeout (not a permanent lock) is how you recover from crashed workers without losing jobs.
- Exponential backoff with jitter on retries prevents retry storms from re-triggering the outage that caused the failures.
- A dead letter queue with a max-attempts cap is mandatory — infinite retries hide bugs and burn capacity.
- Priority queues are best implemented as separate physical queues with weighted polling, not a sort column.
- Choose the broker by throughput need: Postgres/Redis for most products, Kafka only when you need per-key ordering or replay at scale.

## Today's checklist

- [ ] Write functional requirements: enqueue, worker processing, retries.
- [ ] Write non-functional requirements: delivery guarantee, ordering, priorities.
- [ ] Design the job schema (id, payload, status, attempts, scheduled_at).
- [ ] Sketch the worker leasing/visibility-timeout mechanism.
- [ ] Design the dead letter queue and requeue flow.
- [ ] Talk through scaling the broker choice under load.

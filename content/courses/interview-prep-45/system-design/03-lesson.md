---
kind: lesson
type: system_design
id_key: interview-prep-45/day-03-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Notification Service"
position: 3
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

## Why interviewers ask this

A notification service is a canonical asynchronous, multi-provider fan-out system. It tests whether you reach for a message queue instead of synchronous calls, whether you understand at-least-once delivery and idempotency, and whether you can design retry/backoff logic that doesn't hammer a failing downstream provider. Almost every real backend eventually needs this, so expect it in mid-to-senior interviews.

## Requirements

### Functional
- Send notifications via multiple channels: email, SMS, push (mobile).
- Support templated messages (e.g. "Your order {{order_id}} has shipped").
- Track delivery status per notification (queued, sent, delivered, failed).
- Allow other internal services to trigger a notification via an API/event.
- Respect user preferences (opted out of SMS, quiet hours, etc.).

### Non-functional
- **Reliability.** A notification should not be silently lost.
- **Ordering.** For a given user/thread, notifications should generally arrive in the order they were triggered. Not always strictly required, but often expected, e.g. "processing" before "shipped."
- **Retry logic.** Transient provider failures (SMTP timeout, SMS gateway 500) must be retried with backoff, not dropped.
- Scale to millions of notifications/day with provider-specific rate limits respected.

## Capacity estimates

Assume 10M notifications/day across all channels.

- **Average rate:** 10,000,000 / 86,400 ≈ **116/sec**; peak (e.g. a marketing blast) could be 10-50x, so 1,000-5,000/sec.
- **Storage:** a notification record is roughly 1 KB (recipient, channel, template, status, timestamps) × 10M/day × 365 days ≈ 3.65B rows/year, about 3.65 TB/year raw. Plan to archive or cold-store records older than a few months to a cheaper store (S3 plus occasional query via Athena) rather than keeping everything in the hot DB.
- **Provider rate limits:** an SMS gateway might allow 100 msgs/sec. This becomes the bottleneck, not your own infrastructure, so the queue must be able to buffer bursts and drain at the provider's allowed rate.

## API sketch

```
POST /api/v1/notifications
  body: {
    user_id, channel: "email" | "sms" | "push" | "auto",
    template_id, template_data: { order_id: "123" },
    idempotency_key
  }
  resp: { notification_id, status: "queued" }

GET /api/v1/notifications/{id}
  resp: { id, channel, status, created_at, sent_at, delivered_at, error? }

POST /api/v1/webhooks/provider-callback   (provider -> us, delivery receipts)
```

`idempotency_key` (e.g. `order-123-shipped`) lets calling services safely retry the trigger call without double-sending. The API upserts on that key instead of creating a duplicate row.

## Data model

```
notifications
  id                bigint PK
  user_id           bigint INDEX
  channel           enum(email, sms, push)
  template_id       varchar
  payload           jsonb
  idempotency_key   varchar UNIQUE
  status            enum(queued, sending, sent, delivered, failed)
  attempt_count     int DEFAULT 0
  created_at        timestamp
  sent_at           timestamp NULL
  delivered_at      timestamp NULL
  last_error        text NULL

user_preferences
  user_id           bigint PK
  email_opt_in      boolean
  sms_opt_in        boolean
  push_opt_in       boolean
  quiet_hours_start time NULL
  quiet_hours_end   time NULL

templates
  id                varchar PK
  channel           enum(email, sms, push)
  subject           text NULL
  body              text  -- with {{placeholder}} syntax
```

## High-level architecture

```
Internal services --> Notification API --> Notifications DB (status=queued)
                                                    |
                                                    v
                                         Message Queue (Kafka/SQS), partitioned by user_id
                                                    |
                        +---------------------------+---------------------------+
                        v                            v                           v
                Email Worker Pool           SMS Worker Pool             Push Worker Pool
                        |                            |                           |
                        v                            v                           v
                  SES / SendGrid              Twilio / SNS               FCM / APNs
                        |                            |                           |
                        +------------- Delivery webhooks --------------+
                                                    |
                                                    v
                                          Status Updater --> Notifications DB
```

The **Notification API** validates the request, checks user preferences, resolves the template, writes a `queued` row, and publishes an event to the queue. It never calls the provider synchronously, which decouples accepting the request from actually delivering it.

**Per-channel worker pools** consume from the queue, call the relevant provider's API, and update status. Separate pools per channel let you scale email workers independently from SMS workers and apply channel-specific rate limiting.

**Partitioning by `user_id`** in the queue preserves per-user ordering (all of one user's notifications land on the same partition and are processed in order) while still parallelizing across users.

## Component deep dives

### Message queue choice

Kafka or Kinesis if you need replay, multiple independent consumers, and high throughput with ordering guarantees per partition key. SQS (standard or FIFO) is simpler operationally if you don't need replay: SQS FIFO gives per-`MessageGroupId` ordering, which maps naturally to per-user ordering. For an interview, either is acceptable. Justify the pick based on whether you need replay/multiple consumer groups (Kafka) or just simple reliable delivery (SQS).

### Templates

Store templates with versioned placeholders (`{{order_id}}`), and render server-side at send time, not at trigger time, so the latest template/branding is always used even if a message sits in the queue for a while. Support per-locale template variants (`shipped_en`, `shipped_es`) keyed by the user's locale preference.

### Retry logic and dead-letter queue

On provider failure, retry with **exponential backoff plus jitter** (e.g. 1s, 2s, 4s, 8s, capped, plus random jitter to avoid thundering-herd retries all synchronized to the same instant). Cap retries (e.g. 5 attempts); after that, move to a **dead-letter queue (DLQ)** for manual inspection and alerting rather than retrying forever.

Distinguish **retryable** errors (timeout, 5xx, rate-limited) from **permanent** errors (invalid phone number, unsubscribed). Permanent errors should fail immediately without burning retry budget.

### Delivery failures

Track `attempt_count` and `last_error` on the notification row for observability. Provider delivery webhooks (SES bounce/complaint, Twilio delivery receipt) update status asynchronously after the initial "sent" state: "sent" (we handed it to the provider) means something different from "delivered" (the provider confirms the recipient's device or inbox got it).

Respect quiet hours and opt-outs before even enqueueing. It's cheaper than enqueueing and discarding.

## Scaling & trade-offs

**At-least-once delivery is the realistic guarantee.** Exactly-once across a network boundary to a third-party provider isn't achievable in practice. Use the `idempotency_key` so retries, ours or the caller's, don't create duplicate sends.

**Ordering vs throughput:** strict per-user ordering caps parallelism to one in-flight message per user, but that's fine, because per-user notification volume is naturally low and doesn't bottleneck overall throughput.

**Provider fan-out for reliability:** support a primary plus fallback provider per channel (e.g. SendGrid primary, SES fallback) and fail over automatically if the primary's error rate spikes, using a circuit breaker.

**Batching:** for bulk notifications (marketing blast to 1M users), fan the single trigger out into many queue messages asynchronously rather than blocking the API request. Return `202 Accepted` immediately.

## Likely follow-up questions — with answers

**Q: How do you guarantee a user doesn't get the same notification twice?**
A: Idempotency key at the API layer (dedupe on insert) plus idempotency at the worker layer: check the notification's current status before sending, and if it's already `sent`/`delivered`, skip. This makes retries (queue redelivery, our own retry logic) safe.

**Q: How do you prevent a slow/failing provider from backing up the whole queue?**
A: Separate queues/worker pools per channel and per provider so one channel's outage doesn't block others. Apply a circuit breaker per provider: after N consecutive failures, stop sending to it temporarily (fail fast to DLQ or fallback provider) instead of retrying into a known-down service.

**Q: How would you support "notify me only once per day max" type user preferences?**
A: Add a rate-limit/dedupe layer keyed by `(user_id, notification_type)` with a TTL matching the desired window (e.g. a Redis key with 24h TTL). Check it before enqueueing, and only enqueue if the key doesn't already exist.

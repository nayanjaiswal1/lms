---
kind: lesson
id_key: interview-prep-45/hld-10-messaging
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Messaging, Queues, and Event-Driven Architecture"
position: 10
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

The moment you draw a queue, you have made four decisions the interviewer will ask about: what happens if a consumer crashes mid-message, what happens if the same message is delivered twice, whether order is preserved, and what happens when producers outrun consumers. Have all four answers ready and this becomes one of the strongest parts of your design.

## Why a queue, and where the line goes

A queue does four distinct jobs, and naming which one you want is the difference between "I'd add Kafka" and a designed system:

| Job | What it buys | Example |
|---|---|---|
| **Decoupling** | Producer doesn't know or wait for consumers | Order service publishes `order.placed`; email, analytics, and inventory each consume it |
| **Buffering / load levelling** | Absorbs spikes so the slow side isn't overwhelmed | 50k signups in a flash sale drain into a worker pool at its own pace |
| **Async work** | Removes slow work from the request path | Video transcoding, PDF generation, bulk email |
| **Retry & durability** | A failed unit of work isn't lost | Payment webhook delivery with backoff |

**The line to draw in every design:** anything the user's response does not depend on goes behind the queue. `POST /orders` must persist the order and return; sending the confirmation email, updating the recommendation model, indexing for search, and notifying the warehouse must not.

The costs, which you should volunteer:

- **Eventual consistency becomes user-visible.** "Your order is placed" but the email arrives 30 seconds later, and the analytics dashboard lags.
- **Debugging is harder** — a failure now surfaces in a worker log, not in the request trace, unless you propagate trace IDs.
- **Another system to operate**: brokers, partitions, lag monitoring, dead letters.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-why-q1", "type": "mcq",
      "prompt": "Which of these must stay in the synchronous request path of `POST /orders`, rather than moving behind a queue?",
      "options": [
        {"id":"a","text":"Sending the order confirmation email"},
        {"id":"b","text":"Reserving inventory and persisting the order, because the response tells the user whether their order succeeded"},
        {"id":"c","text":"Updating the recommendation model"},
        {"id":"d","text":"Indexing the order for internal search"}
      ],
      "correct": "b",
      "explanation": "Anything the user's answer depends on must complete before you respond. Everything the user learns about later — email, analytics, search indexing — belongs behind the queue." }
] }
```

## Queue vs log: the distinction that matters

There are two fundamentally different shapes, and choosing the wrong one is a common mistake.

**Message queue** (RabbitMQ, SQS, ActiveMQ): a message is delivered to one consumer, acknowledged, and **deleted**. The broker tracks per-message state.

**Distributed log** (Kafka, Kinesis, Redpanda, Pulsar): messages are appended to an ordered, partitioned, **retained** log. Consumers track their own offset and read at their own pace; the message is not deleted when read. Many independent consumer groups read the same stream.

| | Queue (RabbitMQ/SQS) | Log (Kafka) |
|---|---|---|
| After consumption | Deleted | Retained (time/size based) |
| Consumers per message | One (per queue) | Many independent groups |
| Replay history | No | **Yes** — reset the offset |
| Ordering | Per queue, lost with multiple consumers | **Per partition**, strictly |
| Routing | Rich (exchanges, topics, headers, priorities) | Simple: topic + partition |
| Per-message ack/retry | Native, per message | Per offset — one poison message blocks its partition |
| Throughput | High | **Very high** (sequential disk, batching) |
| Typical use | Task queues, RPC-ish work, priority routing | Event streams, CDC, analytics, event sourcing |

The decision rule: **do you need to replay history, or feed several independent consumers the same events? Use a log. Do you need per-message routing, priorities, and delayed retries? Use a queue.**

Kafka's partitions are the unit of both parallelism and ordering: messages with the same key go to the same partition and are strictly ordered there, and one partition is consumed by at most one consumer in a group. So **partition count is your maximum consumer parallelism**, and the partition key is what preserves per-entity order — key by `user_id` and that user's events stay ordered even though the topic as a whole is not.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-queuelog-q1", "type": "mcq",
      "prompt": "You need order events consumed independently by billing, analytics, and search, and you want to rebuild the search index next month by re-reading everything. What fits?",
      "options": [
        {"id":"a","text":"A message queue, with three consumers reading the same queue"},
        {"id":"b","text":"A distributed log (Kafka): each system is its own consumer group with its own offset, and retention lets you reset an offset to rebuild"},
        {"id":"c","text":"Direct synchronous HTTP calls to all three services"},
        {"id":"d","text":"A shared database table polled by all three"}
      ],
      "correct": "b",
      "explanation": "Three consumers on one queue split the messages rather than each seeing all of them, and a queue deletes on ack so there is nothing to replay. Retention plus per-group offsets is exactly the log's contribution." }
] }
```

## Delivery semantics and idempotent consumers

Three possible guarantees; only two of them are real.

| Semantics | Mechanism | Failure mode |
|---|---|---|
| **At-most-once** | Ack before processing | Message lost if the consumer crashes mid-work |
| **At-least-once** | Ack after processing | **Duplicates** when the ack is lost after the work is done |
| **Exactly-once** | Not achievable end-to-end across systems | — |

**At-least-once is the default and the right choice**, because losing work is usually worse than doing it twice. That makes duplicate handling a *design requirement*, not an accident.

"Exactly-once" as marketed by Kafka means exactly-once *within Kafka* — transactional writes across topics with an idempotent producer. The moment your consumer charges a card or sends an email, an external side effect exists that Kafka's transaction cannot roll back. The honest formulation, and the one interviewers want: **"at-least-once delivery plus idempotent processing = effectively-once."**

**How to make a consumer idempotent:**

```python
def handle(msg):
    # 1. Natural idempotency — the operation is safe to repeat as-is.
    #    "SET status = 'shipped'" is idempotent; "counter += 1" is not.

    # 2. Deduplication table — the general mechanism.
    #    The UNIQUE constraint is what makes it race-safe, not the SELECT.
    try:
        db.execute(
            "INSERT INTO processed_messages (message_id, processed_at) VALUES (%s, now())",
            msg.id,
        )
    except UniqueViolation:
        return  # already handled; ack and move on

    do_the_work(msg)

    # 3. Better still: do the work and record the message id in ONE transaction,
    #    so a crash between them cannot leave the dedupe row without the effect.
```

Two more patterns worth naming:

- **Conditional writes**: `UPDATE orders SET status='shipped' WHERE id=? AND status='paid'` applies once no matter how many times it runs.
- **Version/sequence checks**: ignore any event whose version is not exactly one greater than what you have stored.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-delivery-q1", "type": "mcq",
      "prompt": "Why can no message broker offer true end-to-end exactly-once delivery when the consumer sends an email?",
      "options": [
        {"id":"a","text":"Because email servers are unreliable"},
        {"id":"b","text":"Because the consumer can crash after the external side effect but before acknowledging, and no protocol can undo an email that has already left — so the achievable goal is at-least-once delivery plus idempotent processing"},
        {"id":"c","text":"Because brokers don't persist messages"},
        {"id":"d","text":"Because the network reorders packets"}
      ],
      "correct": "b",
      "explanation": "Exactly-once requires an atomic commit spanning the broker and the side effect. Kafka's transactions cover writes back into Kafka, not the outside world — hence \"effectively-once\" via idempotent consumers." }
] }
```

## Ordering, retries, dead letters, and backpressure

**Ordering.** Global order across a topic is expensive and almost never required; **per-entity** order usually is. Partition by the entity key (`user_id`, `account_id`, `conversation_id`) and you get strict order where it matters while still parallelising across entities. If you truly need global order, you have one partition and one consumer — say the cost out loud.

Ordering breaks quietly in three places: multiple consumers on one queue, retries that push a failed message behind newer ones, and re-partitioning (which changes which partition a key lands in).

**Retries.** Retry with **exponential backoff and jitter** — fixed-interval retries from many clients re-synchronise into a thundering herd:

```
delay = min(base * 2**attempt, max_delay) * random_between(0.5, 1.5)
```

Cap the attempts. Distinguish **retryable** failures (timeout, 503, deadlock) from **permanent** ones (validation error, 400) — retrying a malformed message forever is pure waste, and it blocks the partition behind it.

**Dead letter queue (DLQ).** After N failed attempts, move the message to a DLQ with its error and attempt count. Nothing is lost, the main flow is unblocked, and a human (or a fixed consumer) can replay it. **Alert on DLQ depth** — a silent DLQ is a data-loss incident nobody noticed.

**Backpressure.** When producers outrun consumers, queue depth grows unbounded, memory and disk fill, and latency climbs until the system fails. The available responses:

1. **Scale consumers** — autoscale on queue depth or consumer lag. (In Kafka, only up to the partition count.)
2. **Bound the queue** and reject or block producers when it is full — failing fast is better than failing slowly.
3. **Shed load**: drop low-priority messages, or sample.
4. **Rate limit at the producer.**

**Consumer lag is the metric.** For Kafka it is the offset gap; for SQS it is `ApproximateAgeOfOldestMessage`. Alert on lag *trend*, not just absolute value: steadily growing lag means consumers are permanently under-provisioned, and no amount of waiting will drain it.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-ops-q1", "type": "mcq",
      "prompt": "One malformed message fails permanently and is retried forever at the head of a Kafka partition. What is the correct fix?",
      "options": [
        {"id":"a","text":"Increase the retry count so it eventually succeeds"},
        {"id":"b","text":"After N attempts, move it to a dead-letter topic with its error context, commit the offset so the partition drains, and alert on DLQ depth"},
        {"id":"c","text":"Delete the partition"},
        {"id":"d","text":"Switch to at-most-once delivery"}
      ],
      "correct": "b",
      "explanation": "A poison message blocks its partition because offsets commit in order. The DLQ removes it from the hot path without losing it, and the alert makes sure someone actually looks at it." }
] }
```

## Event-driven patterns: pub/sub, outbox, event sourcing, CQRS

**Pub/sub vs point-to-point.** Point-to-point: one producer, one consumer, one queue — a task list. Pub/sub: one event, many independent subscribers — an announcement. Prefer publishing **facts** ("`order.placed`") over issuing **commands** ("`send_email`"): facts let you add a fourth consumer later without touching the producer, which is the whole point of decoupling.

**The dual-write problem, and the outbox pattern.** This is the highest-value pattern in the topic. Writing to the database and then publishing to the broker is **not atomic** — a crash in between leaves the order saved but never announced, or announced but never saved.

```
Wrong:   BEGIN; INSERT order; COMMIT;   kafka.publish(event)   ← crash here = lost event

Right:   BEGIN;
           INSERT INTO orders   (...);
           INSERT INTO outbox   (id, topic, payload, created_at);   -- same transaction
         COMMIT;
         -- a separate relay (CDC on the WAL, or a poller) reads outbox and publishes,
         -- marking rows sent. At-least-once by construction; consumers dedupe.
```

The inverse, the **inbox pattern**, dedupes on the consuming side by recording processed message ids in the same transaction as the effect.

**Event sourcing** stores the sequence of events as the source of truth, and derives current state by replaying them. You gain a complete audit log, time travel, and the ability to build new projections from history. You pay with schema evolution of old events, snapshotting so replay isn't unbounded, and the fact that "what is the current balance" becomes a computed question. Use it where the history *is* the product — ledgers, audit trails, collaborative documents — not by default.

**CQRS** separates the write model from one or more read models, connected by events. It is the natural partner to event sourcing and to any system whose read shape differs sharply from its write shape (a normalised write side, a denormalised feed on the read side). The cost is eventual consistency between the two and twice the models to maintain.

**Change data capture (CDC)** reads the database's own replication log (Debezium on the Postgres WAL or MySQL binlog) and publishes row changes as events. It gives you the outbox's atomicity without application changes, and it is the standard way to feed search indexes, caches, and warehouses from a source-of-truth database.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-outbox-q1", "type": "mcq",
      "prompt": "A service commits an order to Postgres and then publishes an `order.placed` event to Kafka. What can go wrong, and what is the standard fix?",
      "options": [
        {"id":"a","text":"Nothing — the two writes happen in sequence"},
        {"id":"b","text":"The dual-write problem: a crash between commit and publish loses the event permanently. Fix with the transactional outbox — insert the event into an outbox table in the same transaction, and have a relay (or CDC) publish from it"},
        {"id":"c","text":"Kafka may reorder the event; fix by adding a timestamp"},
        {"id":"d","text":"Postgres may roll back after Kafka accepts; fix with a longer transaction timeout"}
      ],
      "correct": "b",
      "explanation": "Two separate systems cannot be written atomically without a distributed transaction. The outbox turns the problem into a single local transaction plus an at-least-once relay, and consumers dedupe." }
] }
```

## Key takeaways

**The recall card:**

```
Queue jobs: decouple · buffer · async · retry.  Rule: response-independent work goes async.
Queue (RabbitMQ/SQS) = delete on ack, rich routing, per-message retry
Log   (Kafka)        = retained + replayable, many consumer groups, order PER PARTITION
                       partitions = max parallelism; partition key = ordering unit

Delivery: at-most-once (lossy) · at-least-once (DEFAULT, duplicates) · exactly-once (myth)
  → at-least-once + idempotent consumer = "effectively once"
  → idempotency via UNIQUE dedupe row, conditional UPDATE, or version check

Retries: exponential backoff + JITTER, capped, retryable vs permanent
DLQ after N failures + ALERT on depth (a poison message blocks its partition)
Backpressure: scale consumers → bound the queue → shed load → rate limit producers
Metric: consumer lag, and its TREND

Patterns: publish FACTS not commands · transactional OUTBOX (dual-write fix)
          inbox (consumer dedupe) · CDC (WAL → events) · event sourcing · CQRS
```

- **"I'd add a queue" is incomplete.** Finish it: queue or log, what the ordering key is, how the consumer is idempotent, what happens after N failures, and how you detect lag.
- **The outbox pattern is the single highest-value thing in this lesson.** Every design that writes to a database and publishes an event has the dual-write problem; almost no candidate names it.
- **Duplicates are guaranteed, so design for them** rather than trying to prevent them.
- **Publish facts, not commands** — it is what makes adding the fourth consumer free.

---
kind: lesson
id_key: interview-prep-45/day-18-backend
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Kafka and Message Queues"
position: 4
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Kafka questions separate candidates who've used a queue from candidates who've used *this* queue. Interviewers probe partitioning, consumer groups, and delivery guarantees because that's exactly where Kafka's design diverges from something like RabbitMQ or SQS. This lesson covers the architecture, a working producer and consumer, and the ordering and duplication questions that come up in nearly every backend system-design interview.

## Kafka's building blocks

Picture a topic as a set of parallel, append-only log files, called partitions. Producers write to the end of a partition; consumers read from wherever they last stopped, at their own pace. Nothing is ever removed on read.

- **Topic**: a named stream of records, split into **partitions**. Splitting into partitions is how Kafka parallelizes work: each partition is its own ordered log, and different partitions can be consumed independently.
- **Broker**: one Kafka server. A cluster is several brokers, each holding some partitions and replicas of others.
- **Producer**: writes records to a topic, choosing which partition each record lands in.
- **Consumer**: reads records from a partition, tracking its position with an **offset**, a per-partition sequence number.
- **Consumer group**: a set of consumers that split a topic's partitions between themselves. Each partition is read by exactly one consumer in the group at a time, which is how Kafka spreads out work without any duplication.

Kafka keeps records for a configured retention period, not just until someone reads them, so multiple independent consumer groups can each read the same topic at their own pace, including replaying from the very beginning.

> **Remember:** a topic-partition is a durable, ordered log. Producers append, consumers read at their own pace by offset, and nothing disappears just because it was read once.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-kafka-architecture-q1", "type": "mcq",
      "prompt": "Two different consumer groups both subscribe to the same Kafka topic. What happens?",
      "options": [
        {"id":"a","text":"Only one group can read the topic at a time"},
        {"id":"b","text":"Each group reads every record independently, at its own pace, since offsets are tracked per (group, partition), not globally"},
        {"id":"c","text":"The second group only receives records the first group has not yet read"},
        {"id":"d","text":"Kafka merges the two groups into one automatically"}
      ],
      "correct": "b",
      "explanation": "Kafka tracks each consumer group's progress separately. Two groups reading the same topic are entirely independent views, each able to replay or lag without affecting the other." }
] }
```

## A producer and consumer that actually commit correctly

```python
from kafka import KafkaProducer, KafkaConsumer

producer = KafkaProducer(
    bootstrap_servers=["localhost:9092"],
    acks="all",               # wait for every in-sync replica to acknowledge
    enable_idempotence=True,   # see duplication below
)

def publish_order_event(order_id: str, status: str):
    # keying by order_id guarantees every event for the same order lands
    # in the same partition, preserving per-order ordering
    producer.send("orders.events", key=order_id.encode(), value={"order_id": order_id, "status": status})
    producer.flush()
```

```python
consumer = KafkaConsumer(
    "orders.events",
    bootstrap_servers=["localhost:9092"],
    group_id="order-notifier",
    enable_auto_commit=False,   # commit manually, only after processing succeeds
)

for message in consumer:
    process_order_event(message.value)
    consumer.commit()           # advance the offset only after success
```

`enable_auto_commit=False` plus a manual `commit()` after processing is the pattern to lead with. Auto-commit on a timer can advance a consumer's offset for a message that then fails to process, silently dropping it, since Kafka now believes that message was handled.

> **Remember:** commit the offset manually, after processing succeeds. Auto-commit on a timer can mark a message "done" before you actually know that.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-kafka-commit-q1", "type": "mcq",
      "prompt": "Why is enable_auto_commit=False plus a manual commit() after processing safer than the default auto-commit?",
      "options": [
        {"id":"a","text":"Manual commits are always faster than automatic ones"},
        {"id":"b","text":"Auto-commit on a timer can advance the offset for a message that then fails to process, silently dropping it, since Kafka now believes it was already handled"},
        {"id":"c","text":"Auto-commit is not supported on Kafka topics with more than one partition"},
        {"id":"d","text":"Manual commits use less network bandwidth"}
      ],
      "correct": "b",
      "explanation": "Auto-commit doesn't know whether your processing actually succeeded. It advances the offset on a timer, which can mark a message as done right before your code throws on it, permanently losing that message." }
] }
```

## Consumer groups and the parallelism ceiling

Add a second consumer process with the same `group_id`, and Kafka's group coordinator rebalances: 6 partitions split between 2 consumers means 3 each. Add a third and it takes some from the other two. Add a *seventh* consumer to a 6-partition topic, and it sits idle. **Partition count is the hard upper bound on parallelism within a group.** That's the detail interviewers check for when they ask how you'd scale consumption.

> **Remember:** you cannot have more actively-consuming workers in a group than the topic has partitions. Scaling consumers past that count just leaves the extras idle.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-kafka-parallelism-q1", "type": "mcq",
      "prompt": "A topic has 6 partitions and a consumer group scales up to 10 consumers. What happens to the 4 extra consumers?",
      "options": [
        {"id":"a","text":"They each get a fair share by splitting existing partitions into smaller pieces"},
        {"id":"b","text":"They sit idle, since a partition can only be read by one consumer in a group at a time, and there are only 6 partitions to hand out"},
        {"id":"c","text":"Kafka automatically creates 4 more partitions to accommodate them"},
        {"id":"d","text":"The consumer group fails to start"}
      ],
      "correct": "b",
      "explanation": "Partition count is the ceiling on parallel consumption within one group. Extra consumers beyond that count have nothing left to claim and simply sit idle." }
] }
```

## Ordering: guaranteed within a partition, never across

Kafka guarantees order *within one partition only*. Records sharing a key always land in the same partition, through the default hash partitioner, and are delivered to that partition's consumer in write order. There is no ordering guarantee *across* different partitions.

- Need strict, global ordering: use a single partition. This caps throughput to one consumer.
- Need ordering per entity (per order, per user): key by that entity's ID, let Kafka spread entities across partitions, and accept there's no ordering guarantee *between* different entities.

Almost every real system picks the second option, which is exactly why the producer example above keys every event by `order_id`.

> **Remember:** Kafka orders records within one partition, never across partitions. Keying by entity ID is how you get "ordered enough" without capping throughput to a single partition.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-kafka-ordering-q1", "type": "mcq",
      "prompt": "A system needs every event for a given order to be processed in the order it happened, but does not care about ordering between different orders. What's the standard approach?",
      "options": [
        {"id":"a","text":"Use a single partition for the whole topic"},
        {"id":"b","text":"Key each event by order_id, so all events for one order land in the same partition and are delivered in order, while different orders can spread across partitions"},
        {"id":"c","text":"Kafka guarantees global ordering automatically, so no special handling is needed"},
        {"id":"d","text":"Use a separate topic per order"}
      ],
      "correct": "b",
      "explanation": "Kafka's default partitioner routes same-key records to the same partition. Keying by the entity that needs internal ordering gets you exactly that guarantee, while spreading unrelated entities across partitions for parallelism." }
] }
```

## Handling duplicate delivery

Two separate layers of defense, answering two different questions:

1. **Producer-side, idempotent producer** (`enable_idempotence=True`). Kafka assigns each producer an ID and each message a sequence number; the broker deduplicates retries of the same pair, caused by the producer retrying after an ack timeout. This stops duplicate *writes* caused by retries, not duplicate *processing*.
2. **Consumer-side, at-least-once delivery is the default**, so consumers must be idempotent. Kafka can redeliver a message if a consumer crashes after processing but before committing its offset. Handle it the same way as any idempotent API: track a unique ID per message and skip work you've already done.

```python
def process_order_event(event, db_session):
    dedupe_key = f"{event['order_id']}:{event['status']}"
    if ProcessedEvent.objects.filter(key=dedupe_key).exists():
        return  # already handled, skip re-applying side effects
    apply_side_effects(event)
    ProcessedEvent.objects.create(key=dedupe_key)
```

For true exactly-once *semantics* end to end, not just exactly-once delivery, Kafka offers transactional producers that atomically write to multiple partitions and commit consumer offsets together. Most interview-level answers are expected to name the at-least-once-plus-idempotent-consumer pattern instead, since that's what's actually deployed in most real systems.

> **Remember:** an idempotent producer stops duplicate writes from retries. An idempotent consumer, keyed by a unique message ID, is what actually protects you from duplicate side effects.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-kafka-duplication-q1", "type": "mcq",
      "prompt": "enable_idempotence=True is set on the producer. Does this alone guarantee the consumer never processes a duplicate?",
      "options": [
        {"id":"a","text":"Yes, idempotent producers eliminate all forms of duplication"},
        {"id":"b","text":"No, it only stops duplicate writes caused by producer retries; a consumer crash between processing and committing its offset can still cause redelivery, so the consumer must also be idempotent"},
        {"id":"c","text":"No, idempotent producers only work with a single partition"},
        {"id":"d","text":"Yes, but only for topics with exactly one consumer"}
      ],
      "correct": "b",
      "explanation": "Producer idempotence and consumer idempotence solve different problems. The producer setting only dedupes retries at write time; the default at-least-once delivery model still means a consumer can see the same message twice." }
] }
```

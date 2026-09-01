---
kind: lesson
id_key: interview-prep-45/day-18-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Message Queues (Kafka)"
position: 18
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Kafka questions separate candidates who've used a queue from candidates who've used *this* queue. Interviewers probe partitioning, consumer groups, and delivery guarantees because those are where Kafka's design diverges from RabbitMQ/SQS. Today covers the architecture, a working producer/consumer, and the ordering and duplication questions that come up in nearly every backend system-design interview.

## Kafka architecture

- **Topic**: a named stream of records, split into **partitions**. Partitioning is how Kafka parallelizes: each partition is an append-only, ordered log, and different partitions can be consumed independently.
- **Broker**: a Kafka server; a cluster is multiple brokers, each holding a subset of partitions (and replicas of others).
- **Producer**: writes records to a topic, choosing (directly or via a partitioner) which partition each record lands in.
- **Consumer**: reads records from partitions, tracking its position via an **offset** (a per-partition sequence number).
- **Consumer group**: a set of consumers that split a topic's partitions among themselves; each partition is read by exactly one consumer in the group at a time, which is how Kafka achieves parallel consumption without duplicate work.
- **ZooKeeper / KRaft**: cluster metadata and controller election; modern Kafka (3.x+) uses KRaft (Kafka's own Raft-based consensus) instead of a separate ZooKeeper cluster.

The mental model interviewers want: a topic-partition is a durable, ordered log file. Producers append; consumers read at their own pace, tracked by offset. Nothing is removed on read. Kafka retains records for a configured retention period (or size), so multiple independent consumer groups can each read the same topic from wherever they like, including replaying from the beginning.

## Producer and consumer

```python
from kafka import KafkaProducer, KafkaConsumer
import json

producer = KafkaProducer(
    bootstrap_servers=["localhost:9092"],
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    acks="all",              # wait for all in-sync replicas to ack — see delivery guarantees below
    retries=5,
    enable_idempotence=True,  # see "handling duplication" below
)

def publish_order_event(order_id: str, status: str):
    # key = order_id: guarantees every event for the same order lands
    # in the same partition, so per-order ordering is preserved
    producer.send(
        "orders.events",
        key=order_id.encode("utf-8"),
        value={"order_id": order_id, "status": status},
    )
    producer.flush()
```

```python
consumer = KafkaConsumer(
    "orders.events",
    bootstrap_servers=["localhost:9092"],
    group_id="order-notifier",          # consumer group — see below
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    enable_auto_commit=False,            # commit manually after processing succeeds
    auto_offset_reset="earliest",        # if no committed offset exists, start from the beginning
)

for message in consumer:
    process_order_event(message.value)
    consumer.commit()                    # advance the offset only after successful processing
```

`enable_auto_commit=False` plus a manual `commit()` after processing is the pattern to lead with in an interview: auto-commit on a timer can advance the offset for a message that then fails to process, silently dropping it.

## Consumer groups

Add a second consumer process with the same `group_id="order-notifier"` and Kafka's group coordinator rebalances: if `orders.events` has 6 partitions and you now have 2 consumers, each gets 3 partitions. Add a third consumer and it takes some from the other two. Add a *seventh* consumer with only 6 partitions available and it sits idle. **Partition count is the hard upper bound on consumer parallelism** within a group, which is the detail interviewers check for when they ask about scaling consumption.

A different `group_id` reading the same topic is an entirely independent view. For example, `order-notifier` and `order-analytics` can both consume every event from `orders.events` at their own pace, because offsets are tracked per (group, partition), not globally.

## Message ordering in Kafka

**What is message ordering in Kafka?** Kafka guarantees order *within a partition only*: records with the same key always land in the same partition (via the default hash partitioner) and are delivered to that partition's consumer in write order. There is no ordering guarantee *across* partitions. So:

- Need strict global ordering: use a single partition (caps throughput to one consumer).
- Need ordering per-entity (per order, per user): key by that entity's ID, let Kafka spread entities across partitions, accept no cross-entity ordering.

Almost every real system picks the second option; it's why the producer example above keys by `order_id`.

## Handling message duplication

**How do you handle message duplication?** Two layers:

1. **Producer-side: idempotent producer** (`enable_idempotence=True`). Kafka assigns each producer a PID and each message a sequence number; the broker deduplicates retries of the same (PID, sequence) pair caused by a producer retrying after an ack timeout. This closes duplicate *writes* from retries, not duplicate *processing*.
2. **Consumer-side: at-least-once delivery is the default, so consumers must be idempotent.** Kafka can redeliver a message if a consumer crashes after processing but before committing its offset. Handle this the same way as Day 17's idempotent API: track a unique message ID (or the Kafka `(topic, partition, offset)` triple) in your datastore and skip work you've already done.

```python
def process_order_event(event, db_session):
    dedupe_key = f"{event['order_id']}:{event['status']}"
    if ProcessedEvent.objects.filter(key=dedupe_key).exists():
        return  # already handled, skip re-applying side effects
    apply_side_effects(event)
    ProcessedEvent.objects.create(key=dedupe_key)
```

For exactly-once *semantics* end-to-end (not just exactly-once delivery), Kafka offers transactional producers (`transactional.id`) that atomically write to multiple partitions and commit consumer offsets together. Most interview-level answers are expected to name the at-least-once-plus-idempotent-consumer pattern instead, since that's what's actually deployed in most systems.

## Implementation notes: producer/consumer you can run locally

```bash
# start a single-broker Kafka in KRaft mode (no ZooKeeper needed) via Docker
docker run -d --name kafka -p 9092:9092 \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  apache/kafka:3.7.0

pip install kafka-python
```

Run the producer script to publish a few `orders.events`, then run the consumer script in two terminals with the same `group_id`. Watch the partitions split between them, then kill one and watch a rebalance hand its partitions to the survivor.

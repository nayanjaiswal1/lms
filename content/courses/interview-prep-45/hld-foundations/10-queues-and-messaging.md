---
kind: lesson
id_key: interview-prep-45/hld-10-messaging
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Messaging, Queues, and Event-Driven Architecture"
position: 10
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

The moment you draw a queue on the whiteboard, an interviewer has four follow-up questions ready: what happens if whoever's processing the message crashes halfway through, what happens if the same message gets delivered twice, is the order of messages preserved, and what happens if messages arrive faster than they can be processed. Walk in with all four answers ready, and this becomes one of the strongest parts of your whole design.

## Why a queue, and where the line goes

A queue does four genuinely different jobs, and being able to name which one you actually need is what separates "I'd just add a message broker like Kafka" from a design that's actually been thought through.

| Job | What it buys you | Example |
|---|---|---|
| **Decoupling** | The producer doesn't need to know about, or wait on, its consumers | An order service announces "order placed," and separately, email, analytics, and inventory each pick that up |
| **Buffering / smoothing out spikes** | Absorbs a sudden rush of traffic so the slower side isn't overwhelmed | 50,000 signups during a flash sale drain into a pool of workers at whatever pace they can handle |
| **Moving slow work out of the way** | Keeps slow work off the path a user is waiting on | Converting video, generating a PDF, sending bulk email |
| **Retrying safely, without losing anything** | A failed piece of work isn't simply lost | Retrying a failed payment notification with increasing delays |

**Here's the line to draw in every design you build: anything the user's response doesn't depend on goes behind a queue.** Creating an order has to save that order and reply right away. Sending the confirmation email, updating a recommendation model, indexing for search, and telling the warehouse can all happen a moment later, in the background.

There are real costs here, and you should mention them yourself before you're asked.

- **The delay becomes visible to users.** "Your order is placed" shows up instantly, but the confirmation email might arrive 30 seconds later, and an analytics dashboard might lag behind by more.
- **Debugging gets harder.** A failure now shows up in a background worker's log, not in the original request's trace, unless you deliberately carry a shared trace ID through both.
- **It's another whole system to run**: the message broker itself, how its partitions are managed, watching for messages piling up, and handling messages that keep failing.

> **Remember:** if the user's response doesn't depend on it, put it behind a queue. Everything else stays in the request path.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-why-q1", "type": "mcq",
      "prompt": "Which of these must stay in the request path of creating an order, rather than moving behind a queue?",
      "options": [
        {"id":"a","text":"Sending the order confirmation email"},
        {"id":"b","text":"Reserving inventory and saving the order, because the response tells the user whether their order actually succeeded"},
        {"id":"c","text":"Updating a recommendation model"},
        {"id":"d","text":"Indexing the order for internal search"}
      ],
      "correct": "b",
      "explanation": "Anything the user's own response depends on has to finish before you reply to them. Everything the user only finds out about later, like an email, an analytics update, or search indexing, belongs behind the queue instead." }
] }
```

## Queue vs log: the distinction that matters

Picture a to-do list, where you cross an item off and it's gone for good, compared with a diary, where every entry stays on the page forever and you can flip back and reread any day you like. A to-do list works like a message queue. A diary works like what's called a distributed log. Picking the wrong shape for the job is a common and expensive mistake.

**A message queue**, like RabbitMQ, SQS, or ActiveMQ, delivers each message to exactly one consumer, who processes it and confirms it, and the broker then **deletes** it. The broker keeps track of each individual message's state.

**A distributed log**, like Kafka, Kinesis, Redpanda, or Pulsar, appends every message to an ordered, **kept** log, split into partitions. Consumers each track their own position, called an offset, and read at their own pace; a message is never deleted just because someone read it. Many separate groups of consumers can all read the very same stream, each independently.

| | Queue (RabbitMQ/SQS) | Log (Kafka) |
|---|---|---|
| What happens after it's read | Deleted | Kept for a set time or size |
| How many consumers per message | One, per queue | Many independent groups |
| Can you replay old history | No | **Yes**, by resetting your offset |
| Ordering | Only within one queue, and lost once several consumers share it | **Strict, within each partition** |
| Routing options | Rich: exchanges, topics, headers, priorities | Simple: a topic, split into partitions |
| Confirming or retrying one message | Built in, per message | Per offset; one stuck message blocks its whole partition |
| How much it can handle | High | **Very high**, thanks to sequential disk writes and batching |
| Typical use | Task queues, work that's like a remote call, priority-based routing | Streams of events, database change feeds, analytics, replaying full history |

The decision rule is simple: **do you need to replay history, or have several independent consumers each read the same events? Use a log. Do you need per-message routing, priorities, or delayed retries? Use a queue.**

In Kafka, partitions are the unit both of how much work can happen in parallel and of ordering itself: messages sharing the same key always go to the same partition and stay strictly ordered there, and each partition is only ever read by one consumer within a given group. So **the number of partitions is the most work you can do in parallel**, and the key you choose is what keeps things belonging to the same entity in order; keying by `user_id`, for instance, keeps one user's own events ordered, even though the topic as a whole is not.

> **Remember:** a queue deletes a message once it's read. A log keeps every message, so many independent readers can each replay it at their own pace. Pick a log whenever you need to replay history.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-queuelog-q1", "type": "mcq",
      "prompt": "You need order events consumed independently by billing, analytics, and search, and you want to rebuild the search index next month by re-reading everything from the start. What fits?",
      "options": [
        {"id":"a","text":"A message queue, with three consumers reading from the same queue"},
        {"id":"b","text":"A distributed log, like Kafka: each system runs as its own consumer group with its own offset, and the retained history lets you reset an offset and rebuild"},
        {"id":"c","text":"Direct, synchronous calls from the order service to all three services"},
        {"id":"d","text":"A shared database table that all three services poll"}
      ],
      "correct": "b",
      "explanation": "Three consumers sharing one queue would split the messages between them instead of each seeing every one, and a queue deletes a message once it's confirmed, so there's nothing left to replay. Keeping the full history and letting each group track its own offset is exactly what a log gives you." }
] }
```

## Delivery semantics and idempotent consumers

There are three possible promises a message system can make, and only two of them are actually achievable.

| Promise | How it's done | What can go wrong |
|---|---|---|
| **At-most-once** | Confirm the message before doing the work | The message is lost if the worker crashes mid-way through |
| **At-least-once** | Confirm the message after doing the work | **Duplicates** appear if the confirmation itself gets lost after the work was already done |
| **Exactly-once** | Not actually achievable end to end, across separate systems | — |

**At-least-once is both the default and the right choice**, because losing work outright is usually worse than accidentally doing it twice. That means handling duplicates isn't an edge case; it's a real design requirement.

When Kafka advertises "exactly-once," it means exactly-once *inside Kafka itself*, through transactional writes across its own topics with a producer that avoids sending the same thing twice. The moment your consumer actually charges a card or sends an email, that's an effect happening out in the real world, one that Kafka's own transaction has no power to undo. The honest way to describe this, and the answer interviewers actually want to hear, is: **"at-least-once delivery plus idempotent processing gives you effectively-once behaviour."**

**Here's how you actually make a consumer idempotent, meaning safe to run more than once:**

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

Two more patterns worth knowing by name.

**Conditional writes**: a statement like `UPDATE orders SET status='shipped' WHERE id=? AND status='paid'` has the same effect no matter how many times you run it, because it only applies once the row is actually in the expected starting state.

**Version or sequence checks**: ignore any incoming event whose version number isn't exactly one greater than the one you already have stored.

> **Remember:** duplicates are guaranteed in a distributed system, so design for them. "At-least-once delivery plus an idempotent consumer" is the honest, achievable promise, not "exactly-once."

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-delivery-q1", "type": "mcq",
      "prompt": "Why can no message broker offer true end-to-end exactly-once delivery when the consumer's job is sending an email?",
      "options": [
        {"id":"a","text":"Because email servers themselves are unreliable"},
        {"id":"b","text":"Because the consumer can crash right after sending the email but before confirming the message, and no protocol can pull back an email that's already been sent; the achievable goal is at-least-once delivery plus a consumer built to handle duplicates"},
        {"id":"c","text":"Because message brokers don't save messages to disk"},
        {"id":"d","text":"Because the network can reorder packets"}
      ],
      "correct": "b",
      "explanation": "True exactly-once needs a single atomic commit spanning both the broker and the real-world side effect. Kafka's transactions only cover writes back into Kafka itself, not anything happening outside it, which is exactly why \"effectively-once\" through an idempotent consumer is the honest answer." }
] }
```

## Ordering, retries, dead letters, and backpressure

**Ordering across an entire topic is expensive, and you almost never actually need it. Ordering per entity usually is what you need instead.** Partitioning by the entity's own key, like `user_id`, `account_id`, or `conversation_id`, gives you strict order exactly where it matters, while still letting different entities be processed in parallel. If you genuinely need every single message globally ordered, you're stuck with one partition and one consumer; say that cost out loud when you propose it.

Ordering quietly breaks in three common situations: several consumers sharing one queue, a retried message getting pushed behind newer ones that arrived after it, and changing the number of partitions, which changes which partition a given key lands in.

**Retries should use exponential backoff with a bit of randomness added, called jitter.** If every failed client retries after exactly the same fixed delay, they all end up retrying together in a wave, called a thundering herd.

```
delay = min(base * 2**attempt, max_delay) * random_between(0.5, 1.5)
```

Always put a cap on the number of attempts. Also tell apart failures that are worth retrying, like a timeout or a temporary overload, from ones that are permanent, like a validation error; retrying a message that's simply malformed forever is pure waste, and it blocks everything behind it in the same partition.

**A dead letter queue** is where a message goes after failing too many times. After N attempts, move it there along with its error and how many times it was tried. Nothing is lost, the main flow keeps moving, and a person, or a separate fixed-up consumer, can retry it later. **Always alert on how many messages are sitting in the dead letter queue**; a dead letter queue nobody is watching is a data-loss incident that nobody has noticed yet.

**Backpressure is what happens when producers create messages faster than consumers can process them.** The queue keeps growing, memory and disk fill up, and response times climb until something breaks. Your options are:

1. **Scale up the number of consumers**, automatically, based on how deep the queue is or how far behind consumers are. In Kafka, this only helps up to the number of partitions you have.
2. **Put a hard limit on the queue's size**, and reject or pause producers once it's full. Failing immediately and clearly is better than slowly grinding to a halt.
3. **Shed load on purpose**: drop lower-priority messages, or only process a sample of them.
4. **Rate limit the producers themselves.**

**The single most important metric here is consumer lag**, meaning how far behind consumers are from the latest message. In Kafka this is the gap between offsets; in SQS it's how old the oldest unprocessed message is. Watch the *trend* in that lag over time, not just its current value: lag that keeps steadily growing means you simply don't have enough consumers, and waiting longer will never fix that on its own.

> **Remember:** one bad message can block a whole partition if you keep retrying it forever. Move it to a dead-letter queue after N attempts, and alert on that queue's depth.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-ops-q1", "type": "mcq",
      "prompt": "One malformed message fails permanently and keeps getting retried forever at the front of a Kafka partition. What is the correct fix?",
      "options": [
        {"id":"a","text":"Increase the retry limit so it eventually succeeds"},
        {"id":"b","text":"After N attempts, move it to a dead-letter topic along with its error details, confirm the original message so the partition can keep moving, and alert on how deep the dead-letter topic is getting"},
        {"id":"c","text":"Delete the whole partition"},
        {"id":"d","text":"Switch the whole system to at-most-once delivery"}
      ],
      "correct": "b",
      "explanation": "A message like this blocks its own partition because messages have to be confirmed in order. Moving it to a dead-letter queue takes it out of the way without losing it, and alerting on that queue's size makes sure someone actually notices and looks at it." }
] }
```

## Event-driven patterns: pub/sub, outbox, event sourcing, CQRS

**Point-to-point versus publish/subscribe.** Point-to-point means one producer, one consumer, one queue, like a personal to-do list. Publish/subscribe, often shortened to pub/sub, means one event has many independent subscribers, like a public announcement everyone can hear. Prefer publishing **facts**, like "order placed," over issuing **commands**, like "send the email." Publishing a fact lets you add a fourth listener later without ever touching the original producer, which is the entire point of decoupling systems in the first place.

**The dual-write problem, and the outbox pattern that fixes it, is the single most valuable idea in this whole topic.** Picture writing a cheque, and then, on a separate trip, walking to the post office to mail someone a receipt for it. If you get hit by a bus in between those two trips, the cheque now exists, but nobody was ever told about it. Saving something to a database and then separately publishing an event to a message broker has exactly this same problem: **it isn't one single atomic action**. A crash in between the two can leave the order saved but never announced, or announced without ever actually being saved.

```
Wrong:   BEGIN; INSERT order; COMMIT;   kafka.publish(event)   ← crash here = lost event

Right:   BEGIN;
           INSERT INTO orders   (...);
           INSERT INTO outbox   (id, topic, payload, created_at);   -- same transaction
         COMMIT;
         -- a separate relay (CDC on the WAL, or a poller) reads outbox and publishes,
         -- marking rows sent. At-least-once by construction; consumers dedupe.
```

The reverse of this idea, called the **inbox pattern**, removes duplicates on the receiving side, by recording each processed message's id in the very same transaction as the effect it caused.

**Event sourcing** stores the full sequence of events as the actual source of truth, and figures out the current state by replaying them from the start. In exchange, you get a complete audit trail, the ability to look at any point in the past, and the option to build entirely new views from that same history later. The cost is having to handle old event formats as your system evolves, needing periodic snapshots so replaying isn't unbounded, and the fact that a simple question like "what's the current balance" now requires computation instead of a lookup. Use this where the history genuinely *is* the product, like ledgers, audit trails, or collaborative documents, not as a default choice everywhere.

**CQRS**, short for command query responsibility segregation, splits the model you write to from one or more separate models you read from, kept in sync through events. It pairs naturally with event sourcing, and with any system whose reads look very different in shape from its writes, such as a normalised write side feeding a denormalised feed for reading. The cost is that the two sides can briefly disagree with each other, and you now maintain two models instead of one.

**Change data capture**, often shortened to CDC, reads a database's own internal change log directly, using a tool like Debezium on Postgres's write-ahead log or MySQL's binary log, and publishes each row change as an event. This gives you the outbox pattern's same safety without changing your application code at all, and it's the standard way to feed search indexes, caches, and data warehouses from one authoritative database.

> **Remember:** writing to a database and publishing an event are two separate actions, so a crash between them loses one or the other. The outbox pattern writes the event into the same database transaction, so there is nothing to lose.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-10-outbox-q1", "type": "mcq",
      "prompt": "A service saves an order to Postgres and then publishes an \"order placed\" event to Kafka. What can go wrong, and what is the standard fix?",
      "options": [
        {"id":"a","text":"Nothing; the two writes simply happen one after the other"},
        {"id":"b","text":"The dual-write problem: a crash between the save and the publish loses the event permanently. Fix it with a transactional outbox: insert the event into an outbox table in the very same transaction as the order, then have a separate relay, or change data capture, publish from that table"},
        {"id":"c","text":"Kafka might reorder the event; fix it by adding a timestamp"},
        {"id":"d","text":"Postgres might roll back after Kafka has already accepted the event; fix it with a longer transaction timeout"}
      ],
      "correct": "b",
      "explanation": "Two separate systems can't be written to atomically without something like a distributed transaction. The outbox pattern turns this into one single local transaction, followed by an at-least-once relay, with consumers built to handle the resulting duplicates." }
] }
```

## Quick recap

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

---
kind: lesson
id_key: interview-prep-45/day-26-backend
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Async Pipelines"
position: 5
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Moving work out of the request cycle is easy. Moving it out *reliably*, so a crash halfway through doesn't corrupt anything or lose an event, is the part that separates "I used Celery to send an email" from "I understand distributed failure modes." This is a favorite senior-level interview area: multi-stage pipelines, dead letter queues, and the outbox pattern.

## Three shapes of async work

**Fire-and-forget.** A request triggers work and doesn't wait for it: a Celery task or a FastAPI `BackgroundTasks` call. The simplest case.

**Fan-out / fan-in.** One input splits into many parallel subtasks, then the results are combined. Resize an upload into 5 sizes at once, mark it "processed" once all 5 finish.

**Pipeline (multi-stage).** Stage N's output is stage N+1's input, and each stage scales and retries independently: upload, virus scan, transcode, thumbnail, notify.

```python
from celery import Celery, chain

app = Celery("pipeline", broker="redis://localhost:6379/0")

@app.task(bind=True, max_retries=3, default_retry_delay=10)
def scan_upload(self, file_id: str) -> str:
    if not virus_scan(file_id):
        raise ValueError(f"file {file_id} failed virus scan")
    return file_id

@app.task(bind=True, max_retries=3, default_retry_delay=10)
def transcode(self, file_id: str) -> str:
    try:
        run_transcode(file_id)
        return file_id
    except TranscodeError as exc:
        raise self.retry(exc=exc)

@app.task
def generate_thumbnail(file_id: str) -> str:
    make_thumbnail(file_id)
    return file_id

@app.task
def notify_owner(file_id: str) -> None:
    send_notification(file_id, "Your upload is ready")

def start_pipeline(file_id: str):
    pipeline = chain(scan_upload.s(file_id), transcode.s(), generate_thumbnail.s(), notify_owner.s())
    pipeline.apply_async()
```

Each stage is its own task with its own retry policy. A transient transcode failure retries on its own, without re-running the (expensive) virus scan that already succeeded. That independence is the whole point of building a pipeline instead of one giant function: it isolates each stage's failure domain and retry policy.

> **Remember:** a pipeline's real value is isolating each stage's failures. A retry in stage 3 should never have to redo stages 1 and 2.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-asyncpipelines-shapes-q1", "type": "mcq",
      "prompt": "Why build a 5-stage pipeline out of separate tasks instead of one function that runs all 5 steps in sequence?",
      "options": [
        {"id":"a","text":"Separate tasks always run faster than one function"},
        {"id":"b","text":"Each stage gets its own retry policy and failure domain, so a transient failure in a later stage doesn't force re-running the earlier stages that already succeeded"},
        {"id":"c","text":"Celery does not support functions longer than a few lines"},
        {"id":"d","text":"One function cannot call another function inside a task"}
      ],
      "correct": "b",
      "explanation": "The entire benefit of a multi-stage pipeline is isolating failure and retry per stage. A single function retries the whole thing on any failure, redoing expensive work that already succeeded." }
] }
```

## Partial failures: what state is left behind

"How do you handle partial failures in a pipeline" is really asking: what happens when stage 3 of 5 fails, and what does the system look like afterward?

Three rules:

1. **Every stage must be idempotent.** A retry re-runs the stage, so running `generate_thumbnail` twice for the same file must not create two thumbnails. Use an upsert (`ON CONFLICT DO UPDATE` in Postgres) instead of a blind insert.
2. **Track stage status explicitly**, in a table, not by inferring it from queue state, which disappears the moment a task finishes or fails. A status row lets you query "what's stuck right now" and resume a stage from its last completed step instead of starting over.
3. **Decide per failure: retry, skip, or fail the whole pipeline.** Not every failure deserves the same response.

```python
@app.task(bind=True, max_retries=3)
def transcode(self, file_id: str) -> str:
    run = get_or_create_run(file_id, stage="transcode")
    run.status, run.attempts = StageStatus.RUNNING, run.attempts + 1
    db.commit()
    try:
        run_transcode(file_id)
    except UnsupportedFormatError as exc:
        run.status, run.error = StageStatus.FAILED, str(exc)   # not transient — don't retry
        db.commit()
        raise
    except TranscodeTimeoutError as exc:
        db.commit()
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)   # transient — worth retrying
    else:
        run.status = StageStatus.DONE
        db.commit()
        return file_id
```

The distinction between a **permanent** failure (bad input, retrying never helps) and a **transient** one (a network blip, worth retrying with backoff) is the single most important decision in any pipeline. Retrying a permanent failure just burns queue capacity and delays the signal that a human actually needs to look at it.

> **Remember:** classify every failure as permanent or transient before deciding to retry. Retrying a permanent failure wastes capacity and delays the alert that a human is actually needed.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-asyncpipelines-partial-q1", "type": "mcq",
      "prompt": "A transcode task fails because the uploaded file format is fundamentally unsupported. What should happen?",
      "options": [
        {"id":"a","text":"Retry with exponential backoff up to the max attempts, same as any other failure"},
        {"id":"b","text":"Fail immediately without retrying, since this is a permanent failure that no amount of retrying will fix"},
        {"id":"c","text":"Silently skip the stage and continue the pipeline as if it succeeded"},
        {"id":"d","text":"Restart the entire pipeline from the first stage"}
      ],
      "correct": "b",
      "explanation": "An unsupported format will fail identically on every retry. Treating it as permanent and failing fast avoids burning queue capacity, and gets the failure signal to a human sooner instead of after 3 wasted retries." }
] }
```

## Dead letter queues: a graveyard needs a way back out

A dead letter queue (DLQ) is where a task lands after exhausting its retries or hitting a permanent failure, instead of vanishing or retrying forever.

```python
from celery.signals import task_failure

@task_failure.connect
def handle_task_failure(sender=None, task_id=None, exception=None, args=None, kwargs=None, **extra):
    send_to_dead_letter_queue(
        task_name=sender.name, task_id=task_id,
        payload={"args": args, "kwargs": kwargs}, error=str(exception),
    )
```

With RabbitMQ or SQS-style brokers, a DLQ is often a first-class feature: configure a max-retry count and a target queue, and the broker moves the message there automatically. With Redis and Celery, it's usually rolled by hand, as above, or via `acks_late` plus a max-retries exception handler.

What actually matters for the interview: **a DLQ entry needs a replay path.** A write-only DLQ is just a failure graveyard. Build, or at least describe, a way to inspect a dead-lettered task, fix the underlying issue, and re-enqueue it, often an admin endpoint or CLI command that reads the stored arguments and calls the task again.

> **Remember:** a dead letter queue without a replay path is just a place failures go to be forgotten. The whole point is inspecting, fixing, and re-enqueuing.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-asyncpipelines-dlq-q1", "type": "mcq",
      "prompt": "A team builds a dead letter queue that logs every permanently failed task, but has no way to re-run one after fixing the underlying bug. What's missing?",
      "options": [
        {"id":"a","text":"Nothing; logging failed tasks is the entire point of a DLQ"},
        {"id":"b","text":"A replay path: a way to inspect a dead-lettered task's stored arguments and re-enqueue it once the underlying issue is fixed"},
        {"id":"c","text":"A faster broker"},
        {"id":"d","text":"More retry attempts before giving up"}
      ],
      "correct": "b",
      "explanation": "A DLQ that only records failures without a way to act on them is a write-only graveyard. The value of a DLQ comes from being able to fix the root cause and replay the exact failed work afterward." }
] }
```

## The outbox pattern: writing to a database and publishing an event, atomically

The problem: you often need to update the database *and* publish an event together, for example creating an order and publishing `OrderCreated`. Done as two separate operations, there's a window where one succeeds and the other fails: the database commits and the process crashes before the publish, or the publish succeeds and the transaction then rolls back. Either way, your database and your event consumers now disagree about reality.

The outbox pattern fixes this by writing the event into an **outbox table, in the same database transaction** as the business data. A separate relay process reads unpublished rows and publishes them, retrying until it succeeds. Because the outbox write is transactional with the business write, the event is guaranteed to exist if and only if the business data was actually committed.

```sql
CREATE TABLE outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ
);
```

```python
def create_order(db_session, order_data: dict):
    with db_session.begin():                    # one transaction
        order = Order(**order_data)
        db_session.add(order)
        db_session.flush()                        # get order.id without committing
        db_session.add(Outbox(
            aggregate_id=str(order.id), event_type="OrderCreated",
            payload={"order_id": str(order.id), "total": order.total},
        ))
    # both rows commit together, or neither does
    return order
```

```python
def relay_outbox_events(db_session, publisher):
    unpublished = db_session.query(Outbox).filter(Outbox.published_at.is_(None)).order_by(Outbox.created_at).limit(100)
    for event in unpublished:
        try:
            publisher.publish(event.event_type, event.payload)
            event.published_at = datetime.now(UTC)
            db_session.commit()
        except PublishError:
            db_session.rollback()
            break   # stop here, retry this batch next tick, preserving order
```

This is sometimes paired with change data capture (reading the database's own write-ahead log, instead of polling) to catch the outbox insert the instant it commits, worth naming as the "at scale" version if asked.

The best guarantee outbox plus retry can offer is at-least-once delivery, since a crash between publishing and marking `published_at` can still cause a duplicate publish. Pair it with an idempotent consumer, keyed on event ID, to close the loop:

```python
def handle_order_created(event: dict, db_session):
    if db_session.query(ProcessedEvent).filter_by(event_id=event["event_id"]).first():
        return  # duplicate delivery, safely ignored
    with db_session.begin():
        fulfill_order(event["order_id"])
        db_session.add(ProcessedEvent(event_id=event["event_id"], processed_at=datetime.now(UTC)))
```

That combination, a transactional outbox on the producer side paired with an idempotent, event-ID-keyed handler on the consumer side, is what "reliable event publishing" means in practice: not zero duplicates, but zero *lost* events, and safe handling of the duplicates that do slip through.

> **Remember:** the outbox table is written in the same transaction as the business data, so the event's existence is tied to the write actually committing. A relay process publishes it afterward, at-least-once, which is why the consumer still needs to be idempotent.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-asyncpipelines-outbox-q1", "type": "mcq",
      "prompt": "Why does writing to an outbox table in the same transaction as the business data solve the 'DB commits but the event never publishes' problem?",
      "options": [
        {"id":"a","text":"It doesn't fully solve it; a separate relay process still has to publish the outbox row later, which is why the consumer must also be idempotent"},
        {"id":"b","text":"The outbox table publishes events directly without needing a relay process"},
        {"id":"c","text":"Writing to two tables in one transaction is always instantaneous, so there's no window for failure"},
        {"id":"d","text":"Outbox rows are automatically deleted once read, which guarantees delivery"}
      ],
      "correct": "a",
      "explanation": "The transactional write guarantees the event ROW exists if and only if the business data committed. Actually publishing it still happens afterward, by a separate relay process that can itself fail partway, which is why outbox alone gives at-least-once, not exactly-once, delivery." }
] }
```
